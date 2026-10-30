<#
  In-process checks of the profile: prompt, input helpers, commands. run.ps1 starts this in a sandbox
  (USERPROFILE, APPDATA and LOCALAPPDATA point into a temp folder it prepared), so nothing here touches
  the real profile, Windows Terminal or caches.
#>
param([Parameter(Mandatory)][string]$Work)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'lib.ps1')

$PROFILE = Join-Path $Work 'profile\Microsoft.PowerShell_profile.ps1'
$env:KUBECONFIG = Join-Path $Work 'kube-none'
$Error.Clear()
. $PROFILE *> $null
$loadErrors = @($Error | ForEach-Object { $_.ToString() })
$Error.Clear()
$plain = Join-Path $Work 'plain'
$repo = Join-Path $Work 'repo'
$branchIcon = [string][char]0xE0A0
$kubeIcon = '󱃾'

Section 'profile'
Test 'loads without errors' { AssertEq $loadErrors.Count 0 "errors: $($loadErrors -join ' | ')" }
Test 'version and switches' {
    AssertMatch $global:TerminalSetupVersion '^\d+\.\d+\.\d+$' 'version'
    foreach ($k in 'Abbreviations', 'LayoutFix', 'Predictions', 'GitStatus', 'Kube') { Assert $global:TerminalSetup.ContainsKey($k) "switch $k" }
}
Test 'profile folder is the one the files are in' { AssertEq $global:ProfileDir (Join-Path $Work 'profile') 'ProfileDir' }
Test 'deferred part is loaded, no stub left behind' {
    Assert $global:TerminalSetupLoaded 'TerminalSetupLoaded'
    foreach ($n in 'help', 'my', 'h', 'jump', 'srv', 'theme', 'lang', 'new', 'nav', 'pv', 'rgi', 'pk', 'gbr', 'o', 'kctx', 'kns', 'doctor', 'update', 'ex', 'bak', 'psg', 'cb', 'ep') {
        $cmd = Get-Command $n -ErrorAction Ignore
        Assert $cmd "$n missing"
        AssertNotMatch "$($cmd.ScriptBlock)" 'Complete-TerminalSetup; &' "$n is still a stub"
    }
}
Test 'sourcing the profile again is safe' {
    $before = $Error.Count
    . $PROFILE *> $null
    AssertEq ($Error.Count - $before) 0 'errors on reload'
    Assert $global:TerminalSetupLoaded 'deferred part after reload'
    AssertNotMatch "$((Get-Command help).ScriptBlock)" 'Complete-TerminalSetup; &' 'help turned back into a stub'
}
Test 'aliases and shortcuts exist' {
    foreach ($n in 'l', 'll', 'lt', '..', '...', '....', 'mkcd', 'which', 'touch', 'lg', 'gst', 'reload') { Assert (Get-Command $n -ErrorAction Ignore) $n }
}
$gitLess = Join-Path $env:ProgramFiles 'Git\usr\bin\less.exe'
if (Test-Path $gitLess) { Test 'bat pages through the less that ships with git' { AssertMatch $env:BAT_PAGER 'Git\\usr\\bin\\less\.exe" -RF$' 'BAT_PAGER' } }
else { Skip 'bat pager' 'git less not installed' }

