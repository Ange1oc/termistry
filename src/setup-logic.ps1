<#
.SYNOPSIS
  Termistry: a good-looking, convenient terminal on Windows 11 in one command. Safe to run again.
  Repository: https://github.com/Ange1oc/termistry

.EXAMPLE
  irm https://raw.githubusercontent.com/Ange1oc/termistry/master/install.ps1 | iex
.EXAMPLE
  .\setup-terminal.ps1 -Lang en -Theme latte -StartingDirectory D:\code -SshTabs prod,staging

.PARAMETER Lang
  UI language: ru or en. Asked interactively when omitted. Later: lang en
.PARAMETER Theme
  Catppuccin flavor: mocha (default), macchiato, frappe or latte. Later: theme latte
.PARAMETER StartingDirectory
  Folder a new PowerShell 7 tab opens in.
.PARAMETER SshTabs
  Hosts from ~/.ssh/config that get a tab in the Windows Terminal menu.
.PARAMETER SkipApps
  Only configs - no programs, no font.
.PARAMETER Uninstall
  Remove the managed profile files and caches. custom.ps1, bin\, installed programs and *.bak files stay.
.PARAMETER ProfileDir
  Put the profile files somewhere other than the $PROFILE folder (used by the tests).
#>
param(
    [ValidateSet('', 'ru', 'en')][string]$Lang = '',
    [string]$Theme = '',
    [string]$StartingDirectory,
    [string[]]$SshTabs = @(),
    [switch]$SkipApps,
    [switch]$Uninstall,
    [string]$ProfileDir = ''
)

