# The prompt is rendered in PowerShell itself (a few ms) instead of spawning oh-my-posh (~140 ms + git).
# Branch comes from .git/HEAD, k8s context from kubeconfig; git status counts are fetched on PowerShell.OnIdle
# and the prompt is redrawn in place, so a slow `git status` never delays the prompt.
$global:TsGit = @{ Root = ''; Text = ''; Time = [datetime]::MinValue; Pending = '' }
$global:TsGitRoots = @{}
$global:TsVersions = @{}
$global:TsKube = @{ Stamp = ''; Text = '' }
$global:TsTransient = $false
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

# Runs git once; called from OnIdle, never from the prompt itself
function global:Update-TsGitStatus([string]$Root) {
    $lines = @(git -C $Root -c core.quotepath=false status --porcelain --branch 2>$null)
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
    $global:TsGit = @{ Root = $Root; Text = $(if ($parts) { ' ' + ($parts -join ' ') } else { '' }); Time = Get-Date; Pending = '' }
}

function global:Get-TsKubeText {
    $file = if ($env:KUBECONFIG) { ($env:KUBECONFIG -split ';')[0] } else { Join-Path $HOME '.kube\config' }
    if (-not (Test-Path -LiteralPath $file)) { return '' }
    $stamp = "$file|$((Get-Item -LiteralPath $file).LastWriteTimeUtc.Ticks)"
    if ($global:TsKube.Stamp -eq $stamp) { return $global:TsKube.Text }
    $text = ''
    $yaml = Get-Content -LiteralPath $file -Raw
    if ($yaml -match '(?m)^current-context:\s*(\S+)') {
        $ctx = $Matches[1]
        $ns = ''
        foreach ($block in ($yaml -split '(?m)^- context:')) {
            if ($block -match "(?m)^\s*name:\s*$([regex]::Escape($ctx))\s*$" -and $block -match 'namespace:\s*([^\s,}]+)') { $ns = $Matches[1]; break }
        }
        $text = "󱃾 $ctx" + $(if ($ns -and $ns -ne 'default') { "/$ns" })
    }
    $global:TsKube = @{ Stamp = $stamp; Text = $text }
    $text
}

function global:Get-TsToolVersion([string]$Tool) {
    if ($global:TsVersions.ContainsKey($Tool)) { return $global:TsVersions[$Tool] }
    $v = ''
    if (Get-Command $Tool -ErrorAction SilentlyContinue) {
        $out = switch ($Tool) { 'go' { go version 2>$null } 'rust' { rustc --version 2>$null } default { & $Tool --version 2>$null } }
        if ("$out" -match '(\d+)\.(\d+)(\.\d+)?') { $v = if ($Tool -eq 'node') { $Matches[1] } else { "$($Matches[1]).$($Matches[2])" } }
    }
    $global:TsVersions[$Tool] = $v
    $v
}

function global:Get-TsShortPath([string]$Dir) {
    $p = if ($Dir.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { '~' + $Dir.Substring($HOME.Length) } else { $Dir }
    $parts = $p.TrimEnd('\') -split '\\'
    if ($parts.Count -gt 4) { $parts = @($parts[0], '..') + $parts[-3..-1] }
    $parts -join '\'
}

function global:Get-TsPrompt {
    param([string]$Dir = $PWD.ProviderPath, [int]$Status = 0, [int]$Ms = 0, [int]$Width = 100, [switch]$Transient)
    $c = $global:TK
    $leaf = Split-Path $Dir -Leaf; if (-not $leaf) { $leaf = $Dir }
    $title = "$([char]27)]0;$leaf$([char]7)"
    if ($Transient) { return "$title$($c.dim)$leaf $($c.ok)❯$($c.R) " }

    $left = "$($c.dim)╭─$($c.R) $($c.cmd) $(Get-TsShortPath $Dir)$($c.R)"
    $root = Get-TsGitRoot $Dir
    if ($root) {
        $branch = Get-TsGitBranch $root
        $gitText = ''
        if ($global:TerminalSetup.GitStatus) {
            if ($global:TsGit.Root -eq $root -and ((Get-Date) - $global:TsGit.Time).TotalSeconds -lt 2) { $gitText = $global:TsGit.Text }
            else { $global:TsGit.Pending = $root }
        }
        $left += "  $($c.title) $branch$gitText$($c.R)"
    }
    if ($env:VIRTUAL_ENV -or (Test-Path -LiteralPath (Join-Path $Dir 'pyproject.toml')) -or (Test-Path -LiteralPath (Join-Path $Dir 'requirements.txt'))) {
        $v = Get-TsToolVersion python
        if ($v) { $left += "  $($c.warn) $v$(if ($env:VIRTUAL_ENV) { " ($(Split-Path $env:VIRTUAL_ENV -Leaf))" })$($c.R)" }
    }
    if (Test-Path -LiteralPath (Join-Path $Dir 'package.json')) { $v = Get-TsToolVersion node; if ($v) { $left += "  $($c.ok) $v$($c.R)" } }
    if (Test-Path -LiteralPath (Join-Path $Dir 'go.mod')) { $v = Get-TsToolVersion go; if ($v) { $left += "  $($c.teal) $v$($c.R)" } }
    if (Test-Path -LiteralPath (Join-Path $Dir 'Cargo.toml')) { $v = Get-TsToolVersion rust; if ($v) { $left += "  $($c.accent) $v$($c.R)" } }

    $right = @()
    $k = Get-TsKubeText; if ($k) { $right += "$($c.dim)$k$($c.R)" }
    if ($Ms -ge 2000) { $right += "$($c.dim) $(if ($Ms -ge 60000) { '{0}m {1}s' -f [int][math]::Floor($Ms / 60000), [int](($Ms % 60000) / 1000) } else { ($Ms / 1000).ToString('0.#', [Globalization.CultureInfo]::InvariantCulture) + 's' })$($c.R)" }
    if ($Status) { $right += "$($c.err)✘ $Status$($c.R)" }
    $rightText = $right -join '  '
    $pad = $Width - (($left + $rightText) -replace "`e\[[0-9;]*m", '' -replace "`e\][^`a]*`a", '').Length - 1
    if ($pad -lt 2) { $pad = 2 }
    $arrow = if ($Status) { $c.err } else { $c.ok }
    "$title`n$left$(' ' * $pad)$rightText`n$($c.dim)╰─$arrow❯$($c.R) "
}

function global:prompt {
    $ok = $?
    $code = if ($ok) { 0 } elseif ($global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }
    $ms = 0
    $last = Get-History -Count 1
    if ($last -and $last.Id -ne $global:TsLastHistoryId) {
        $global:TsLastHistoryId = $last.Id
        $ms = [int]($last.EndExecutionTime - $last.StartExecutionTime).TotalMilliseconds
    }
    $transient = $global:TsTransient; $global:TsTransient = $false
    Get-TsPrompt -Status $code -Ms $ms -Width $Host.UI.RawUI.WindowSize.Width -Transient:$transient
}

if ($global:isInteractive) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
        if ($global:TsGit.Pending) {
            Update-TsGitStatus $global:TsGit.Pending
            try { [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() } catch {}
        }
    }
}
