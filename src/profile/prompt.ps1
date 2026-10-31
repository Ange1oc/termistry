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

function global:Get-TsGitRoot([string]$Dir) {
    if ($global:TsGitRoots.ContainsKey($Dir)) { return $global:TsGitRoots[$Dir] }
    $d = $Dir; $root = ''
    while ($d) {
        if (Test-Path -LiteralPath (Join-Path $d '.git')) { $root = $d; break }
        $d = Split-Path $d -Parent
    }
    $global:TsGitRoots[$Dir] = $root
    $root
}

function global:Get-TsGitBranch([string]$Root) {
    $gitDir = Join-Path $Root '.git'
    if (Test-Path -LiteralPath $gitDir -PathType Leaf) {
        $line = Get-Content -LiteralPath $gitDir -First 1
        if ($line -match '^gitdir:\s*(.+)$') { $gitDir = $Matches[1]; if (-not [IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $Root $gitDir } }
    }
    $head = Join-Path $gitDir 'HEAD'
    if (-not (Test-Path -LiteralPath $head)) { return '' }
    $ref = Get-Content -LiteralPath $head -First 1
    if ($ref -match '^ref: refs/heads/(.+)$') { return $Matches[1] }
    if ($ref.Length -ge 7) { return $ref.Substring(0, 7) }
    ''
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
    $c = $global:TK
    $parts = @()
    if ($staged) { $parts += "$($c.ok)+$staged" }
    if ($modified) { $parts += "$($c.accent)~$modified" }
    if ($untracked) { $parts += "$($c.accent)?$untracked" }
    if ($ahead) { $parts += "$($c.teal)⇡$ahead" }
    if ($behind) { $parts += "$($c.teal)⇣$behind" }
    if ($stash) { $parts += "$($c.dim)≡$stash" }
    $g = $global:TsGit
    $g.Root = $Root; $g.Text = $(if ($parts) { ' ' + ($parts -join ' ') } else { '' }); $g.Time = [datetime]::Now; $g.Pending = ''
}

function global:Get-TsKubeText {
    $file = if ($env:KUBECONFIG) { ($env:KUBECONFIG -split ';')[0] } else { Join-Path $HOME '.kube\config' }
    if (-not (Test-Path -LiteralPath $file)) { return '' }
    $stamp = "$file|$((Get-Item -LiteralPath $file).LastWriteTimeUtc.Ticks)"
    if ($global:TsKube.Stamp -eq $stamp) { return $global:TsKube.Text }
    $text = ''; $ctx = ''
    $yaml = Get-Content -LiteralPath $file -Raw
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
    $leaf = Split-Path $Dir -Leaf; if (-not $leaf) { $leaf = $Dir }
    $title = "$([char]27)]0;$leaf$([char]7)"

    $left = "$($c.dim)╭─$($c.R) $($c.cmd)$([char]0xF07B) $(Get-TsShortPath $Dir)$($c.R)"
    $root = Get-TsGitRoot $Dir
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
        $left += "  $($c.title)$([char]0xE0A0) $branch$gitText$($c.R)"
    }
    if ($env:VIRTUAL_ENV -or [IO.File]::Exists("$Dir\pyproject.toml") -or [IO.File]::Exists("$Dir\requirements.txt")) {
        $v = Get-TsToolVersion python
        if ($v) { $left += "  $($c.warn)$([char]0xE73C) $v$(if ($env:VIRTUAL_ENV) { " ($(Split-Path $env:VIRTUAL_ENV -Leaf))" })$($c.R)" }
    }
    if ([IO.File]::Exists("$Dir\package.json")) { $v = Get-TsToolVersion node; if ($v) { $left += "  $($c.ok)$([char]0xE718) $v$($c.R)" } }
    if ([IO.File]::Exists("$Dir\go.mod")) { $v = Get-TsToolVersion go; if ($v) { $left += "  $($c.teal)$([char]0xE627) $v$($c.R)" } }
    if ([IO.File]::Exists("$Dir\Cargo.toml")) { $v = Get-TsToolVersion rust; if ($v) { $left += "  $($c.accent)$([char]0xE7A8) $v$($c.R)" } }

    $right = @()
    $kube = "$($global:Termistry.Kube)"
    if ($kube -and $kube -ne 'off' -and $kube -ne 'False') {
        $k = Get-TsKubeText
        if ($k -and ($kube -eq 'always' -or $global:TsKube.Prod -or (Test-TsKubeDir $Dir) -or ($root -and $root -ne $Dir -and (Test-TsKubeDir $root)))) {
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
