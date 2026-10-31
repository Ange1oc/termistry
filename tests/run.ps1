<#
  Runs every check that does not need a human at the keyboard: static scans, the profile in a sandbox,
  the installer in a sandbox and the server bash in WSL. The real profile, Windows Terminal and caches
  are never touched.
    .\tests\run.ps1                    everything
    .\tests\run.ps1 -Only profile      static | profile | setup | server
    .\tests\run.ps1 -Keep              leave the sandbox folder behind for a look
#>
param([string[]]$Only = @('static', 'profile', 'setup', 'server'), [switch]$Keep)
$ErrorActionPreference = 'Stop'
$Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($o in $Only) { if ($o -notin 'static', 'profile', 'setup', 'server') { throw "-Only: static, profile, setup, server (got '$o')" } }
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'lib.ps1')
$root = Split-Path $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) "termistry-tests-$PID"
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
    New-Item -ItemType Directory -Force $wt, (Join-Path $SandboxHome '.config\termistry'), (Join-Path $SandboxHome 'AppData\Roaming') | Out-Null
    @'
{
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles": { "defaults": {}, "list": [ { "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}", "name": "PowerShell", "colorScheme": "Catppuccin Mocha" } ] },
    "schemes": [],
    "actions": []
}
'@ | Set-Content (Join-Path $wt 'settings.json') -Encoding utf8
    Set-Content (Join-Path $SandboxHome '.config\termistry\theme') 'mocha'
    Set-Content (Join-Path $SandboxHome '.config\termistry\lang') 'ru'
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
    Test 'build.ps1 and the profile agree on the managed files' {
        $build = Get-Content (Join-Path $root 'build.ps1') -Raw
        $built = [regex]::Matches($build, "(?m)^\s+'([^']+)'\s+= 'src\\") | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne 'custom.ps1' }
        $profile = Get-Content (Join-Path $root 'src\profile\Microsoft.PowerShell_profile.ps1') -Raw
        Assert ($profile -match "(?m)^\`$global:TsFiles = (.+)$") 'TsFiles not found'
        $listed = [regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }
        AssertEq ($built -join ',') ($listed -join ',') 'same files in the same order'
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
    G branch feature
    Add-Content "$prof\custom.ps1" "`nfunction deploy-demo { 'demo' }`nabbr dd 'docker compose down'"
    New-Item -ItemType Directory -Force "$sandboxHome\.ssh" | Out-Null
    @'
# hosts for the tests
Host prod
    HostName 10.0.0.1
    User root
    Port 2222
    IdentityFile ~/.ssh/id_prod
Host staging
  HostName=staging.example.com
  User deploy
Host db web
    User deploy
Match host prod
    User ignored
Host db
    User later
Host *
    ServerAliveInterval 30