$ErrorActionPreference = 'Stop'
$SetupVersion = '__VERSION__'
$ProgressPreference = 'SilentlyContinue'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$SshTabs = @($SshTabs | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$ConfigDir = Join-Path $HOME '.config\termistry'
# Settings of an install from before the rename (terminal-setup) move over as they are
$LegacyDirs = (Join-Path $HOME '.config\terminal-setup'), (Join-Path $HOME '.cache\terminal-setup')
if ((Test-Path $LegacyDirs[0]) -and -not (Test-Path $ConfigDir)) { Move-Item $LegacyDirs[0] $ConfigDir }

function Test-Command([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

if (-not $Lang) {
    $saved = Join-Path $ConfigDir 'lang'
    if (Test-Path $saved) { $Lang = (Get-Content $saved -First 1).Trim() }
}
if ($Lang -notin 'ru', 'en') {
    $default = if ((Get-Culture).TwoLetterISOLanguageName -eq 'ru') { 'ru' } else { 'en' }
    $Lang = $default
    if (-not [Console]::IsInputRedirected) {
        $answer = Read-Host "  Language / Язык  [ru/en] ($default)"
        if ($answer.Trim().ToLower() -in 'ru', 'en') { $Lang = $answer.Trim().ToLower() }
    }
}

$L = @{
    ru = @{
        title = '✦ Termistry';admin_note = 'запущено от администратора - лучше от обычного пользователя, права попрошу сам, где нужно'
        continue7 = 'продолжаю в PowerShell 7…'; no_winget = 'Нет winget. Установи «Установщик приложений» (App Installer) из Microsoft Store и запусти скрипт снова.'
        no_pwsh = 'PowerShell 7 не установился - поставь вручную: winget install Microsoft.PowerShell'
        present = 'уже есть'; installing = 'устанавливаю…'; installed = 'установлен'; winget_code = 'winget вернул {0}'
        s_apps = 'Программы'; skip_apps = 'нет winget - программы пропускаю (App Installer из Microsoft Store)'
        s_font = 'Шрифт JetBrainsMono Nerd Font'; font_present = 'уже установлен для всех пользователей'; font_downloaded = 'скачано: {0}'
        font_uac = 'нужны права администратора - подтверди запрос Windows (UAC)'; font_failed = 'не установились: {0}'; font_done = 'установлен для всех пользователей'
        font_error = 'шрифт не установлен: {0}'; font_notfont = 'скачался не шрифт: {0}'; font_fallback = 'Nerd Font нет - в терминале будет Cascadia Mono (иконки не покажутся)'
        s_psfzf = 'Модуль PSFzf'; psfzf_failed = 'не установился: {0}'
        s_profile = 'Профиль PowerShell и шаблоны'; unchanged = 'без изменений'; updated = 'обновлён'; old = 'старый'; created = 'создан'
        custom_yours = 'твой, не трогаю'; custom_created = 'создан (для своих настроек и команд)'; dir_created = 'создана'
        theme_set = 'тема: {0} · сменить: theme latte'; lang_set = 'язык: {0} · сменить: lang en'
        s_wt = 'Windows Terminal'; wt_badjson = 'не разобрал JSON, пропускаю: {0}'; wt_never = 'Windows Terminal ещё ни разу не запускался - открой его один раз и запусти скрипт снова'
        s_vscode = 'Терминал VS Code'; vscode_none = 'VS Code не найден - пропускаю'; vscode_font = 'шрифт терминала: {0}'
        s_git = 'git: диффы через delta'; git_none = 'git не найден - пропускаю'; delta_none = 'delta не найден - пропускаю'; git_changed = '~/.gitconfig - изменено настроек: {0}'; git_same = '~/.gitconfig - без изменений'
        s_check = 'Проверка профиля'; profile_ok = 'профиль загружается без ошибок'; profile_errors = 'ошибок при загрузке профиля: {0}'
        done_warn = 'Готово, предупреждений: {0} (см. выше, жёлтым).'; done = 'Готово.'
        next1 = 'Закрой все окна Windows Terminal и открой заново, затем набери: help  (или F1)'
        next2 = 'Своё: custom.ps1 и bin\ рядом с профилем (ep) · new имя.py - команда на любом языке · theme latte · lang en'
        next3 = 'Серверы: srv install <хост> -Env prod  - такой же удобный bash на Linux.'
        next4 = 'Скрипт можно запускать повторно - он доустановит недостающее и обновит конфиги.'
        s_uninstall = 'Удаление'; removed = 'удалён'; uninstall_kept = 'Остались: custom.ps1, bin\, server\custom\, список проектов Workspace, программы, шрифт, настройки Windows Terminal и *.bak'
    }
    en = @{
        title = '✦ Termistry';admin_note = 'running as administrator - better as a regular user; elevation is requested only where needed'
        continue7 = 'continuing in PowerShell 7…'; no_winget = 'No winget. Install "App Installer" from the Microsoft Store and run the script again.'
        no_pwsh = 'PowerShell 7 did not install - install it manually: winget install Microsoft.PowerShell'
        present = 'already installed'; installing = 'installing…'; installed = 'installed'; winget_code = 'winget returned {0}'
        s_apps = 'Programs'; skip_apps = 'no winget - skipping programs (App Installer from the Microsoft Store)'
        s_font = 'JetBrainsMono Nerd Font'; font_present = 'already installed for all users'; font_downloaded = 'downloaded: {0}'
        font_uac = 'administrator rights needed - confirm the Windows prompt (UAC)'; font_failed = 'not installed: {0}'; font_done = 'installed for all users'
        font_error = 'font not installed: {0}'; font_notfont = 'downloaded file is not a font: {0}'; font_fallback = 'no Nerd Font - the terminal will use Cascadia Mono (no icons)'
        s_psfzf = 'PSFzf module'; psfzf_failed = 'failed to install: {0}'
        s_profile = 'PowerShell profile and templates'; unchanged = 'unchanged'; updated = 'updated'; old = 'old'; created = 'created'
        custom_yours = 'yours, left alone'; custom_created = 'created (for your own settings and commands)'; dir_created = 'created'
        theme_set = 'theme: {0} · change: theme latte'; lang_set = 'language: {0} · change: lang ru'
        s_wt = 'Windows Terminal'; wt_badjson = 'could not parse JSON, skipping: {0}'; wt_never = 'Windows Terminal has never been started - open it once and run the script again'
        s_vscode = 'VS Code terminal'; vscode_none = 'VS Code not found - skipping'; vscode_font = 'terminal font: {0}'
        s_git = 'git: diffs via delta'; git_none = 'git not found - skipping'; delta_none = 'delta not found - skipping'; git_changed = '~/.gitconfig - settings changed: {0}'; git_same = '~/.gitconfig - unchanged'
        s_check = 'Profile check'; profile_ok = 'profile loads without errors'; profile_errors = 'errors while loading the profile: {0}'
        done_warn = 'Done, warnings: {0} (see above, in yellow).'; done = 'Done.'
        next1 = 'Close all Windows Terminal windows, open it again and type: help  (or F1)'
        next2 = 'Yours: custom.ps1 and bin\ next to the profile (ep) · new name.py - a command in any language · theme latte · lang ru'
        next3 = 'Servers: srv install <host> -Env prod  - the same bash on Linux.'
        next4 = 'Safe to run again - it installs what is missing and updates the configs.'
        s_uninstall = 'Uninstall'; removed = 'removed'; uninstall_kept = 'Kept: custom.ps1, bin\, server\custom\, the Workspace project list, programs, font, Windows Terminal settings and *.bak files'
    }
}[$Lang]

function Step([string]$Title) { Write-Host ''; Write-Host "▸ $Title" -ForegroundColor Magenta }
function Ok([string]$Text) { Write-Host "  ✓ $Text" -ForegroundColor Green }
function Info([string]$Text) { Write-Host "  · $Text" -ForegroundColor DarkGray }
function Warn([string]$Text) { Write-Host "  ! $Text" -ForegroundColor Yellow; $script:Warnings++ }
function Short([string]$Path) { $Path.Replace($HOME, '~') }
$Warnings = 0

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Pwsh {
    $candidates = @("$env:ProgramFiles\PowerShell\7\pwsh.exe")
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd) { $candidates += $cmd.Source }
    foreach ($p in $candidates) { if ($p -and (Test-Path $p)) { return $p } }
}

function Install-WingetPackage([string]$Id, [string]$Command, [string]$Title) {
    if (-not $Title) { $Title = $Id }
    if ($Command -and (Test-Command $Command)) { Ok "$Title - $($L.present)"; return }
    Info "$Title - $($L.installing)"
    $out = winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2>&1
    $code = $LASTEXITCODE
    Update-SessionPath
    # 0x8A15002B = already installed
    if ($code -eq 0 -or $code -eq -1978335189 -or ($Command -and (Test-Command $Command))) { Ok "$Title - $($L.installed)" }
    else { Warn "$Title - $($L.winget_code -f $code)"; $out | Select-Object -Last 5 | ForEach-Object { Info "$_" } }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ''
    Write-Host "  $($L.title) $SetupVersion" -ForegroundColor Magenta
    Step 'PowerShell 7'
    $pwsh = Get-Pwsh
    if (-not $pwsh) {
        if (-not (Test-Command winget)) { throw $L.no_winget }
        Install-WingetPackage 'Microsoft.PowerShell' '' 'PowerShell 7'
        $pwsh = Get-Pwsh
        if (-not $pwsh) { throw $L.no_pwsh }
    } else {
        Ok "PowerShell 7 - $($L.present)"
    }
    Info $L.continue7
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Lang', $Lang)
    if ($StartingDirectory) { $argList += @('-StartingDirectory', $StartingDirectory) }
    if ($SshTabs) { $argList += @('-SshTabs', ($SshTabs -join ',')) }
    if ($Theme) { $argList += @('-Theme', $Theme) }
    if ($ProfileDir) { $argList += @('-ProfileDir', $ProfileDir) }
    if ($SkipApps) { $argList += '-SkipApps' }
    if ($Uninstall) { $argList += '-Uninstall' }
    & $pwsh @argList
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host "  $($L.title) $SetupVersion" -ForegroundColor Magenta
Info "PowerShell $($PSVersionTable.PSVersion) · $([Environment]::OSVersion.VersionString)"
if (Test-Admin) { Info $L.admin_note }

if (-not $ProfileDir) { $ProfileDir = Split-Path $PROFILE }
$ProfileFile = Join-Path $ProfileDir 'Microsoft.PowerShell_profile.ps1'

#@@EMBEDDED_FILES@@

if ($Uninstall) {
    Step $L.s_uninstall
    $managed = @($EmbeddedFiles.Keys | Where-Object { $_ -ne 'custom.ps1' } | ForEach-Object { Join-Path $ProfileDir $_ })
    # the Workspace project list is the user's own, like custom.ps1
    $managed += @(Get-ChildItem $ConfigDir -Force -ErrorAction Ignore | Where-Object Name -notlike 'projects*.tsv' | ForEach-Object FullName)
    $managed += (Join-Path $HOME '.cache\termistry'), (Join-Path $HOME '.cache\pwsh-completions'), (Join-Path $HOME '.cache\pwsh-predictor')
    $managed += $LegacyDirs
    foreach ($p in $managed) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Ok "$(Short $p) - $($L.removed)" }
    }
    if ((Test-Path $ConfigDir) -and -not (Get-ChildItem $ConfigDir -Force)) { Remove-Item $ConfigDir }
    Write-Host ''
    Write-Host "  $($L.uninstall_kept)" -ForegroundColor Gray
    Write-Host ''
    exit 0
}
$ThemeFile = Join-Path $ConfigDir 'theme'
$LangFile = Join-Path $ConfigDir 'lang'
$FontFace = 'JetBrainsMono NF'
$FontStyles = [ordered]@{ Regular = 'Regular'; Bold = 'Bold'; Italic = 'Italic'; BoldItalic = 'Bold Italic' }
$FontBaseUrl = 'https://github.com/ryanoasis/nerd-fonts/raw/v3.4.0/patched-fonts/JetBrainsMono/Ligatures'

if (-not $SkipApps) {
    Step $L.s_apps
    if (-not (Test-Command winget)) {
        Warn $L.skip_apps
    } else {
        Install-WingetPackage 'Microsoft.WindowsTerminal' 'wt' 'Windows Terminal'
        $apps = @(
            @('Git.Git', 'git', 'git'),
            @('junegunn.fzf', 'fzf', 'fzf'),
            @('ajeetdsouza.zoxide', 'zoxide', 'zoxide'),
            @('eza-community.eza', 'eza', 'eza'),
            @('sharkdp.bat', 'bat', 'bat'),
            @('BurntSushi.ripgrep.MSVC', 'rg', 'ripgrep'),
            @('sharkdp.fd', 'fd', 'fd'),
            @('dandavison.delta', 'delta', 'delta'),
            @('JesseDuffield.lazygit', 'lazygit', 'lazygit'),
            @('tldr-pages.tlrc', 'tldr', 'tldr'),
            @('GitHub.cli', 'gh', 'gh')
        )
        foreach ($a in $apps) { Install-WingetPackage $a[0] $a[1] $a[2] }
    }

    Step $L.s_font
    $missing = @($FontStyles.Keys | Where-Object { -not (Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-$_.ttf") })
    if (-not $missing) {
        Ok $L.font_present
    } else {
        $fontTmp = Join-Path ([IO.Path]::GetTempPath()) "nerd-font-$Stamp"
        New-Item -ItemType Directory -Force $fontTmp | Out-Null
        try {
            foreach ($style in $missing) {
                $file = Join-Path $fontTmp "JetBrainsMonoNerdFont-$style.ttf"
                Invoke-WebRequest "$FontBaseUrl/$style/JetBrainsMonoNerdFont-$style.ttf" -OutFile $file -UseBasicParsing
                $head = [IO.File]::ReadAllBytes($file)[0..3] -join ','
                if ((Get-Item $file).Length -lt 500KB -or $head -ne '0,1,0,0') { throw ($L.font_notfont -f $style) }
            }
            Info ($L.font_downloaded -f ($missing -join ', '))
            # per-user fonts are invisible to the packaged Windows Terminal, so install machine-wide
            $installer = Join-Path $fontTmp 'install-font.ps1'
            $styleMap = ($FontStyles.GetEnumerator() | ForEach-Object { "'$($_.Key)'='$($_.Value)'" }) -join ';'
            @"
`$ErrorActionPreference = 'Stop'
`$styles = @{ $styleMap }
foreach (`$f in Get-ChildItem '$fontTmp' -Filter *.ttf) {
    `$style = `$f.BaseName -replace '^JetBrainsMonoNerdFont-', ''
    Copy-Item `$f.FullName "`$env:windir\Fonts\`$(`$f.Name)" -Force
    New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name "JetBrainsMono Nerd Font `$(`$styles[`$style]) (TrueType)" -Value `$f.Name -PropertyType String -Force | Out-Null
}
"@ | Set-Content $installer -Encoding utf8
            if (Test-Admin) {
                & $installer
            } else {
                Info $L.font_uac
                Start-Process (Get-Pwsh) -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installer`""
            }
            $still = @($FontStyles.Keys | Where-Object { -not (Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-$_.ttf") })
            if ($still) { Warn ($L.font_failed -f ($still -join ', ')) } else { Ok $L.font_done }
        } catch {
            Warn ($L.font_error -f $_.Exception.Message)
        } finally {
            Remove-Item $fontTmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Step $L.s_psfzf
    if (Get-Module -ListAvailable PSFzf) { Ok $L.present }
    else {
        try { Install-Module PSFzf -Scope CurrentUser -Force -AllowClobber; Ok $L.installed }
        catch { Warn ($L.psfzf_failed -f $_.Exception.Message) }
    }
}
$FontInstalled = Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-Regular.ttf"
if (-not $FontInstalled) { $FontFace = 'Cascadia Mono'; Warn $L.font_fallback }

function Write-ManagedFile([string]$Path, [string]$Content) {
    $Content = ($Content -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    if (Test-Path $Path) {
        $old = [IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
        if ($old -eq $Content) { Ok "$(Short $Path) - $($L.unchanged)"; return }
        Copy-Item $Path "$Path.bak-$Stamp" -Force
        [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
        Ok "$(Short $Path) - $($L.updated) $([char]0x00B7) $($L.old): $(Split-Path $Path -Leaf).bak-$Stamp"
    } else {
        [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
        Ok "$(Short $Path) - $($L.created)"
    }
}

Step $L.s_profile
. ([scriptblock]::Create($EmbeddedFiles['palette.ps1']))
if ($Theme -and -not $Themes.Contains($Theme.ToLower())) { throw "-Theme: $($Themes.Keys -join ', ')" }
if ($Theme) { New-Item -ItemType Directory -Force $ConfigDir | Out-Null; [IO.File]::WriteAllText($ThemeFile, "$($Theme.ToLower())`n") }
$ThemeName = Get-ThemeName
$ThemeTitle = $Themes[$ThemeName].title

foreach ($rel in $EmbeddedFiles.Keys) {
    if ($rel -ne 'custom.ps1') { Write-ManagedFile (Join-Path $ProfileDir $rel) $EmbeddedFiles[$rel] }
}
Remove-Item $LegacyDirs[1] -Recurse -Force -ErrorAction SilentlyContinue

$customFile = Join-Path $ProfileDir 'custom.ps1'
if (Test-Path $customFile) { Ok "$(Short $customFile) - $($L.custom_yours)" }
else { [IO.File]::WriteAllText($customFile, ($EmbeddedFiles['custom.ps1'] -replace "`r`n", "`n"), $Utf8NoBom); Ok "$(Short $customFile) - $($L.custom_created)" }
foreach ($d in 'bin', 'server\custom') {
    $p = Join-Path $ProfileDir $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force $p | Out-Null; Ok "$(Short $p)\ - $($L.dir_created)" }
}

New-Item -ItemType Directory -Force $ConfigDir | Out-Null
[IO.File]::WriteAllText($LangFile, "$Lang`n")
Ok ($L.lang_set -f $Lang)
Ok ($L.theme_set -f $ThemeName)

function Get-StableGuid([string]$Text) {
    $md5 = [Security.Cryptography.MD5]::Create()
    '{' + [guid]::new($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).ToString() + '}'
}

function Update-TerminalSettings([string]$Path) {
    $raw = if (Test-Path $Path) { [IO.File]::ReadAllText($Path) } else { '' }
    try { $s = if ($raw.Trim()) { $raw | ConvertFrom-Json -AsHashtable } else { [ordered]@{} } }
    catch { Warn "$(Short $Path) - $($L.wt_badjson -f $_.Exception.Message)"; return }
    $before = if ($raw.Trim()) { $s | ConvertTo-Json -Depth 32 } else { '' }

    if (-not $s.Contains('profiles')) { $s['profiles'] = [ordered]@{} }
    if ($s.profiles -is [array]) { $s['profiles'] = [ordered]@{ defaults = [ordered]@{}; list = $s.profiles } }
    if (-not $s.profiles.Contains('defaults') -or -not $s.profiles.defaults) { $s.profiles['defaults'] = [ordered]@{} }
    if (-not $s.profiles.Contains('list')) { $s.profiles['list'] = @() }
    $list = [Collections.Generic.List[object]]::new()
    foreach ($p in $s.profiles.list) { $list.Add($p) }

    $d = $s.profiles.defaults
    $d['colorScheme'] = $ThemeTitle
    if (-not $d.Contains('font') -or -not ($d.font -is [Collections.IDictionary])) { $d['font'] = [ordered]@{} }
    $d.font['face'] = $FontFace
    $d.font['size'] = 11
    $d.font['cellHeight'] = '1.2'
    $d['padding'] = '14, 10'
    $d['cursorShape'] = 'bar'
    $d['antialiasingMode'] = 'cleartype'
    $d['intenseTextStyle'] = 'bright'
    $d['scrollbarState'] = 'hidden'
    $d['historySize'] = 20000
    $d['bellStyle'] = 'none'

    $pwshGuid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
    $pw = $list | Where-Object { $_.guid -eq $pwshGuid } | Select-Object -First 1
    if (-not $pw) {
        $pw = [ordered]@{ guid = $pwshGuid; name = 'PowerShell 7'; source = 'Windows.Terminal.PowershellCore'; hidden = $false }
        $list.Insert(0, $pw)
    }
    $pw['name'] = 'PowerShell 7'
    $pw['hidden'] = $false
    if ($StartingDirectory) { $pw['startingDirectory'] = $StartingDirectory }
    $s['defaultProfile'] = $pwshGuid

    foreach ($p in $list) { if ($p.source -eq 'Windows.Terminal.Azure') { $p['hidden'] = $true } }

    foreach ($h in $SshTabs) {
        $tab = $list | Where-Object { $_.commandline -eq "ssh $h" } | Select-Object -First 1
        if (-not $tab) { $tab = [ordered]@{ guid = (Get-StableGuid "ssh:$h") }; $list.Add($tab) }
        $tab['name'] = "$h (ssh)"
        $tab['commandline'] = "ssh $h"
        $tab['icon'] = ([string][char]0xF233)
        $tab['tabColor'] = '#FAB387'
        $tab['hidden'] = $false
    }
    $s.profiles['list'] = $list.ToArray()

    $ours = @($Themes.Values.title)
    $s['schemes'] = @(@($s.schemes | Where-Object { $_ -and $_.name -notin $ours -and $_.name -notlike 'Catppuccin *' }) + @($Themes.Keys | ForEach-Object { Get-TerminalScheme $_ }))
    $s['themes'] = @(@($s.themes | Where-Object { $_ -and $_.name -notin $ours -and $_.name -notlike 'Catppuccin *' }) + @($Themes.Keys | ForEach-Object { Get-TerminalTheme $_ }))
    $s['theme'] = $ThemeTitle

    if (-not $s.Contains('actions')) { $s['actions'] = @() }
    if (-not $s.Contains('keybindings')) { $s['keybindings'] = @() }
    if (-not ($s.actions | Where-Object { $_.id -eq 'User.quakeMode' })) {
        $s['actions'] = @($s.actions) + [ordered]@{ command = 'quakeMode'; id = 'User.quakeMode' }
    }
    if (-not ($s.keybindings | Where-Object { $_.id -eq 'User.quakeMode' -or $_.keys -eq 'win+`' })) {
        $s['keybindings'] = @($s.keybindings) + [ordered]@{ id = 'User.quakeMode'; keys = 'win+`' }
    }

    $after = $s | ConvertTo-Json -Depth 32
    if ($after -eq $before) { Ok "$(Short $Path) - $($L.unchanged)"; return }
    if (Test-Path $Path) { Copy-Item $Path "$Path.bak-$Stamp" -Force }
    else { New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null }
    [IO.File]::WriteAllText($Path, $after, $Utf8NoBom)
    Ok "$(Short $Path) - $($L.updated)$(if ($raw.Trim()) { " $([char]0x00B7) $($L.old): settings.json.bak-$Stamp" })"
}

Step $L.s_wt
$wtFound = $false
foreach ($pkg in 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') {
    $pkgDir = Join-Path $env:LOCALAPPDATA "Packages\$pkg"
    if (Test-Path $pkgDir) { $wtFound = $true; Update-TerminalSettings (Join-Path $pkgDir 'LocalState\settings.json') }
}
$portable = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
if (Test-Path $portable) { $wtFound = $true; Update-TerminalSettings $portable }
if (-not $wtFound) { Warn $L.wt_never }

Step $L.s_vscode
$vsSettings = Join-Path $env:APPDATA 'Code\User\settings.json'
if (-not (Test-Path (Split-Path $vsSettings)) -and -not (Test-Command code)) {
    Info $L.vscode_none
} else {
    $line = "`"terminal.integrated.fontFamily`": `"$FontFace`""
    $raw = if (Test-Path $vsSettings) { [IO.File]::ReadAllText($vsSettings) } else { '{}' }
    $new = if ($raw -match '"terminal\.integrated\.fontFamily"\s*:\s*"[^"]*"') {
        $raw -replace '"terminal\.integrated\.fontFamily"\s*:\s*"[^"]*"', $line
    } elseif ($raw.Trim() -match '^\{\s*\}$') {
        "{`n  $line`n}`n"
    } else {
        ([regex]'\{').Replace($raw, "{`n  $line,", 1)
    }
    if ($new -eq $raw) { Ok "$(Short $vsSettings) - $($L.unchanged)" }
    else {
        if (Test-Path $vsSettings) { Copy-Item $vsSettings "$vsSettings.bak-$Stamp" -Force }
        else { New-Item -ItemType Directory -Force (Split-Path $vsSettings) | Out-Null }
        [IO.File]::WriteAllText($vsSettings, $new, $Utf8NoBom)
        Ok "$(Short $vsSettings) - $($L.vscode_font -f $FontFace)"
    }
}

Step $L.s_git
if (-not (Test-Command git)) { Warn $L.git_none }
elseif (-not (Test-Command delta)) { Warn $L.delta_none }
else {
    # ANSI colors only, so diffs follow the terminal theme (light or dark)
    $gitSettings = [ordered]@{
        'core.pager'                         = 'delta'
        'interactive.diffFilter'             = 'delta --color-only'
        'merge.conflictstyle'                = 'zdiff3'
        'delta.navigate'                     = 'true'
        'delta.line-numbers'                 = 'true'
        'delta.syntax-theme'                 = 'ansi'
        'delta.file-style'                   = 'magenta bold'
        'delta.file-decoration-style'        = 'brightblack ul'
        'delta.hunk-header-style'            = 'file line-number syntax'
        'delta.hunk-header-decoration-style' = 'brightblack box'
        'delta.line-numbers-minus-style'     = 'red'
        'delta.line-numbers-plus-style'      = 'green'
        'delta.line-numbers-zero-style'      = 'brightblack'
    }
    $changed = 0
    foreach ($k in $gitSettings.Keys) {
        $current = git config --global --get $k 2>$null
        if ($current -ne $gitSettings[$k]) { git config --global $k $gitSettings[$k]; $changed++ }
    }
    if ($changed) { Ok ($L.git_changed -f $changed) } else { Ok $L.git_same }
}

Step $L.s_check
$check = & (Get-Pwsh) -NoLogo -NoProfile -Command "`$Error.Clear(); . '$ProfileFile' *> `$null; `$Error.Count; foreach (`$e in `$Error) { `$e.ToString() }" 2>&1
$errCount = [int]($check | Select-Object -First 1)
if ($errCount -eq 0) { Ok $L.profile_ok }
else { Warn ($L.profile_errors -f $errCount); $check | Select-Object -Skip 1 -First 5 | ForEach-Object { Info "$_" } }

Write-Host ''
if ($Warnings) { Write-Host "  $($L.done_warn -f $Warnings)" -ForegroundColor Yellow }
else { Write-Host "  $($L.done)" -ForegroundColor Green }
Write-Host "  $($L.next1)" -ForegroundColor Gray
Write-Host "  $($L.next2)" -ForegroundColor DarkGray
Write-Host "  $($L.next3)" -ForegroundColor DarkGray
Write-Host "  $($L.next4)" -ForegroundColor DarkGray
Write-Host ''
