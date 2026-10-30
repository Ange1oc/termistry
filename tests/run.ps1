<#
  Runs every check that does not need a human at the keyboard: static scans, the profile in a sandbox,
  the installer in a sandbox and the server bash in WSL. The real profile, Windows Terminal and caches
  are never touched.
    .\tests\run.ps1                    everything
    .\tests\run.ps1 -Only profile      static | profile | setup | server
    .\tests\run.ps1 -Keep              leave the sandbox folder behind for a look
#>
param(
    [ValidateSet('static', 'profile', 'setup', 'server')][string[]]$Only = @('static', 'profile', 'setup', 'server'),
    [switch]$Keep
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Split-Path $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) "terminal-setup-tests-$PID"
Remove-Item $work -Recurse -Force -ErrorAction Ignore
New-Item -ItemType Directory -Force $work | Out-Null
Write-Host "  $TcDim sandbox: $work$TcR"

# The profile and the installer find everything through these variables, so pointing them into the sandbox is enough
function Invoke-Sandboxed([string]$SandboxHome, [scriptblock]$Block) {
    $names = 'USERPROFILE', 'HOME', 'APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'KUBECONFIG'
    $saved = @{}; foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }
    try {
        $env:USERPROFILE = $SandboxHome; $env:HOME = $SandboxHome
        $env:APPDATA = Join-Path $SandboxHome 'AppData\Roaming'; $env:LOCALAPPDATA = Join-Path $SandboxHome 'AppData\Local'
        $env:XDG_CONFIG_HOME = Join-Path $SandboxHome '.config'; $env:KUBECONFIG = ''
        & $Block
    } finally { foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $saved[$n]) } }
}
function New-SandboxHome([string]$SandboxHome) {
    $wt = Join-Path $SandboxHome 'AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
    New-Item -ItemType Directory -Force $wt, (Join-Path $SandboxHome '.config\terminal-setup'), (Join-Path $SandboxHome 'AppData\Roaming') | Out-Null
    @'
{
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles": { "defaults": {}, "list": [ { "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}", "name": "PowerShell", "colorScheme": "Catppuccin Mocha" } ] },
    "schemes": [],
    "actions": []
}
'@ | Set-Content (Join-Path $wt 'settings.json') -Encoding utf8
    Set-Content (Join-Path $SandboxHome '.config\terminal-setup\theme') 'mocha'
    Set-Content (Join-Path $SandboxHome '.config\terminal-setup\lang') 'ru'
}
# Child test processes print "##result passed=N failed=M" last; everything else is shown as is
function Invoke-ChildTests([scriptblock]$Start) {
    $lines = @(& $Start 2>&1 | ForEach-Object { "$_" })
    foreach ($l in $lines) {
        if ($l -match '^##result passed=(\d+) failed=(\d+)') { $script:TestsPassed += [int]$Matches[1]; $script:TestsFailed += [int]$Matches[2] }
        else { Write-Host $l }
    }
}