'@ | Set-Content "$sandboxHome\.ssh\config"
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
    Test 'a broken custom.ps1 does not take the profile down' {
        $broken = Join-Path $work 'profile-broken'
        Copy-Item $prof $broken -Recurse
        Add-Content "$broken\custom.ps1" 'function broken {'
        $out = Invoke-Sandboxed $sandboxHome {
            & pwsh -NoProfile -NoLogo -Command "`$PROFILE = '$broken\Microsoft.PowerShell_profile.ps1'; . `$PROFILE 3>&1 2>&1 | Out-String; (Get-Command help).CommandType; (prompt).Split([char]10).Count" 2>&1 | ForEach-Object { "$_" }
        }
        AssertMatch ($out -join "`n") 'custom\.ps1' 'warning names the file'
        AssertMatch ($out -join "`n") 'Function' 'commands still defined'
        AssertMatch ($out -join "`n") '(?m)^3$' 'prompt still renders'
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
    $ompConfig = Join-Path $setupHome '.config\ohmyposh\soft.omp.json'   # the user's own Oh My Posh theme
    New-Item -ItemType Directory -Force (Split-Path $ompConfig) | Out-Null; Set-Content $ompConfig '{}'
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
        AssertEq (Get-Content (Join-Path $setupHome '.config\termistry\lang') -First 1) 'ru' 'lang file'
    }
    Test 'windows terminal: schemes, default profile, font, quake binding' {
        $raw = Get-Content (Join-Path $setupHome 'AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json') -Raw
        $s = $raw | ConvertFrom-Json
        AssertEq $s.defaultProfile '{574e775e-4f2a-5b96-ac1e-a2962a402336}' 'default profile'
        Assert ($s.schemes.Count -ge 10) "schemes: $($s.schemes.Count)"
        # without the Nerd Font (CI) the installer falls back to Cascadia Mono
        AssertMatch $raw $(if (Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-Regular.ttf") { 'JetBrainsMono' } else { 'Cascadia Mono' }) 'font'
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
        Assert (-not (Test-Path (Join-Path $setupHome '.config\termistry'))) 'config removed'
        Assert (Test-Path $ompConfig) 'Oh My Posh config kept through install and uninstall'
    }

    # a second machine: english, a theme, ssh tabs, a starting folder, and settings the user already had
    $setupHome2 = Join-Path $work 'setup-home2'; New-SandboxHome $setupHome2
    $wt2 = Join-Path $setupHome2 'AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    @'
{
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles": [
        { "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}", "name": "Windows PowerShell", "colorScheme": "Campbell" },
        { "guid": "{11111111-2222-3333-4444-555555555555}", "name": "My Ubuntu", "commandline": "wsl -d Ubuntu", "colorScheme": "MyScheme" }
    ],
    "schemes": [ { "name": "MyScheme", "background": "#000000", "foreground": "#FFFFFF" } ],
    "actions": [ { "command": "paste", "keys": "ctrl+v" } ]
}
'@ | Set-Content $wt2 -Encoding utf8
    $vs2 = Join-Path $setupHome2 'AppData\Roaming\Code\User\settings.json'
    New-Item -ItemType Directory -Force (Split-Path $vs2) | Out-Null
    '{ "editor.fontSize": 14, "terminal.integrated.fontFamily": "Consolas" }' | Set-Content $vs2 -Encoding utf8
    $pdir2 = Join-Path $work 'setup-profile2'
    $git2 = Join-Path $setupHome2 '.gitconfig'
    if (Get-Command git -ErrorAction Ignore) {
        git config --file $git2 delta.minus-style 'bold red'                # the user's own
        git config --file $git2 delta.plus-style 'syntax "#323C3F"'         # left by the first version
    }
    $out5 =Invoke-Sandboxed $setupHome2 {
        (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup -Lang en -Theme gruvbox -SshTabs prod,staging -StartingDirectory 'D:\code' -SkipApps -ProfileDir $pdir2 2>&1 | ForEach-Object { "$_" }) -join "`n"
    }
    Test 'english run with a theme, ssh tabs and a starting folder' {
        AssertMatch $out5 'Done[.,]' 'english messages'
        AssertEq (Get-Content (Join-Path $setupHome2 '.config\termistry\lang') -First 1) 'en' 'lang file'
        AssertEq (Get-Content (Join-Path $setupHome2 '.config\termistry\theme') -First 1) 'gruvbox' 'theme file'
        $s = Get-Content $wt2 -Raw | ConvertFrom-Json
        AssertEq $s.profiles.defaults.colorScheme 'Gruvbox Dark' 'default scheme'
        AssertEq $s.theme 'Gruvbox Dark' 'window theme'
        $pw = $s.profiles.list | Where-Object guid -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
        AssertEq $pw.startingDirectory 'D:\code' 'starting folder'
        foreach ($h in 'prod', 'staging') { Assert ($s.profiles.list | Where-Object commandline -eq "ssh $h") "tab for $h" }
    }
    Test 'settings the user already had survive' {
        $s = Get-Content $wt2 -Raw | ConvertFrom-Json
        Assert ($s.profiles.list | Where-Object name -eq 'My Ubuntu') 'own profile kept'
        Assert ($s.schemes | Where-Object name -eq 'MyScheme') 'own scheme kept'
        Assert ($s.actions | Where-Object command -eq 'paste') 'own action kept'
        Assert ($s.actions | Where-Object command -eq 'quakeMode') 'quake added next to it'
        $vs = Get-Content $vs2 -Raw | ConvertFrom-Json
        AssertEq $vs.'editor.fontSize' 14 'vs code setting kept'
        AssertMatch $vs.'terminal.integrated.fontFamily' 'JetBrainsMono|Cascadia' 'terminal font replaced'
        Assert (Get-ChildItem (Split-Path $vs2) -Filter 'settings.json.bak-*') 'vs code backup made'
    }
    if ((Get-Command git -ErrorAction Ignore) -and (Get-Command delta -ErrorAction Ignore)) {
        Test 'git gets delta as its pager in the sandbox home' {
            AssertMatch (Get-Content (Join-Path $setupHome2 '.gitconfig') -Raw) '(?m)^\s*pager = delta' 'core.pager'
            AssertMatch $out5 'settings changed: \d+' 'reported'
            $out6 = Invoke-Sandboxed $setupHome2 { (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup -Lang en -SkipApps -ProfileDir $pdir2 2>&1 | ForEach-Object { "$_" }) -join "`n" }
            AssertMatch $out6 '\.gitconfig - unchanged' 'second run leaves git alone'
        }
        Test 'git: only the colors the first version set are removed' {
            AssertEq (git config --file $git2 --get delta.minus-style) 'bold red' 'own style kept'
            AssertEq (git config --file $git2 --get delta.plus-style) $null 'old style removed'
        }
    } else { Skip 'git delta config' 'git or delta not installed' }

    # an install from before the rename: settings in .config\terminal-setup, custom.ps1 using $TerminalSetup
    $setupHome3 = Join-Path $work 'setup-home3'; New-SandboxHome $setupHome3
    $pdir3 = Join-Path $work 'setup-profile3'
    Move-Item (Join-Path $setupHome3 '.config\termistry') (Join-Path $setupHome3 '.config\terminal-setup')
    Set-Content (Join-Path $setupHome3 '.config\terminal-setup\lang') 'en'
    Set-Content (Join-Path $setupHome3 '.config\terminal-setup\theme') 'dracula'
    New-Item -ItemType Directory -Force (Join-Path $setupHome3 '.cache\terminal-setup'), $pdir3 | Out-Null
    Set-Content (Join-Path $pdir3 'custom.ps1') '$TerminalSetup.Kube = ''off'''
    $out7 = Invoke-Sandboxed $setupHome3 { (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup -SkipApps -ProfileDir $pdir3 2>&1 | ForEach-Object { "$_" }) -join "`n" }
    Test 'an install from before the rename moves over' {
        AssertMatch $out7 'Done[.,]' 'english without asking'
        AssertNotMatch $out7 'errors while loading' 'profile check'
        Assert (-not (Test-Path (Join-Path $setupHome3 '.config\terminal-setup'))) 'old settings folder left'
        Assert (-not (Test-Path (Join-Path $setupHome3 '.cache\terminal-setup'))) 'old cache left'
        AssertEq (Get-Content (Join-Path $setupHome3 '.config\termistry\theme') -First 1) 'dracula' 'theme kept'
        $kube = Invoke-Sandboxed $setupHome3 { & pwsh -NoProfile -Command ". '$pdir3\Microsoft.PowerShell_profile.ps1' *> `$null; . '$pdir3\custom.ps1'; `$Termistry.Kube" }
        AssertEq "$kube".Trim() 'off' '$TerminalSetup in an old custom.ps1'
    }
}

