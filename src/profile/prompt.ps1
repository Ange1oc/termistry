# The prompt is rendered in PowerShell itself (a few ms) instead of spawning oh-my-posh (~140 ms + git).
# Branch comes from .git/HEAD, k8s context from kubeconfig; git status counts are fetched on PowerShell.OnIdle
# and the prompt is redrawn in place, so a slow `git status` never delays the prompt.
$global:TsGit = @{ Root = ''; Text = ''; Shown = ''; Time = [datetime]::MinValue; Pending = '' }
$global:TsGitRoots = @{}
$global:TsVersions = @{}
$global:TsKube = @{ Stamp = ''; Text = ''; Prod = $false }
$global:TsRedraw = $false
$global:TsLast = @{ Status = 0; Ms = 0 }
$global:TsLastExit = 0
$global:TsLastHistoryId = 0
$global:TsCtx = @{}
$global:TsNetDrives = @{}
$global:TsNoFile = [datetime]::FromFileTimeUtc(0).Ticks
$global:TsPromptTypes = 'node', 'python', 'go', 'rust', 'docker'

# .NET calls instead of Test-Path / Get-Content: the prompt runs them on every Enter and cmdlets cost ~1 ms each
function global:Get-TsGitRoot([string]$Dir) {
    if ($global:TsGitRoots.ContainsKey($Dir)) { return $global:TsGitRoots[$Dir] }
    $d = $Dir; $root = ''
    while ($d) {
        $git = [IO.Path]::Combine($d, '.git')
        if ([IO.Directory]::Exists($git) -or [IO.File]::Exists($git)) { $root = $d; break }
        $d = [IO.Path]::GetDirectoryName($d)
    }
    $global:TsGitRoots[$Dir] = $root
    $root
}

function global:Get-TsGitBranch([string]$Root) {
    $gitDir = [IO.Path]::Combine($Root, '.git')
    try {
        if ([IO.File]::Exists($gitDir) -and [IO.File]::ReadAllText($gitDir) -match '^gitdir:\s*(\S.*?)\s*$') {
            $gitDir = $Matches[1]; if (-not [IO.Path]::IsPathRooted($gitDir)) { $gitDir = [IO.Path]::Combine($Root, $gitDir) }
        }
        $ref = [IO.File]::ReadAllText([IO.Path]::Combine($gitDir, 'HEAD')).Trim()
    } catch { return '' }
    if ($ref -match '^ref: refs/heads/(.+)$') { return $Matches[1] }
    if ($ref.Length -ge 7) { return $ref.Substring(0, 7) }
    ''
}

function global:Test-TsNetworkPath([string]$Dir) {
    if ($Dir.StartsWith('\\')) { return $true }
    $drive = $Dir.Substring(0, 1)
    if (-not $global:TsNetDrives.ContainsKey($drive)) {
        $global:TsNetDrives[$drive] = try { [IO.DriveInfo]::new($drive).DriveType -eq 'Network' } catch { $false }
    }
    $global:TsNetDrives[$drive]
}

# What a folder is: its project root (git root, or the folder itself when it has a marker file), the project
# types found there and in the root, and whether it is a k8s folder (found on first need). Worked out when the
# folder changes and reused while the folder and its root keep their timestamps, which a new or deleted file
# updates; so an unchanged prompt costs one or two timestamps instead of a dozen file checks. On network
# drives nothing is checked but the git root, and the result is kept until the folder changes.
function global:Get-TsContext([string]$Dir) {
    $ctx = $global:TsCtx[$Dir]
    if ($ctx -and ($ctx.Net -or $ctx.Stamp -eq (Get-TsContextStamp $ctx))) { return $ctx }
    if ($Dir -notmatch '^([A-Za-z]:\\|\\\\)') { return @{ Dir = $Dir; Root = ''; Project = ''; Types = @(); Kube = $false; Net = $true } }
    $net = Test-TsNetworkPath $Dir
    [void]$global:TsGitRoots.Remove($Dir)
    $root = Get-TsGitRoot $Dir
    $types = [Collections.Generic.List[string]]::new()
    if (-not $net) {
        foreach ($d in @($Dir; if ($root -and $root -ne $Dir) { $root })) {
            foreach ($m in $global:ProjectMarkers.GetEnumerator()) {
                if ($m.Value -in $global:TsPromptTypes -and -not $types.Contains($m.Value) -and [IO.File]::Exists([IO.Path]::Combine($d, $m.Key))) { $types.Add($m.Value) }
            }
        }
    }
    $ctx = @{ Dir = $Dir; Root = $root; Project = $(if ($root) { $root } elseif ($types.Count) { $Dir } else { '' }); Types = $types.ToArray(); Kube = $null; Net = $net }
    $ctx.Stamp = if ($net) { 0 } else { Get-TsContextStamp $ctx }
    if ($global:TsCtx.Count -ge 256) { $global:TsCtx.Clear() }
    $global:TsCtx[$Dir] = $ctx
    $ctx
}