if ('static' -in $Only) {
    Section 'static'
    $files = @(Get-ChildItem $root -Recurse -File -Include *.ps1, *.sh, *.local, *.cs, *.md, inputrc | Where-Object { $_.FullName -notmatch '\\(\.git|docs)\\' -and $_.Name -ne 'setup-terminal.ps1' })
    Test 'no long dashes in code or docs' {
        $hits = @($files | Select-String -Pattern ([string][char]0x2014) -SimpleMatch | ForEach-Object { "$($_.Filename):$($_.LineNumber)" })
        AssertEq ($hits -join ' ') '' 'found'
    }
    Test 'code comments are in english' {
        $hits = @($files | Where-Object Extension -ne '.md' | Select-String -Pattern '^\s*(#|//)[^\n]*[А-Яа-яЁё]' | Where-Object { $_.Line -notmatch 'help:' } | ForEach-Object { "$($_.Filename):$($_.LineNumber)" })
        AssertEq ($hits -join ' ') '' 'found'
    }
    Test 'every deferred stub points at a real function' {
        $profile = Get-Content (Join-Path $root 'src\profile\Microsoft.PowerShell_profile.ps1') -Raw
        Assert ($profile -match "foreach \(\`$n in ([^)]+)\)") 'stub list not found'
        $names = [regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
        $lazy = (Get-Content (Join-Path $root 'src\profile\toolkit-lazy.ps1'), (Join-Path $root 'src\profile\prompt.ps1') -Raw) -join "`n"
        $missing = @($names | Where-Object { $lazy -notmatch "function global:$([regex]::Escape($_))\b" })
        AssertEq ($missing -join ',') '' 'stubs without a function'
    }
    Test 'build output parses in Windows PowerShell 5.1 and carries the version' {
        $out = & (Join-Path $root 'build.ps1') | Out-String
        AssertMatch $out 'parses' 'build'
        $setup = Join-Path $root 'setup-terminal.ps1'
        $errors = & powershell.exe -NoProfile -Command "`$e = `$null; [void][System.Management.Automation.Language.Parser]::ParseFile('$setup', [ref]`$null, [ref]`$e); `$e.Count"
        AssertEq $errors 0 'parse errors'
        $version = (Get-Content (Join-Path $root 'src\profile\Microsoft.PowerShell_profile.ps1') -First 1) -replace ".*'([^']+)'.*", '$1'
        AssertMatch (Get-Content $setup -Raw) "\`$SetupVersion = '$([regex]::Escape($version))'" 'version injected'
    }
}

if ('profile' -in $Only) {
    Section 'profile (sandboxed pwsh)'
    $sandboxHome = Join-Path $work 'home'; New-SandboxHome $sandboxHome
    $prof = Join-Path $work 'profile'
    New-Item -ItemType Directory -Force "$prof\server", "$prof\bin" | Out-Null
    Copy-Item "$root\src\profile\*" $prof -Recurse -Force
    Copy-Item "$root\src\server\*" "$prof\server" -Recurse -Force

    # a repo with every kind of change, a worktree, a detached checkout, kube configs, a history file
    $repo = Join-Path $work 'repo'
    New-Item -ItemType Directory -Force $repo, "$work\plain", "$work\chart", "$work\k8sroot\k8s", "$work\k8sroot\src" | Out-Null
    function G { param([Parameter(ValueFromRemainingArguments)][string[]]$a) & git -C $repo -c user.email= -c user.name=t -c commit.gpgsign=false -c core.autocrlf=false @a 2>&1 | Out-Null }
    G init -q -b main
    Set-Content "$repo\a.txt" 'a'; Set-Content "$repo\b.txt" 'b'
    G add .; G commit -q -m init
    G init -q --bare "$work\remote.git"
    G remote add origin "$work\remote.git"; G push -q -u origin main
    Set-Content "$repo\a.txt" 'stashed'; G stash -q
    Set-Content "$repo\b.txt" 'b2'; G commit -q -am second
    Set-Content "$repo\c.txt" 'c'; G add c.txt
    Set-Content "$repo\a.txt" 'changed'
    Set-Content "$repo\d.txt" 'd'
    G worktree add -q "$work\wt" -b wt-branch
    G worktree add -q --detach "$work\detached"
    & git -C "$work\k8sroot" init -q 2>&1 | Out-Null
    Set-Content "$work\chart\Chart.yaml" 'apiVersion: v2'
    $contexts = @"
contexts:
- name: kind-dev
  context: { cluster: dev, user: admin, namespace: shop }
- name: prod-eu
  context: { cluster: prod, user: admin }
clusters:
- name: dev
  cluster: { server: https://10.255.255.1:6443 }
- name: prod
  cluster: { server: https://10.255.255.2:6443 }
users:
- name: admin
  user: {}
"@
    "apiVersion: v1`nkind: Config`ncurrent-context: kind-dev`n$contexts" | Set-Content "$work\kube-dev"
    "apiVersion: v1`nkind: Config`ncurrent-context: prod-eu`n$contexts" | Set-Content "$work\kube-prod"
    $history = @(1..58 | ForEach-Object { "cmd-$_" }) + 'docker ps' + 'docker run `' + '  --rm x' + 'cmd-59' + 'cmd-60'
    [IO.File]::WriteAllLines("$work\history.txt", [string[]]$history)

    Invoke-Sandboxed $sandboxHome {
        Invoke-ChildTests { & pwsh -NoProfile -NoLogo -File (Join-Path $PSScriptRoot 'profile.tests.ps1') -Work $work }
    }
    Test 'profile loads in under 2 s (sandbox, warm caches)' {
        $ms = Invoke-Sandboxed $sandboxHome {
            [int](& pwsh -NoProfile -NoLogo -Command "`$sw = [Diagnostics.Stopwatch]::StartNew(); `$PROFILE = '$prof\Microsoft.PowerShell_profile.ps1'; . `$PROFILE *> `$null; `$sw.ElapsedMilliseconds")
        }
        Assert ($ms -lt 2000) "$ms ms"
        Write-Host "    $TcDim$ms ms including the deferred part$TcR"
    }
}

if ('setup' -in $Only) {
    Section 'installer (sandboxed, -SkipApps)'
    $setupHome = Join-Path $work 'setup-home'; New-SandboxHome $setupHome
    $pdir = Join-Path $work 'setup-profile'
    $setup = Join-Path $root 'setup-terminal.ps1'
    if (-not (Test-Path $setup)) { & (Join-Path $root 'build.ps1') | Out-Null }
    function Invoke-Setup([string[]]$Extra = @()) {
        Invoke-Sandboxed $setupHome {
            (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup -Lang ru -SkipApps -ProfileDir $pdir @Extra 2>&1 | ForEach-Object { "$_" }) -join "`n"
        }
    }
    $out1 = Invoke-Setup
    Test 'first run creates everything' {
        AssertMatch $out1 'Готово' 'finished'
        AssertNotMatch $out1 'ошибок при загрузке[^\n]*' 'profile check'
        AssertMatch $out1 'без ошибок' 'profile check'
        foreach ($f in 'Microsoft.PowerShell_profile.ps1', 'palette.ps1', 'lang.ps1', 'toolkit.ps1', 'toolkit-lazy.ps1', 'prompt.ps1', 'DeepHistoryPredictor.cs', 'custom.ps1', 'server\bashrc.local', 'server\inputrc', 'server\install.sh') { Assert (Test-Path (Join-Path $pdir $f)) $f }
        foreach ($d in 'bin', 'server\custom') { Assert (Test-Path (Join-Path $pdir $d) -PathType Container) $d }
        AssertEq (Get-Content (Join-Path $setupHome '.config\terminal-setup\lang') -First 1) 'ru' 'lang file'
    }
    Test 'windows terminal: schemes, default profile, font, quake binding' {
        $raw = Get-Content (Join-Path $setupHome 'AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json') -Raw
        $s = $raw | ConvertFrom-Json
        AssertEq $s.defaultProfile '{574e775e-4f2a-5b96-ac1e-a2962a402336}' 'default profile'
        Assert ($s.schemes.Count -ge 10) "schemes: $($s.schemes.Count)"
        AssertMatch $raw 'JetBrainsMono' 'font'
        AssertMatch $raw 'quake' 'quake binding'
    }
    Test 'second run changes nothing and keeps custom.ps1' {
        Add-Content (Join-Path $pdir 'custom.ps1') '# my own line'
        $out2 = Invoke-Setup
        AssertNotMatch $out2 'обновлён|создан' 'something was rewritten'
        AssertMatch (Get-Content (Join-Path $pdir 'custom.ps1') -Raw) '# my own line' 'custom.ps1 kept'
    }
    Test 'a changed file is restored with a backup next to it' {
        Add-Content (Join-Path $pdir 'toolkit.ps1') '# tampered'
        $out3 = Invoke-Setup
        AssertMatch $out3 'toolkit\.ps1 - обновлён' 'reported'
        Assert (Get-ChildItem $pdir -Filter 'toolkit.ps1.bak-*') 'backup made'
        AssertNotMatch (Get-Content (Join-Path $pdir 'toolkit.ps1') -Raw) '# tampered' 'restored'
    }
    Test 'uninstall removes its own files and keeps yours' {
        $null = Invoke-Setup @('-Uninstall')
        foreach ($f in 'Microsoft.PowerShell_profile.ps1', 'toolkit.ps1', 'prompt.ps1', 'server\bashrc.local') { Assert (-not (Test-Path (Join-Path $pdir $f))) "$f still there" }
        Assert (Test-Path (Join-Path $pdir 'custom.ps1')) 'custom.ps1 kept'
        Assert (Test-Path (Join-Path $pdir 'bin')) 'bin kept'
        Assert (-not (Test-Path (Join-Path $setupHome '.config\terminal-setup'))) 'config removed'
    }
}

if ('server' -in $Only) {
    Section 'server bash (WSL)'
    if (-not (Get-Command wsl -ErrorAction Ignore)) { Skip 'server tests' 'wsl not installed' }
    else {
        $toLinux = { param($p) (& wsl wslpath -a ($p -replace '\\', '/')).Trim() }
        Invoke-ChildTests { & wsl -e bash (& $toLinux (Join-Path $PSScriptRoot 'server.sh')) (& $toLinux (Join-Path $root 'src\server')) }
    }
}

$failed = Write-TestSummary
if (-not $Keep) { Remove-Item $work -Recurse -Force -ErrorAction Ignore } else { Write-Host "  $TcDim kept: $work$TcR" }
exit $failed