if ('server' -in $Only) {
    Section 'server bash (WSL)'
    if (-not (Get-Command wsl -ErrorAction Ignore)) { Skip 'server tests' 'wsl not installed' }
    else {
        $toLinux = { param($p) (& wsl wslpath -a ($p -replace '\\', '/')).Trim() }
        Invoke-ChildTests { & wsl -e bash (& $toLinux (Join-Path $PSScriptRoot 'server.sh')) (& $toLinux (Join-Path $root 'src\server')) }
        $srvScript = Join-Path $work 'srv-script.sh'
        if (Test-Path $srvScript) {
            Test 'the script srv built on Windows installs on a Linux box' {
                $out = (& wsl -e bash -c "export HOME=`$(mktemp -d); bash '$(& $toLinux $srvScript)' 2>&1; echo EXIT=`$?") -join "`n"
                AssertMatch $out 'EXIT=0' 'exit code'
                AssertMatch $out 'label: prod · language: en' 'label and language'
                AssertMatch $out '~/\.bashrc\.local' 'bashrc installed'
                AssertMatch $out 'reconnect over ssh' 'finished'
            }
        } else { Skip 'srv script on Linux' 'needs the profile tests in the same run' }
    }
}

$failed = Write-TestSummary
if (-not $Keep) { Remove-Item $work -Recurse -Force -ErrorAction Ignore } else { Write-Host "  $TcDim kept: $work$TcR" }
exit $failed