function global:Get-TsContextStamp($Ctx) {
    $s = [IO.Directory]::GetLastWriteTimeUtc($Ctx.Dir).Ticks
    if ($Ctx.Root -and $Ctx.Root -ne $Ctx.Dir) { $s += [IO.Directory]::GetLastWriteTimeUtc($Ctx.Root).Ticks }
    $s
}

# Runs git once; called from OnIdle, never from the prompt itself. $LASTEXITCODE belongs to the user's last command.
function global:Update-TsGitStatus([string]$Root) {
    $exit = $global:LASTEXITCODE
    $lines = @(git -C $Root -c core.quotepath=false status --porcelain --branch 2>$null)
    $global:LASTEXITCODE = $exit
    $staged = 0; $modified = 0; $untracked = 0; $ahead = 0; $behind = 0
    foreach ($l in $lines) {
        if ($l.StartsWith('## ')) {
            if ($l -match 'ahead (\d+)') { $ahead = [int]$Matches[1] }
            if ($l -match 'behind (\d+)') { $behind = [int]$Matches[1] }
            continue
        }
        if ($l.Length -lt 2) { continue }
        if ($l[0] -eq '?') { $untracked++; continue }
        if ($l[0] -ne ' ') { $staged++ }
        if ($l[1] -ne ' ') { $modified++ }
    }
    $stash = 0
    $stashLog = Join-Path $Root '.git\logs\refs\stash'
    if (Test-Path -LiteralPath $stashLog) { $stash = @(Get-Content -LiteralPath $stashLog).Count }
    # {color} placeholders, filled in by the prompt, so the counts follow a theme switch
    $parts = @()
    if ($staged) { $parts += "{ok}+$staged" }
    if ($modified) { $parts += "{accent}~$modified" }
    if ($untracked) { $parts += "{accent}?$untracked" }
    if ($ahead) { $parts += "{teal}⇡$ahead" }
    if ($behind) { $parts += "{teal}⇣$behind" }
    if ($stash) { $parts += "{dim}≡$stash" }
    $g = $global:TsGit
    $g.Root = $Root; $g.Text = $(if ($parts) { ' ' + ($parts -join ' ') } else { '' }); $g.Time = [datetime]::Now; $g.Pending = ''
}

function global:Get-TsKubeText {
    $file = if ($env:KUBECONFIG) { ($env:KUBECONFIG -split ';')[0] } else { Join-Path $HOME '.kube\config' }
    $ticks = [IO.File]::GetLastWriteTimeUtc($file).Ticks
    if ($ticks -eq $global:TsNoFile) { return '' }
    $stamp = "$file|$ticks"
    if ($global:TsKube.Stamp -eq $stamp) { return $global:TsKube.Text }
    $text = ''; $ctx = ''
    $yaml = [IO.File]::ReadAllText($file)
    if ($yaml -match '(?m)^current-context:\s*(\S+)') {
        $ctx = $Matches[1]
        $ns = ''
        # only the contexts: list; clusters and users have "name:" entries too
        if ($yaml -match '(?ms)^contexts:[^\n]*\n(.*?)(?=^[A-Za-z]|\z)') {
            foreach ($item in ($Matches[1] -split '(?m)^- ')) {
                if ($item -match "(?m)^\s*name:\s*$([regex]::Escape($ctx))\s*$" -and $item -match 'namespace:\s*([^\s,}]+)') { $ns = $Matches[1]; break }
            }
        }
        $text = "󱃾 $ctx" + $(if ($ns -and $ns -ne 'default') { "/$ns" })
    }
    $global:TsKube = @{ Stamp = $stamp; Text = $text; Prod = [bool]($ctx -match '(?i)(^|[^a-z])(prod|production|live)([^a-z]|$)') }
    $text
}