Section 'strings'
Test 'ru and en have the same keys, sections and rows' {
    $ru = $global:Strings.ru; $en = $global:Strings.en
    $only = @($ru.Keys | Where-Object { -not $en.ContainsKey($_) }) + @($en.Keys | Where-Object { -not $ru.ContainsKey($_) })
    AssertEq ($only -join ',') '' 'keys present in one language only'
    AssertEq $en.sections.Count $ru.sections.Count 'section count'
    for ($i = 0; $i -lt $ru.sections.Count; $i++) {
        AssertEq $en.sections[$i].Key $ru.sections[$i].Key "section $i key"
        AssertEq $en.sections[$i].Rows.Count $ru.sections[$i].Rows.Count "rows in section $($ru.sections[$i].Key)"
    }
    AssertEq (@($en.my_topics.get_Keys()) -join ',') (@($ru.my_topics.get_Keys()) -join ',') 'my topics'
}
Test 'every string the code uses exists in both languages' {
    $code = (Get-Content (Join-Path $Work 'profile\toolkit-lazy.ps1'), (Join-Path $Work 'profile\toolkit.ps1'), (Join-Path $Work 'profile\prompt.ps1'), $PROFILE -Raw) -join "`n"
    $used = [regex]::Matches($code, '\$TkStr\.([A-Za-z_]\w*)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    Assert ($used.Count -gt 50) "only $($used.Count) string references found"
    $missing = @($used | Where-Object { -not $global:Strings.ru.ContainsKey($_) -or -not $global:Strings.en.ContainsKey($_) })
    AssertEq ($missing -join ',') '' 'used but not defined'
}

Section 'palette'
Test 'ten themes with the same color slots' {
    Assert ($Themes.Count -ge 10) "only $($Themes.Count) themes"
    $ref = @($Themes.mocha.Keys | Sort-Object) -join ','
    foreach ($name in $Themes.Keys) {
        AssertEq (@($Themes[$name].Keys | Sort-Object) -join ',') $ref "$name slots"
        Assert $Themes[$name].title "$name title"
    }
}
Test 'terminal schemes carry all sixteen colors' {
    foreach ($name in $Themes.Keys) {
        $s = Get-TerminalScheme $name
        AssertEq $s.name $Themes[$name].title "$name scheme name"
        foreach ($k in 'background', 'foreground', 'cursorColor', 'selectionBackground', 'black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white', 'brightBlack', 'brightRed', 'brightGreen', 'brightYellow', 'brightBlue', 'brightPurple', 'brightCyan', 'brightWhite') {
            AssertMatch "$($s.$k)" '^#[0-9A-Fa-f]{6}$' "$name.$k"
        }
    }
}

Section 'prompt'
Test 'three lines, branch read from .git/HEAD' {
    $lines = (Get-TsPrompt -Dir $repo -Width 100) -split "`n"
    AssertEq $lines.Count 3 'lines'
    AssertMatch (Plain $lines[1]) "repo\s+$branchIcon main" 'path and branch'
    AssertMatch (Plain $lines[2]) '^╰─❯ $' 'arrow line'
}
Test 'git counts: staged, modified, untracked, ahead, stash' {
    Update-TsGitStatus $repo
    $t = Plain $global:TsGit.Text
    foreach ($x in '\+1', '~1', '\?1', '⇡1', '≡1') { AssertMatch $t $x 'counts' }
    AssertEq $global:TsGit.Pending '' 'pending cleared'
}
Test 'fresh counts are shown, stale ones stay until the refresh' {
    $global:TsGit.Time = [datetime]::Now
    AssertMatch (Plain (Get-TsPrompt -Dir $repo -Width 100)) 'main \+1 ~1 \?1 ⇡1 ≡1' 'fresh'
    AssertEq $global:TsGit.Pending '' 'no refresh requested'
    $global:TsGit.Time = [datetime]::Now.AddSeconds(-10)
    AssertMatch (Plain (Get-TsPrompt -Dir $repo -Width 100)) 'main \+1 ~1' 'stale still shown'
    AssertEq $global:TsGit.Pending $repo 'refresh requested'
    $global:TsGit.Pending = ''
}
Test 'background git status leaves $LASTEXITCODE alone' {
    $global:LASTEXITCODE = 42
    Update-TsGitStatus $repo
    AssertEq $global:LASTEXITCODE 42 'LASTEXITCODE'
}
Test 'worktree and detached HEAD' {
    AssertMatch (Plain (Get-TsPrompt -Dir (Join-Path $Work 'wt') -Width 100)) "$branchIcon wt-branch" 'worktree branch'
    $d = Plain (Get-TsPrompt -Dir (Join-Path $Work 'detached') -Width 100)
    AssertMatch $d "$branchIcon [0-9a-f]{7}\b" 'short sha'
    AssertNotMatch $d "$branchIcon main" 'no branch name'
}
Test 'outside git there is no branch segment' {
    AssertEq (Get-TsGitRoot $plain) '' 'root'
    AssertNotMatch (Plain (Get-TsPrompt -Dir $plain -Width 100)) $branchIcon 'branch icon'
}
Test 'exit code, duration, right alignment, arrow color' {
    $l = (Plain (Get-TsPrompt -Dir $plain -Status 3 -Ms 2500 -Width 100)) -split "`n"
    AssertMatch $l[1] "$([char]0xF017) 2\.5s\s+✘ 3$" 'duration and code'
    AssertMatch $l[1] "$([char]0xF07B) " 'folder icon'
    Assert ($l[1].Length -le 100) "line longer than the width: $($l[1].Length)"
    AssertMatch (Plain (Get-TsPrompt -Dir $plain -Ms 65000 -Width 100)) '1m 5s' 'minutes'
    AssertNotMatch (Plain (Get-TsPrompt -Dir $plain -Ms 1500 -Width 100)) '\d+s' 'short commands show no time'
    $raw = (Get-TsPrompt -Dir $plain -Status 1 -Width 100) -split "`n"
    AssertMatch $raw[2] ([regex]::Escape($global:TK.err) + '❯') 'red arrow on error'
    AssertMatch ((Get-TsPrompt -Dir $plain -Width 100) -split "`n")[2] ([regex]::Escape($global:TK.ok) + '❯') 'green arrow'
}
Test 'short path' {
    AssertEq (Get-TsShortPath (Join-Path $HOME 'a\b\c\d\e')) '~\..\c\d\e' 'deep home path'
    AssertEq (Get-TsShortPath (Join-Path $HOME 'x')) '~\x' 'home path'
    AssertEq (Get-TsShortPath 'D:\x\y') 'D:\x\y' 'short absolute path'
}
Test 'project markers show the tool version' {
    $markers = @(
        @{ tool = 'node'; file = 'package.json'; re = "$([char]0xE718) \d+" }
        @{ tool = 'python'; file = 'pyproject.toml'; re = "$([char]0xE73C) \d+\.\d+" }
        @{ tool = 'go'; file = 'go.mod'; re = "$([char]0xE627) \d+\.\d+" }
        @{ tool = 'rustc'; file = 'Cargo.toml'; re = "$([char]0xE7A8) \d+\.\d+" }
    )
    $checked = @()
    foreach ($m in $markers) {
        $cmd = Get-Command $m.tool -ErrorAction Ignore
        if (-not $cmd -or $cmd.Source -like '*WindowsApps*') { continue }
        $dir = Join-Path $Work "proj-$($m.tool)"; New-Item -ItemType Directory -Force $dir | Out-Null; Set-Content (Join-Path $dir $m.file) ''
        AssertMatch (Plain (Get-TsPrompt -Dir $dir -Width 100)) $m.re $m.tool
        $checked += $m.tool
    }
    Write-Host "    $TcDim$(if ($checked) { $checked -join ', ' } else { 'no language tool installed, nothing checked' })$TcR"
}
Test 'kube: k8s folders only, prod in red everywhere, switch honored' {
    $env:KUBECONFIG = Join-Path $Work 'kube-dev'
    AssertNotMatch (Plain (Get-TsPrompt -Dir $plain -Width 100)) $kubeIcon 'plain folder'
    AssertMatch (Plain (Get-TsPrompt -Dir (Join-Path $Work 'chart') -Width 100)) "$kubeIcon kind-dev/shop" 'chart folder'
    AssertMatch (Plain (Get-TsPrompt -Dir (Join-Path $Work 'k8sroot\src') -Width 100)) "$kubeIcon kind-dev" 'k8s folder at the repo root'
    $global:TerminalSetup.Kube = 'off'
    AssertNotMatch (Plain (Get-TsPrompt -Dir (Join-Path $Work 'chart') -Width 100)) $kubeIcon 'Kube = off'
    $global:TerminalSetup.Kube = 'always'
    AssertMatch (Plain (Get-TsPrompt -Dir $plain -Width 100)) "$kubeIcon kind-dev" 'Kube = always'
    $global:TerminalSetup.Kube = 'auto'
    $env:KUBECONFIG = Join-Path $Work 'kube-prod'
    $raw = Get-TsPrompt -Dir $plain -Width 100
    AssertMatch (Plain $raw) "$kubeIcon prod-eu" 'prod everywhere'
    AssertMatch $raw ([regex]::Escape($global:TK.err) + $kubeIcon) 'prod in red'
    $env:KUBECONFIG = Join-Path $Work 'kube-none'
}
Test 'prompt function: exit code, redraw, no stale code after a cmdlet error' {
    Set-Location $plain
    Clear-History
    cmd /c exit 3
    AssertMatch (Plain (prompt)) '✘ 3' 'native exit code'
    $global:TsRedraw = $true
    AssertMatch (Plain (prompt)) '✘ 3' 'redraw keeps the code'
    Assert (-not $global:TsRedraw) 'redraw flag reset'
    Get-Item (Join-Path $plain 'no-such-file') -ErrorAction SilentlyContinue
    $p = Plain (prompt)
    AssertMatch $p '✘ 1' 'cmdlet error shown as a plain failure'
    AssertNotMatch $p '✘ 3' 'stale native code'
    Add-History ([pscustomobject]@{ CommandLine = 'cmd /c exit 3'; ExecutionStatus = 'Completed'; StartExecutionTime = Get-Date; EndExecutionTime = Get-Date })
    cmd /c exit 3
    AssertMatch (Plain (prompt)) '✘ 3' 'same code twice from an executable'
    Get-Date | Out-Null
    AssertNotMatch (Plain (prompt)) '✘' 'success clears it'
}
Test 'prompt renders in under 25 ms' {
    $global:TsGit.Time = [datetime]::Now
    $null = Get-TsPrompt -Dir $repo -Width 100
    $sw = [Diagnostics.Stopwatch]::StartNew()
    1..20 | ForEach-Object { $null = Get-TsPrompt -Dir $repo -Width 100 }
    $avg = $sw.ElapsedMilliseconds / 20
    Assert ($avg -lt 25) "avg $avg ms"
    Write-Host "    $TcDim$avg ms$TcR"
}
if (Get-Command kubectl -ErrorAction Ignore) {
    Test 'kctx switches the context and the prompt follows' {
        $env:KUBECONFIG = Join-Path $Work 'kube-dev'
        kctx prod-eu *> $null
        AssertMatch (Plain (Get-TsKubeText)) 'prod-eu' 'after kctx'
        kctx kind-dev *> $null
        AssertMatch (Plain (Get-TsKubeText)) 'kind-dev' 'back'
        $env:KUBECONFIG = Join-Path $Work 'kube-none'
    }
} else { Skip 'kctx' 'kubectl not installed' }

Section 'input'
Test 'abbreviations expand only at the command position' {
    $e = Expand-Abbreviation 'g' 1
    AssertEq $e.Text 'git' 'g'; AssertEq $e.Start 0 'start'; AssertEq $e.Length 1 'length'
    AssertEq (Expand-Abbreviation 'echo g' 6) $null 'argument position'
    AssertEq (Expand-Abbreviation 'ls | g' 6).Text 'git' 'after a pipe'
    AssertEq (Expand-Abbreviation 'gx' 2) $null 'unknown word'
    $e = Expand-Abbreviation 'gcm' 3
    AssertMatch $e.Text '^git commit -m' 'gcm'
    Assert ($e.Cursor -gt 0) 'cursor marker honored'
}
Test 'abbr adds and removes' {
    abbr zz 'echo zz'
    AssertEq (Expand-Abbreviation 'zz' 2).Text 'echo zz' 'added'
    abbr zz -Remove
    AssertEq (Expand-Abbreviation 'zz' 2) $null 'removed'
}
Test 'russian layout is fixed only when it makes a real command' {
    AssertEq (Repair-CommandLayout 'пше ыефегы') 'git status' 'пше ыефегы'
    AssertEq (Repair-CommandLayout 'git status') $null 'already english'
    AssertEq (Repair-CommandLayout 'ыыыы') $null 'not a command'
    AssertEq (Convert-Layout 'вщслук') 'docker' 'layout map'
}

Section 'commands'
$wt = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
Test 'theme switches the palette, the file and Windows Terminal' {
    theme gruvbox *> $null
    AssertEq $global:ThemeName 'gruvbox' 'name'
    AssertEq (Get-Content $ThemeFile -First 1) 'gruvbox' 'theme file'
    AssertEq $global:TK.ok (_tkRgb $Themes.gruvbox.green) 'palette color'
    AssertMatch (Get-Content $wt -Raw) "`"colorScheme`": `"$($Themes.gruvbox.title)`"" 'wt colorScheme'
    $null = Capture { theme nope }
    AssertEq $global:ThemeName 'gruvbox' 'unknown theme ignored'
    theme mocha *> $null
    AssertEq $global:ThemeName 'mocha' 'back'
}
Test 'lang switches help and messages' {
    lang en *> $null
    AssertEq $global:LangName 'en' 'name'
    AssertEq (Get-Content $global:LangFile -First 1) 'en' 'lang file'
    AssertEq $global:TkStr.help_title $global:Strings.en.help_title 'strings'
    AssertMatch (Plain (Capture { help })) ([regex]::Escape($global:Strings.en.sections[0].Title)) 'help in english'
    lang ru *> $null
    AssertEq $global:TkStr.help_title $global:Strings.ru.help_title 'back to ru'
}
Test 'help: a section, a search, nothing found' {
    $git = $global:TkStr.sections | Where-Object Key -eq 'git'
    AssertMatch (Plain (Capture { help git })) ([regex]::Escape($git.Title)) 'section by key'
    AssertMatch (Plain (Capture { help bak })) '\bbak\b' 'search'
    AssertMatch (Plain (Capture { help qqqzzz })) ([regex]::Escape($global:TkStr.nothing_found)) 'nothing found'
}
Test 'new makes a command from a template, bin never shadows a real command' {
    new hello.py 'say hi' *> $null
    $file = Join-Path $global:ProfileDir 'bin\hello.py'
    Assert (Test-Path $file) 'file created'
    AssertMatch (Get-Content $file -Raw) '# help: say hi' 'help line'
    AssertEq (Get-Command hello -ErrorAction Ignore).CommandType 'Function' 'hello is a command'
    AssertMatch (Plain (Capture { my cmds })) 'hello\s+say hi' 'listed in my cmds'
    AssertMatch (Plain (Capture { help })) 'hello' 'listed in help'
    new git.py 'nope' *> $null
    Assert (-not (Test-Path (Join-Path $global:ProfileDir 'bin\git.py'))) 'git.py refused'
    Set-Content (Join-Path $global:ProfileDir 'bin\git.ps1') '# help: shadow'
    Register-BinCommands (Join-Path $global:ProfileDir 'bin')
    AssertEq (Get-Command git).CommandType 'Application' 'git is still the real one'
    new 'bad name.py' *> $null
    Assert (-not (Test-Path (Join-Path $global:ProfileDir 'bin\bad name.py'))) 'bad name refused'
}
Test 'ex and bak' {
    $dir = Join-Path $Work 'arch'; New-Item -ItemType Directory -Force "$dir\src" | Out-Null
    Set-Content "$dir\src\a.txt" 'hello'
    Push-Location $dir
    try {
        tar -czf pack.tar.gz -C src a.txt
        ex pack.tar.gz *> $null
        Assert (Test-Path "$dir\pack\a.txt") 'extracted into a folder of its own name'
        AssertMatch (Plain (Capture { ex nope.zip })) ([regex]::Escape(($global:TkStr.ex_nofile -f 'nope.zip'))) 'missing archive'
        AssertMatch (Plain (Capture { ex src\a.txt })) 'a\.txt' 'unknown format reported'
        bak src\a.txt *> $null
        Assert (Get-ChildItem "$dir\src" -Filter 'a.txt.bak-*') 'bak copy'
    } finally { Pop-Location }
}
Test 'psg, Format-TkSize, Invoke-WithTimeout' {
    AssertMatch (psg pwsh | Out-String) "\b$PID\b" 'psg finds this process'
    AssertMatch (Format-TkSize 1536) "^1[.,]5 $($global:TkStr.units[1])$" 'KB'
    AssertMatch (Format-TkSize 1073741824) "^1([.,]0)? $($global:TkStr.units[3])$" 'GB'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-WithTimeout pwsh @('-NoProfile', '-Command', 'Start-Sleep 5') 500
    Assert ($sw.ElapsedMilliseconds -lt 4000) "took $($sw.ElapsedMilliseconds) ms"
    AssertEq "$r" '' 'nothing returned on timeout'
}
Test 'h reads PSReadLine history: newest first, filtered, multi-line' {
    Import-Module PSReadLine -ErrorAction Stop
    Set-PSReadLineOption -HistorySavePath (Join-Path $Work 'history.txt')
    $out = Plain (Capture { h })
    AssertEq ([regex]::Matches($out, '(?m)^\s+\d+\s{2}').Count) 50 '50 entries'
    AssertMatch $out '(?m)^\s+1\s{2}cmd-60' 'newest first'
    $f = Plain (Capture { h docker })
    AssertMatch $f 'docker ps' 'filter keeps matches'
    AssertNotMatch $f 'cmd-' 'filter drops the rest'
    AssertMatch $f 'docker run' 'multi-line entry'
}
Test 'doctor: files ok, a broken custom.ps1 is reported' {
    $out = Plain (Capture { doctor })
    AssertNotMatch $out ('✗ ' + [regex]::Escape($global:TkStr.doctor_files)) 'files'
    AssertNotMatch $out ('✗ ' + [regex]::Escape($global:TkStr.doctor_custom)) 'custom ok'
    $custom = Join-Path $global:ProfileDir 'custom.ps1'
    $saved = Get-Content $custom -Raw
    Add-Content $custom 'function broken {'
    try { AssertMatch (Plain (Capture { doctor })) ('✗ ' + [regex]::Escape($global:TkStr.doctor_custom)) 'broken custom reported' }
    finally { Set-Content $custom $saved -NoNewline }
}
Test 'my: every topic runs without errors' {
    foreach ($topic in 'sys', 'ip', 'ports', 'path', 'tools', 'git', 'cmds', 'config', 'ssh', 'k8s', 'docker') {
        $r = Run { my $topic }
        AssertEq $r.Errors.Count 0 "my $topic`: $($r.Errors -join ' | ')"
    }
    AssertMatch (Plain (Capture { my config })) ([regex]::Escape($global:ProfileDir)) 'my config shows the profile folder'
    AssertMatch (Plain (Capture { my sys })) '[█░]' 'my sys draws bars'
}
Test 'srv without arguments explains itself' {
    $r = Run { srv }
    AssertEq $r.Errors.Count 0 'errors'
    AssertMatch (Plain $r.Text) 'srv install' 'usage'
}
Test 'completion cache gets the global marker' {
    $global:CompletionGenerators['pwsh'] = { "function Foo-Bar { 1 }`nRegister-ArgumentCompleter -CommandName pwsh -ScriptBlock {}" }
    $file = Join-Path $HOME '.cache\pwsh-completions\pwsh.ps1'
    try {
        Update-Completions *> $null
        $text = Get-Content $file -Raw
        AssertMatch $text '^# global' 'marker'
        AssertMatch $text 'function global:Foo-Bar' 'rewritten to global'
    } finally { $global:CompletionGenerators.Remove('pwsh'); Remove-Item $file -ErrorAction Ignore }
}
if ((Get-Command bat -ErrorAction Ignore) -and (Get-Command eza -ErrorAction Ignore)) {
    Test 'fzf preview script shows files and folders, Cyrillic included' {
        $pv = Get-TsPreview
        Assert (Test-Path $pv) 'preview.cmd exists'
        $dir = Join-Path $Work 'кириллица'; New-Item -ItemType Directory -Force $dir | Out-Null
        Set-Content (Join-Path $dir 'файл.txt') 'privet-mir' -Encoding utf8
        AssertMatch (Plain ((& $pv (Join-Path $dir 'файл.txt')) -join "`n")) 'privet-mir' 'file preview'
        AssertMatch (Plain ((& $pv $dir) -join "`n")) 'файл\.txt' 'folder preview'
    }
} else { Skip 'fzf preview script' 'bat or eza not installed' }

exit (Write-TestSummary -Machine)