# The kube segment is shown only inside a k8s project (charts, manifests) or, in red, when the context looks like prod
function global:Test-TsKubeDir([string]$Dir) {
    foreach ($m in 'Chart.yaml', 'values.yaml', 'kustomization.yaml', 'skaffold.yaml', 'Tiltfile', 'k8s', 'kubernetes', 'helm', 'charts', 'manifests') {
        if ([IO.File]::Exists("$Dir\$m") -or [IO.Directory]::Exists("$Dir\$m")) { return $true }
    }
    $false
}

function global:Get-TsToolVersion([string]$Tool) {
    if ($global:TsVersions.ContainsKey($Tool)) { return $global:TsVersions[$Tool] }
    $v = ''
    $exe = if ($Tool -eq 'rust') { 'rustc' } else { $Tool }
    if (Find-TkCommand $exe) {
        $exit = $global:LASTEXITCODE
        $out = switch ($Tool) { 'go' { go version 2>$null } default { & $exe --version 2>$null } }
        $global:LASTEXITCODE = $exit
        if ("$out" -match '(\d+)\.(\d+)(\.\d+)?') { $v = if ($Tool -eq 'node') { $Matches[1] } else { "$($Matches[1]).$($Matches[2])" } }
    }
    $global:TsVersions[$Tool] = $v
    $v
}

function global:Get-TsShortPath([string]$Dir) {
    $p = if ($Dir.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { '~' + $Dir.Substring($HOME.Length) } else { $Dir }
    if ($p -match '^[A-Za-z]:\\?$') { return $p.TrimEnd('\') + '\' }
    $parts = $p.TrimEnd('\') -split '\\'
    if ($parts.Count -gt 4) { $parts = @($parts[0], '..') + $parts[-3..-1] }
    $parts -join '\'
}

function global:Get-TsPrompt {
    param([string]$Dir = $PWD.ProviderPath, [int]$Status = 0, [int]$Ms = 0, [int]$Width = 100)
    $c = $global:TK
    $leaf = [IO.Path]::GetFileName($Dir); if (-not $leaf) { $leaf = $Dir }
    $title = "$([char]27)]0;$leaf$([char]7)"

    $ctx = Get-TsContext $Dir
    $root = $ctx.Root
    $left = "$($c.dim)╭─$($c.R) $($c.cmd)$([char]0xF07B) $(Get-TsShortPath $Dir)$($c.R)"
    if ($root) {
        $branch = Get-TsGitBranch $root
        $gitText = ''
        if ($global:Termistry.GitStatus) {
            $g = $global:TsGit
            # Stale counts stay on screen while OnIdle refreshes them; a redraw happens only if they changed
            if ($g.Root -eq $root) { $gitText = $g.Text }
            if ($g.Root -ne $root -or ([datetime]::Now - $g.Time).TotalSeconds -ge 2) { $g.Pending = $root }
            $g.Shown = $gitText
        }
        $left += "  $($c.title)$([char]0xE0A0) $branch$($gitText -replace '\{(\w+)\}', { $c[$_.Groups[1].Value] })$($c.R)"
    }
    $types = $ctx.Types
    if ($env:VIRTUAL_ENV -or $types -contains 'python') {
        $v = Get-TsToolVersion python
        if ($v) { $left += "  $($c.warn)$([char]0xE73C) $v$(if ($env:VIRTUAL_ENV) { " ($([IO.Path]::GetFileName($env:VIRTUAL_ENV)))" })$($c.R)" }
    }
    if ($types -contains 'node') { $v = Get-TsToolVersion node; if ($v) { $left += "  $($c.ok)$([char]0xE718) $v$($c.R)" } }
    if ($types -contains 'go') { $v = Get-TsToolVersion go; if ($v) { $left += "  $($c.teal)$([char]0xE627) $v$($c.R)" } }
    if ($types -contains 'rust') { $v = Get-TsToolVersion rust; if ($v) { $left += "  $($c.accent)$([char]0xE7A8) $v$($c.R)" } }
    if ($types -contains 'docker') { $left += "  $($c.teal)$([char]0xF308)$($c.R)" }

    $right = @()
    $kube = "$($global:Termistry.Kube)"
    if ($kube -and $kube -ne 'off' -and $kube -ne 'False') {
        $k = Get-TsKubeText
        if ($k -and $kube -ne 'always' -and -not $global:TsKube.Prod -and $null -eq $ctx.Kube) {
            $ctx.Kube = -not $ctx.Net -and ((Test-TsKubeDir $Dir) -or ($root -and $root -ne $Dir -and (Test-TsKubeDir $root)))
        }
        if ($k -and ($kube -eq 'always' -or $global:TsKube.Prod -or $ctx.Kube)) {
            $right += "$(if ($global:TsKube.Prod) { $c.err } else { $c.dim })$k$($c.R)"
        }
    }
    if ($Ms -ge 2000) { $right += "$($c.dim)$([char]0xF017) $(if ($Ms -ge 60000) { '{0}m {1}s' -f [int][math]::Floor($Ms / 60000), [int](($Ms % 60000) / 1000) } else { ($Ms / 1000).ToString('0.#', [Globalization.CultureInfo]::InvariantCulture) + 's' })$($c.R)" }
    if ($Status) { $right += "$($c.err)✘ $Status$($c.R)" }
    $rightText = $right -join '  '
    $pad = $Width - (($left + $rightText) -replace "`e\[[0-9;]*m", '' -replace "`e\][^`a]*`a", '').Length - 1
    if ($pad -lt 2) { $pad = 2 }
    $arrow = if ($Status) { $c.err } else { $c.ok }
    "$title`n$left$(' ' * $pad)$rightText`n$($c.dim)╰─$arrow❯$($c.R) "
}

function global:prompt {
    $ok = $?
    $width = $Host.UI.RawUI.WindowSize.Width
    # Redraw from OnIdle: $? and history belong to the handler, so reuse what the real prompt saw
    if ($global:TsRedraw) { $global:TsRedraw = $false; return Get-TsPrompt -Status $global:TsLast.Status -Ms $global:TsLast.Ms -Width $width }
    $ms = 0
    $last = Get-History -Count 1
    if ($last -and $last.Id -ne $global:TsLastHistoryId) {
        $global:TsLastHistoryId = $last.Id
        $ms = [int]($last.EndExecutionTime - $last.StartExecutionTime).TotalMilliseconds
    }
    # $LASTEXITCODE outlives the native command that set it; after a cmdlet error it would be stale,
    # so it is trusted only when it changed since the last prompt or the command that ran was an executable
    $code = 0
    if (-not $ok) {
        $exit = $global:LASTEXITCODE
        $native = $false
        if ($exit -and $exit -eq $global:TsLastExit -and $last) {
            $first = ($last.CommandLine.TrimStart() -split '[\s|;(]', 2)[0]
            $native = (Find-TkCommand $first).CommandType -eq 'Application'
        }
        $code = if ($exit -and ($exit -ne $global:TsLastExit -or $native)) { $exit } else { 1 }
    }
    $global:TsLastExit = $global:LASTEXITCODE
    $global:TsLast = @{ Status = $code; Ms = $ms }
    Get-TsPrompt -Status $code -Ms $ms -Width $width
}

if ($global:isInteractive) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
        if ($global:TsGit.Pending) {
            Update-TsGitStatus $global:TsGit.Pending
            if ($global:TsGit.Text -ne $global:TsGit.Shown) {
                $global:TsRedraw = $true
                try { [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() } catch {} finally { $global:TsRedraw = $false }
            }
        }
    }
}
