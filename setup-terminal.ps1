<#
.SYNOPSIS
  A good-looking, convenient terminal on Windows 11 in one command. Safe to run again.
  Repository: https://github.com/Ange1oc/terminal-setup

.EXAMPLE
  irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1 | iex
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
#>
param(
    [ValidateSet('', 'ru', 'en')][string]$Lang = '',
    [string]$Theme = '',
    [string]$StartingDirectory,
    [string[]]$SshTabs = @(),
    [switch]$SkipApps,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$SetupVersion = '2.3.0'
$ProgressPreference = 'SilentlyContinue'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$SshTabs = @($SshTabs | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$ConfigDir = Join-Path $HOME '.config\terminal-setup'

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
        title = '✦ Настройка терминала'; admin_note = 'запущено от администратора - лучше от обычного пользователя, права попрошу сам, где нужно'
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
        s_uninstall = 'Удаление'; removed = 'удалён'; uninstall_kept = 'Остались: custom.ps1, bin\, server\custom\, программы, шрифт, настройки Windows Terminal и *.bak'
    }
    en = @{
        title = '✦ Terminal setup'; admin_note = 'running as administrator - better as a regular user; elevation is requested only where needed'
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
        s_uninstall = 'Uninstall'; removed = 'removed'; uninstall_kept = 'Kept: custom.ps1, bin\, server\custom\, programs, font, Windows Terminal settings and *.bak files'
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
    if ($SkipApps) { $argList += '-SkipApps' }
    & $pwsh @argList
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host "  $($L.title) $SetupVersion" -ForegroundColor Magenta
Info "PowerShell $($PSVersionTable.PSVersion) · $([Environment]::OSVersion.VersionString)"
if (Test-Admin) { Info $L.admin_note }

$ProfileDir = Split-Path $PROFILE

if ($Uninstall) {
    Step $L.s_uninstall
    $managed = @('Microsoft.PowerShell_profile.ps1', 'palette.ps1', 'lang.ps1', 'toolkit.ps1', 'DeepHistoryPredictor.cs', 'server\bashrc.local', 'server\inputrc', 'server\install.sh' | ForEach-Object { Join-Path $ProfileDir $_ })
    $managed += (Join-Path $HOME '.config\ohmyposh\soft.omp.json'), (Join-Path $HOME '.config\terminal-setup'), (Join-Path $HOME '.cache\pwsh-completions'), (Join-Path $HOME '.cache\pwsh-predictor')
    foreach ($p in $managed) {
        if (Test-Path $p) { Remove-Item $p -Recurse -Force; Ok "$(Short $p) - $($L.removed)" }
    }
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

# ── Встроенные файлы (собраны build.ps1 из src/) ────────────────────────────
$EmbeddedFiles = [ordered]@{}
$EmbeddedFiles['profile'] = @'
$global:TerminalSetupVersion = '2.3.0'
$global:TerminalSetupLoaded = $false
$global:ProfileDir = Split-Path $PROFILE
$env:XDG_CONFIG_HOME = "$HOME\.config"
$global:isInteractive = -not [Console]::IsOutputRedirected -and $Host.Name -eq 'ConsoleHost'
$cacheDir = "$HOME\.cache\terminal-setup"

$global:TerminalSetup = @{
    Abbreviations = $true
    LayoutFix     = $true
    Predictions   = 50
}

. (Join-Path $ProfileDir 'palette.ps1')
$global:ThemeName = Get-ThemeName
$global:Palette = $Themes[$ThemeName]
$env:TERMINAL_THEME = $ThemeName
$langFile = Join-Path $HOME '.config\terminal-setup\lang'
$global:LangName = if ((Test-Path $langFile) -and (Get-Content $langFile -First 1).Trim() -eq 'en') { 'en' } elseif ((Test-Path $langFile) -or (Get-Culture).TwoLetterISOLanguageName -eq 'ru') { 'ru' } else { 'en' }

. (Join-Path $ProfileDir 'toolkit.ps1')
if (-not $isInteractive) { Set-TerminalPalette }

# The rest (strings, commands, completions, zoxide) loads after the first prompt is drawn.
# Those files declare everything as global: because they are dot-sourced from inside this function.
function global:Complete-TerminalSetup {
    if ($global:TerminalSetupLoaded) { return }
    $global:TerminalSetupLoaded = $true
    . (Join-Path $global:ProfileDir 'lang.ps1')
    $global:TkStr = $global:Strings[$global:LangName]
    . (Join-Path $global:ProfileDir 'toolkit-lazy.ps1')
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        $zoxideInit = "$HOME\.cache\terminal-setup\zoxide-init.ps1"
        $zoxideExe = (Get-Command zoxide).Source
        if (-not (Test-Path $zoxideInit) -or (Get-Item $zoxideInit).LastWriteTime -lt (Get-Item $zoxideExe).LastWriteTime) {
            New-Item -ItemType Directory -Force (Split-Path $zoxideInit) | Out-Null
            zoxide init powershell | Set-Content $zoxideInit -Encoding utf8
        }
        try { . $zoxideInit } catch { Write-Warning "zoxide: $_" }
    }
    $completions = "$HOME\.cache\pwsh-completions"
    $files = @(Get-ChildItem $completions -Filter *.ps1 -ErrorAction SilentlyContinue)
    if (-not (Test-Path $completions) -or ($files | Where-Object { (Get-Content $_.FullName -First 1) -ne '# global' })) {
        Update-Completions | Out-Null
        $files = @(Get-ChildItem $completions -Filter *.ps1 -ErrorAction SilentlyContinue)
    }
    foreach ($file in $files) {
        try { . $file.FullName } catch { Write-Warning "$($file.Name): $_" }
    }
    $null = Get-TsPreview
}
# Until then these names forward to the real functions on first use
foreach ($n in 'help', 'my', 'h', 'jump', 'srv', 'theme', 'lang', 'new', 'nav', 'pv', 'rgi', 'pk', 'gbr', 'o', 'doctor', 'update', 'ex', 'bak', 'psg', 'cb', 'ep', 'Invoke-HelpPicker', 'Update-Completions', 'Get-TsPreview') {
    Set-Item "Function:global:$n" -Value ([scriptblock]::Create("Complete-TerminalSetup; & '$n' @args"))
}

$before = @(Get-ChildItem Function: | Select-Object -ExpandProperty Name)
$customFile = Join-Path $ProfileDir 'custom.ps1'
if (Test-Path $customFile) {
    try { . $customFile } catch { Write-Warning "custom.ps1: $_" }
}
$global:CustomFunctions = @(Get-ChildItem Function: | Where-Object { $_.Name -notin $before -and $_.Name -notmatch ':' } | Select-Object -ExpandProperty Name)
Remove-Variable before, customFile
Register-BinCommands (Join-Path $ProfileDir 'bin')

if ($isInteractive) {
    try {
        Set-PSReadLineOption -EditMode Emacs `
            -HistoryNoDuplicates `
            -HistorySearchCursorMovesToEnd `
            -MaximumHistoryCount 20000 `
            -BellStyle None `
            -PredictionSource History `
            -PredictionViewStyle ListView
    } catch { Write-Warning "PSReadLine: $_" }
    Set-TerminalPalette

    Set-PSReadLineKeyHandler -Key Tab             -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+c          -Function CancelLine
    Set-PSReadLineKeyHandler -Key UpArrow         -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow       -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key F2              -Function SwitchPredictionView
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace  -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+Delete     -Function KillWord
    Set-PSReadLineKeyHandler -Key Ctrl+z          -Function Undo
    Set-PSReadLineKeyHandler -Key Ctrl+y          -Function Redo
    Set-PSReadLineKeyHandler -Key Shift+Enter     -Function AddLine
    Set-PSReadLineKeyHandler -Key F1 -BriefDescription 'CheatSheet' -ScriptBlock { Complete-TerminalSetup; Invoke-HelpPicker }

    if ($TerminalSetup.Abbreviations) {
        Set-PSReadLineKeyHandler -Key Spacebar -BriefDescription 'ExpandAbbreviation' -ScriptBlock {
            $line = $null; $cursor = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
            $exp = Expand-Abbreviation $line $cursor
            if ($exp) {
                [Microsoft.PowerShell.PSConsoleReadLine]::Replace($exp.Start, $exp.Length, $exp.Text)
                if ($exp.Cursor -ge 0) { [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($exp.Cursor); return }
            }
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert(' ')
        }
    }

    # History predictor plugin: PSReadLine caps built-in history suggestions at 10, plugins get 50.
    # The DLL is cached by source hash because a loaded DLL stays locked by open sessions.
    $predictorSrc = Join-Path $ProfileDir 'DeepHistoryPredictor.cs'
    if ($TerminalSetup.Predictions -gt 0 -and (Test-Path $predictorSrc)) {
        try {
            if (-not ('DeepHistoryPredictor' -as [type])) {
                $predictorHash = (Get-FileHash $predictorSrc -Algorithm SHA256).Hash.Substring(0, 12)
                $predictorDll = "$HOME\.cache\pwsh-predictor\DeepHistoryPredictor-$predictorHash.dll"
                if (-not (Test-Path $predictorDll)) {
                    New-Item -ItemType Directory -Force (Split-Path $predictorDll) | Out-Null
                    Add-Type -Path $predictorSrc -OutputAssembly $predictorDll -OutputType Library
                }
                Add-Type -Path $predictorDll
            }
            $predictorKind = [System.Management.Automation.Subsystem.SubsystemKind]::CommandPredictor
            if (-not ((Get-PSSubsystem -Kind CommandPredictor).Implementations | Where-Object Id -eq ([DeepHistoryPredictor]::PredictorId))) {
                [System.Management.Automation.Subsystem.SubsystemManager]::RegisterSubsystem(
                    $predictorKind, [DeepHistoryPredictor]::new((Get-PSReadLineOption).HistorySavePath, [Math]::Min(50, $TerminalSetup.Predictions)))
            }
            Set-PSReadLineOption -PredictionSource Plugin
        } catch {
            Write-Warning "DeepHistoryPredictor: $_"
        }
    }
}

# Prompt: oh-my-posh renders it, but its own `init` script costs ~0.4 s to evaluate on every start.
# This is the same call it makes, without the module around it. Transient prompt: see the Enter handler.
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $global:TsOmp = (Get-Command oh-my-posh).Source
    $global:TsOmpConfig = "$HOME\.config\ohmyposh\soft.omp.json"
    $env:POSH_THEME = $TsOmpConfig
    $env:POSH_SHELL = 'pwsh'
    $global:TsTransient = $false
    $global:TsLastHistoryId = 0
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    function global:prompt {
        $ok = $?
        $code = if ($ok) { 0 } elseif ($global:LASTEXITCODE) { $global:LASTEXITCODE } else { 1 }
        $ms = 0
        $last = Get-History -Count 1
        if ($last -and $last.Id -ne $global:TsLastHistoryId) {
            $global:TsLastHistoryId = $last.Id
            $ms = [int]($last.EndExecutionTime - $last.StartExecutionTime).TotalMilliseconds
        }
        $width = $Host.UI.RawUI.WindowSize.Width
        $kind = if ($global:TsTransient) { $global:TsTransient = $false; 'transient' } else { 'primary' }
        $out = & $global:TsOmp print $kind --shell pwsh --config $global:TsOmpConfig --pwd $PWD.ProviderPath --terminal-width $width --status $code --execution-time $ms
        $out -join "`n"
    }
}

# Enter: layout fix + abbreviation, redraw the prompt in its transient form, then run
if ($isInteractive -and ($TerminalSetup.LayoutFix -or $TerminalSetup.Abbreviations -or $global:TsOmp)) {
    Set-PSReadLineKeyHandler -Key Enter -BriefDescription 'TerminalSetupEnter' -ScriptBlock {
        $line = $null; $cursor = $null; $errors = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($TerminalSetup.LayoutFix -and $line) {
            $fixed = Repair-CommandLayout $line
            if ($fixed) { [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $fixed); $line = $fixed; $cursor = $fixed.Length }
        }
        if ($TerminalSetup.Abbreviations) {
            $exp = Expand-Abbreviation $line $cursor
            if ($exp) { [Microsoft.PowerShell.PSConsoleReadLine]::Replace($exp.Start, $exp.Length, $exp.Text) }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$null, [ref]$null, [ref]$errors, [ref]$null)
        if ($global:TsOmp -and $errors.Count -eq 0) {
            $global:TsTransient = $true
            try { [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() } catch { $global:TsTransient = $false }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
$env:FZF_CTRL_R_OPTS = '--height=14'
$env:FZF_CTRL_T_OPTS = "--height=70% --preview=`"$cacheDir\preview.cmd {}`" --preview-window=right:55%"
if ($isInteractive -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
    # PSFzf auto-loads on first use; importing it eagerly costs ~0.3 s at startup
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Invoke-FzfPsReadlineHandlerHistory }
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Invoke-FzfPsReadlineHandlerProvider }
    Set-PSReadLineKeyHandler -Key Alt+c -BriefDescription 'FolderNavigator' -ScriptBlock { Complete-TerminalSetup; nav; [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt() }
}

$env:BAT_THEME = 'ansi'
$env:BAT_STYLE = 'numbers,changes,header-filename'

$ezaArgs = '--icons=auto', '--group-directories-first', '--color=always'
function l   { eza @ezaArgs @args }
function ll  { eza @ezaArgs -la --git --time-style=relative --no-user @args }
function lt  { eza @ezaArgs --tree --level=2 --git-ignore @args }
function ..   { Set-Location .. }
function ...  { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function mkcd($path) { New-Item -ItemType Directory -Force $path | Out-Null; Set-Location $path }
function which($name) { Get-Command $name -All | Select-Object CommandType, Name, Source }
function touch($path) { if (Test-Path $path) { (Get-Item $path).LastWriteTime = Get-Date } else { New-Item -ItemType File $path | Out-Null } }
function lg  { git log --graph --pretty='%C(magenta)%h%Creset %C(green)%ar%Creset %C(blue)%an%Creset %s%C(yellow)%d%Creset' -n 30 @args }
function gst { git status -sb @args }
function reload { . $PROFILE }

if ($isInteractive) {
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -SupportEvent -Action { Complete-TerminalSetup }
} else {
    Complete-TerminalSetup
}
'@
$EmbeddedFiles['palette'] = @'
# Every theme uses the same 26 Catppuccin-style slots, so one table drives Windows Terminal,
# the oh-my-posh prompt, PSReadLine colors and fzf. Add a theme here and it works everywhere.
$Themes = [ordered]@{
    mocha = @{
        title = 'Catppuccin Mocha'; dark = $true
        rosewater = 0xF5E0DC; flamingo = 0xF2CDCD; pink = 0xF5C2E7; mauve = 0xCBA6F7; red = 0xF38BA8; maroon = 0xEBA0AC
        peach = 0xFAB387; yellow = 0xF9E2AF; green = 0xA6E3A1; teal = 0x94E2D5; sky = 0x89DCEB; sapphire = 0x74C7EC
        blue = 0x89B4FA; lavender = 0xB4BEFE; text = 0xCDD6F4; subtext1 = 0xBAC2DE; subtext0 = 0xA6ADC8
        overlay2 = 0x9399B2; overlay1 = 0x7F849C; overlay0 = 0x6C7086; surface2 = 0x585B70; surface1 = 0x45475A
        surface0 = 0x313244; base = 0x1E1E2E; mantle = 0x181825; crust = 0x11111B
    }
    macchiato = @{
        title = 'Catppuccin Macchiato'; dark = $true
        rosewater = 0xF4DBD6; flamingo = 0xF0C6C6; pink = 0xF5BDE6; mauve = 0xC6A0F6; red = 0xED8796; maroon = 0xEE99A0
        peach = 0xF5A97F; yellow = 0xEED49F; green = 0xA6DA95; teal = 0x8BD5CA; sky = 0x91D7E3; sapphire = 0x7DC4E4
        blue = 0x8AADF4; lavender = 0xB7BDF8; text = 0xCAD3F5; subtext1 = 0xB8C0E0; subtext0 = 0xA5ADCB
        overlay2 = 0x939AB7; overlay1 = 0x8087A2; overlay0 = 0x6E738D; surface2 = 0x5B6078; surface1 = 0x494D64
        surface0 = 0x363A4F; base = 0x24273A; mantle = 0x1E2030; crust = 0x181926
    }
    frappe = @{
        title = 'Catppuccin Frappe'; dark = $true
        rosewater = 0xF2D5CF; flamingo = 0xEEBEBE; pink = 0xF4B8E4; mauve = 0xCA9EE6; red = 0xE78284; maroon = 0xEA999C
        peach = 0xEF9F76; yellow = 0xE5C890; green = 0xA6D189; teal = 0x81C8BE; sky = 0x99D1DB; sapphire = 0x85C1DC
        blue = 0x8CAAEE; lavender = 0xBABBF1; text = 0xC6D0F5; subtext1 = 0xB5BFE2; subtext0 = 0xA5ADCE
        overlay2 = 0x949CBB; overlay1 = 0x838BA7; overlay0 = 0x737994; surface2 = 0x626880; surface1 = 0x51576D
        surface0 = 0x414559; base = 0x303446; mantle = 0x292C3C; crust = 0x232634
    }
    latte = @{
        title = 'Catppuccin Latte'; dark = $false
        rosewater = 0xDC8A78; flamingo = 0xDD7878; pink = 0xEA76CB; mauve = 0x8839EF; red = 0xD20F39; maroon = 0xE64553
        peach = 0xFE640B; yellow = 0xDF8E1D; green = 0x40A02B; teal = 0x179299; sky = 0x04A5E5; sapphire = 0x209FB5
        blue = 0x1E66F5; lavender = 0x7287FD; text = 0x4C4F69; subtext1 = 0x5C5F77; subtext0 = 0x6C6F85
        overlay2 = 0x7C7F93; overlay1 = 0x8C8FA1; overlay0 = 0x9CA0B0; surface2 = 0xACB0BE; surface1 = 0xBCC0CC
        surface0 = 0xCCD0DA; base = 0xEFF1F5; mantle = 0xE6E9EF; crust = 0xDCE0E8
    }
    black = @{
        title = 'Black'; dark = $true
        rosewater = 0xF5E0DC; flamingo = 0xF2CDCD; pink = 0xF5C2E7; mauve = 0xCBA6F7; red = 0xF38BA8; maroon = 0xEBA0AC
        peach = 0xFAB387; yellow = 0xF9E2AF; green = 0xA6E3A1; teal = 0x94E2D5; sky = 0x89DCEB; sapphire = 0x74C7EC
        blue = 0x89B4FA; lavender = 0xB4BEFE; text = 0xE4E4E4; subtext1 = 0xC8C8C8; subtext0 = 0xAAAAAA
        overlay2 = 0x8A8A8A; overlay1 = 0x707070; overlay0 = 0x585858; surface2 = 0x3C3C3C; surface1 = 0x2A2A2A
        surface0 = 0x1A1A1A; base = 0x000000; mantle = 0x000000; crust = 0x000000
    }
    gruvbox = @{
        title = 'Gruvbox Dark'; dark = $true
        rosewater = 0xEBDBB2; flamingo = 0xFE8019; pink = 0xD3869B; mauve = 0xD3869B; red = 0xFB4934; maroon = 0xCC241D
        peach = 0xFE8019; yellow = 0xFABD2F; green = 0xB8BB26; teal = 0x8EC07C; sky = 0x7DAEA3; sapphire = 0x458588
        blue = 0x83A598; lavender = 0xD3869B; text = 0xEBDBB2; subtext1 = 0xD5C4A1; subtext0 = 0xBDAE93
        overlay2 = 0xA89984; overlay1 = 0x928374; overlay0 = 0x7C6F64; surface2 = 0x665C54; surface1 = 0x504945
        surface0 = 0x3C3836; base = 0x282828; mantle = 0x1D2021; crust = 0x161616
    }
    dracula = @{
        title = 'Dracula'; dark = $true
        rosewater = 0xF8F8F2; flamingo = 0xFF79C6; pink = 0xFF79C6; mauve = 0xBD93F9; red = 0xFF5555; maroon = 0xFF6E6E
        peach = 0xFFB86C; yellow = 0xF1FA8C; green = 0x50FA7B; teal = 0x8BE9FD; sky = 0x8BE9FD; sapphire = 0x80BFFF
        blue = 0x8BE9FD; lavender = 0xBD93F9; text = 0xF8F8F2; subtext1 = 0xE6E6E0; subtext0 = 0xC9C9C4
        overlay2 = 0x959DC9; overlay1 = 0x7B86B8; overlay0 = 0x6272A4; surface2 = 0x565A75; surface1 = 0x44475A
        surface0 = 0x343746; base = 0x282A36; mantle = 0x21222C; crust = 0x191A21
    }
    tokyonight = @{
        title = 'Tokyo Night'; dark = $true
        rosewater = 0xC0CAF5; flamingo = 0xFF9E64; pink = 0xBB9AF7; mauve = 0xBB9AF7; red = 0xF7768E; maroon = 0xDB4B4B
        peach = 0xFF9E64; yellow = 0xE0AF68; green = 0x9ECE6A; teal = 0x1ABC9C; sky = 0x7DCFFF; sapphire = 0x2AC3DE
        blue = 0x7AA2F7; lavender = 0xBB9AF7; text = 0xC0CAF5; subtext1 = 0xA9B1D6; subtext0 = 0x9AA5CE
        overlay2 = 0x8A93B8; overlay1 = 0x737AA2; overlay0 = 0x565F89; surface2 = 0x414868; surface1 = 0x3B4261
        surface0 = 0x292E42; base = 0x1A1B26; mantle = 0x16161E; crust = 0x0F0F14
    }
    nord = @{
        title = 'Nord'; dark = $true
        rosewater = 0xECEFF4; flamingo = 0xD08770; pink = 0xB48EAD; mauve = 0xB48EAD; red = 0xBF616A; maroon = 0xBF616A
        peach = 0xD08770; yellow = 0xEBCB8B; green = 0xA3BE8C; teal = 0x8FBCBB; sky = 0x88C0D0; sapphire = 0x5E81AC
        blue = 0x81A1C1; lavender = 0xB48EAD; text = 0xECEFF4; subtext1 = 0xE5E9F0; subtext0 = 0xD8DEE9
        overlay2 = 0x93A0B5; overlay1 = 0x7B88A1; overlay0 = 0x616E88; surface2 = 0x4C566A; surface1 = 0x434C5E
        surface0 = 0x3B4252; base = 0x2E3440; mantle = 0x272C36; crust = 0x20242C
    }
    rosepine = @{
        title = 'Rose Pine'; dark = $true
        rosewater = 0xEBBCBA; flamingo = 0xEBBCBA; pink = 0xEBBCBA; mauve = 0xC4A7E7; red = 0xEB6F92; maroon = 0xEB6F92
        peach = 0xF6C177; yellow = 0xF6C177; green = 0x9CCFD8; teal = 0x31748F; sky = 0x9CCFD8; sapphire = 0x31748F
        blue = 0x9CCFD8; lavender = 0xC4A7E7; text = 0xE0DEF4; subtext1 = 0xD0CDE6; subtext0 = 0xB8B5CC
        overlay2 = 0xA8A4C0; overlay1 = 0x908CAA; overlay0 = 0x6E6A86; surface2 = 0x524F67; surface1 = 0x403D52
        surface0 = 0x26233A; base = 0x191724; mantle = 0x1F1D2E; crust = 0x141220
    }
}

$ThemeFile = Join-Path $HOME '.config\terminal-setup\theme'

function Get-ThemeName {
    $name = if (Test-Path $ThemeFile) { (Get-Content $ThemeFile -First 1).Trim().ToLower() }
    if ($name -and $Themes.Contains($name)) { $name } else { 'mocha' }
}

function ConvertTo-Hex([int]$Rgb) { '#{0:X6}' -f $Rgb }

function Get-TerminalScheme([string]$Name) {
    $p = $Themes[$Name]
    [ordered]@{
        name = $p.title
        background = ConvertTo-Hex $p.base; foreground = ConvertTo-Hex $p.text
        cursorColor = ConvertTo-Hex $p.rosewater; selectionBackground = ConvertTo-Hex $p.surface2
        black = ConvertTo-Hex $p.surface1; red = ConvertTo-Hex $p.red; green = ConvertTo-Hex $p.green; yellow = ConvertTo-Hex $p.yellow
        blue = ConvertTo-Hex $p.blue; purple = ConvertTo-Hex $p.mauve; cyan = ConvertTo-Hex $p.teal; white = ConvertTo-Hex $p.subtext1
        brightBlack = ConvertTo-Hex $p.surface2; brightRed = ConvertTo-Hex $p.red; brightGreen = ConvertTo-Hex $p.green; brightYellow = ConvertTo-Hex $p.yellow
        brightBlue = ConvertTo-Hex $p.blue; brightPurple = ConvertTo-Hex $p.mauve; brightCyan = ConvertTo-Hex $p.teal; brightWhite = ConvertTo-Hex $p.subtext0
    }
}

function Get-TerminalTheme([string]$Name) {
    $p = $Themes[$Name]
    [ordered]@{
        name = $p.title
        tab = [ordered]@{ background = (ConvertTo-Hex $p.base) + 'FF'; unfocusedBackground = $null; showCloseButton = 'hover' }
        tabRow = [ordered]@{ background = (ConvertTo-Hex $p.mantle) + 'FF'; unfocusedBackground = (ConvertTo-Hex $p.crust) + 'FF' }
        window = [ordered]@{ applicationTheme = $(if ($p.dark) { 'dark' } else { 'light' }); useMica = $false }
    }
}

function Get-OmpPalette([string]$Name) {
    $p = $Themes[$Name]
    [ordered]@{
        text = ConvertTo-Hex $p.text; subtext = ConvertTo-Hex $p.subtext0; overlay = ConvertTo-Hex $p.overlay1; dim = ConvertTo-Hex $p.overlay0
        blue = ConvertTo-Hex $p.blue; mauve = ConvertTo-Hex $p.mauve; green = ConvertTo-Hex $p.green; red = ConvertTo-Hex $p.red
        peach = ConvertTo-Hex $p.peach; yellow = ConvertTo-Hex $p.yellow; teal = ConvertTo-Hex $p.teal; lavender = ConvertTo-Hex $p.lavender
        sapphire = ConvertTo-Hex $p.sapphire
    }
}

# Rewrites the palette blocks of the oh-my-posh config from this table and returns the JSON text
function Set-OmpPalettes([string]$Json, [string]$Current) {
    $cfg = $Json | ConvertFrom-Json -AsHashtable
    $list = [ordered]@{}
    foreach ($k in $Themes.Keys) { $list[$k] = Get-OmpPalette $k }
    $cfg['palettes'] = [ordered]@{ template = '{{ .Env.TERMINAL_THEME }}'; list = $list }
    $cfg['palette'] = Get-OmpPalette $Current
    $cfg | ConvertTo-Json -Depth 16
}
'@
$EmbeddedFiles['lang'] = @'
$global:LangFile = Join-Path $HOME '.config\terminal-setup\lang'

function global:Get-LangName {
    $name = if (Test-Path $LangFile) { (Get-Content $LangFile -First 1).Trim().ToLower() }
    if ($name -in 'ru', 'en') { return $name }
    if ((Get-Culture).TwoLetterISOLanguageName -eq 'ru') { 'ru' } else { 'en' }
}

$global:Strings = @{
    ru = @{
        help_title    = '✦ Что умеет мой терминал'
        help_theme    = 'тема'
        help_hint     = 'F1 - то же с поиском · help <тема> - раздел · help <текст> - поиск · my - мои данные'
        help_found    = 'Нашлось в шпаргалке'
        help_user     = 'Моё'
        help_custom   = 'функция из custom.ps1'
        help_more     = '… ещё {0}'
        help_abbr_all = 'abbr - все'
        picker_header = 'Enter - вставить команду в строку · Esc'
        sections = @(
            @{ Key = 'nav'; Title = 'Навигация'; Rows = @(
                , ('z <часть имени>', 'перейти в папку, где часто бываешь', 'z coding')
                , ('zi', 'то же, но выбрать из списка')
                , ('Alt+C / nav', 'папки и файлы деревом с просмотром: → войти, ← вверх, Ctrl+E файлы, Ctrl+F искать вглубь')
                , ('.. / ... / ....', 'на уровень / два / три вверх')
                , ('mkcd <папка>', 'создать папку и сразу зайти в неё', 'mkcd new-app')
                , ('ii .', 'открыть текущую папку в Проводнике')
                , ('code .', 'открыть папку в VS Code')
            ) }
            @{ Key = 'files'; Title = 'Файлы'; Rows = @(
                , ('l / ll / lt', 'список · подробно с git-статусом · деревом')
                , ('bat <файл>', 'просмотр с подсветкой и номерами строк', 'bat .env')
                , ('touch <файл>', 'создать пустой файл / обновить дату')
                , ('which <команда>', 'где лежит программа', 'which python')
                , ('tldr <команда>', 'короткая шпаргалка с примерами', 'tldr tar')
                , ('pv [папка]', 'файлы с просмотром сбоку: Enter открыть, Ctrl+P показать здесь, Ctrl+Y путь', 'pv src')
                , ('o [путь]', 'открыть файл или папку в программе по умолчанию', 'o report.pdf')
                , ('ex <архив>', 'распаковать zip · tar.gz · 7z · xz в папку рядом', 'ex build.zip')
                , ('bak <файл>', 'копия рядом: файл.bak-дата - перед правкой', 'bak .env')
                , ('… | cb', 'вывод команды - в буфер обмена', 'll | cb')
            ) }
            @{ Key = 'search'; Title = 'Поиск'; Rows = @(
                , ('rg <текст>', 'найти текст во всех файлах папки', 'rg TODO -t py')
                , ('fd <имя>', 'найти файл по имени', 'fd docker-compose')
                , ('rgi <текст>', 'живой поиск по содержимому с просмотром, Enter открывает файл:строку', 'rgi TODO')
                , ('Ctrl+T', 'выбрать файл с просмотром и вставить путь в строку')
            ) }
            @{ Key = 'keys'; Title = 'Клавиши'; Rows = @(
                , ('F1', 'эта шпаргалка с поиском - Enter вставляет команду')
                , ('Ctrl+R', 'поиск по всей истории: 10 строк, PgUp/PgDn листать')
                , ('↑ / ↓', 'история по уже набранному началу', 'набрал git → ↑')
                , ('→ / Ctrl+→', 'принять подсказку целиком / по словам')
                , ('F2', 'подсказки: список ⇄ серый текст в строке')
                , ('Tab', 'меню дополнений (команды, пути, ssh-хосты)')
                , ('Ctrl+Backspace / Ctrl+Del', 'удалить слово слева / справа')
                , ('Ctrl+Z / Ctrl+Y', 'отменить / вернуть правку строки')
                , ('Shift+Enter', 'новая строка без запуска')
                , ('Ctrl+C', 'отменить строку · копировать, если выделено')
                , ('Ctrl+Shift+F', 'поиск по выводу в окне терминала')
                , ('Alt+Shift+D', 'разделить окно на две панели')
                , ('Win+`', 'терминал выпадает сверху поверх всего (quake)')
            ) }
            @{ Key = 'input'; Title = 'Ввод'; Rows = @(
                , ('начни печатать', 'до 50 подсказок из истории, ↑/↓ листать, Esc - скрыть')
                , ('g␣ k␣ d␣ dc␣', 'сокращения раскрываются сами: g → git', 'abbr - все')
                , ('abbr gcm ''git commit -m "%"''', 'своё сокращение, % - где оставить курсор')
                , ('вщслук зы ⏎', 'набрал в русской раскладке - исправится само')
                , ('h / h docker', 'последние 50 команд по 10 · с фильтром')
            ) }
            @{ Key = 'git'; Title = 'Git'; Rows = @(
                , ('gst', 'короткий статус')
                , ('lg', 'красивый лог, 30 коммитов', 'lg -n 100')
                , ('lazygit', 'git в полноэкранном интерфейсе: стейдж, коммиты, ветки')
                , ('gbr', 'ветки с логом справа, Enter переключает')
                , ('git diff', 'дифф с подсветкой (delta), n/N - к след./пред. файлу')
                , ('gh pr create', 'пулл-реквест из терминала (gh - GitHub CLI)')
                , ('my git', 'имя, почта, remotes текущего репо')
            ) }
            @{ Key = 'ssh'; Title = 'Серверы'; Rows = @(
                , ('my ssh [фильтр]', 'все SSH-хосты из ~/.ssh/config', 'my ssh prod')
                , ('jump [имя]', 'выбрать сервер из списка и подключиться', 'jump prod')
                , ('ssh <Tab>', 'дополнение имён хостов (и для scp)')
                , ('srv install [хост]', 'поставить/обновить такой же bash на сервере', 'srv install myserver -Env prod')
                , ('srv remove [хост]', 'откатить bashrc на сервере')
                , ('srv', 'подробно: что получает сервер, свои файлы для серверов')
            ) }
            @{ Key = 'dev'; Title = 'Инструменты'; Rows = @(
                , ('docker / kubectl / helm', 'Tab-дополнения подкоманд и флагов')
                , ('my k8s', 'текущий контекст и namespace kubectl, все контексты')
                , ('my docker', 'контейнеры и compose-проекты')
                , ('my sys', 'процессор, память, диски, топ процессов')
                , ('my ports [порт]', 'кто слушает порты', 'my ports 5432')
                , ('psg <имя>', 'процессы по имени: PID, память, запуск', 'psg node')
                , ('pk [имя]', 'выбрать процесс (Tab - несколько) и завершить', 'pk node')
                , ('my ip', 'IP-адреса и шлюз · my ip public - внешний IP')
                , ('my tools', 'версии всех установленных инструментов')
            ) }
            @{ Key = 'mine'; Title = 'Своё'; Rows = @(
                , ('new имя.py', 'своя команда: py · ps1 · js · ts · sh · go · rs · clj', 'new weather.py')
                , ('my cmds', 'мои команды, функции и сокращения')
                , ('ep', 'открыть папку профиля в VS Code: custom.ps1, bin\')
                , ('my config', 'где лежат все файлы и настройки')
                , ('theme [имя]', '10 тем на лету: catppuccin, black, gruvbox, dracula, nord…', 'theme latte')
                , ('lang [ru|en]', 'язык терминала и серверов')
                , ('doctor', 'проверить, что всё на месте и работает')
                , ('update', 'обновить terminal-setup с GitHub')
                , ('reload', 'перечитать профиль после правок')
                , ('Update-Completions', 'обновить Tab-дополнения после обновления CLI')
            ) }
        )
        nav_header = '→ войти  ← вверх  Enter - перейти/открыть  Ctrl+E - файлы  Ctrl+H - скрытые  Ctrl+F - искать вглубь  Ctrl+O - Проводник'
        pv_header = 'Enter - открыть  Ctrl+P - показать здесь  Ctrl+Y - скопировать путь'; pv_prompt = 'файлы'
        rgi_header = 'печатай - ищет по содержимому  Enter - открыть файл:строку  Ctrl+Y - скопировать'
        pk_header = 'Tab - отметить несколько  Enter - завершить'; pk_done = 'завершён {0}'
        gbr_header = 'Enter - переключиться на ветку'; gbr_none = 'не git-репозиторий'
        nav_deep = 'все папки внутри {0}'
        ex_nofile = 'нет файла: {0}'; ex_unknown = 'не знаю, чем распаковать: {0}'; ex_done = 'распаковано в {0}'
        cb_done = 'в буфере обмена: {0} строк'
        config_title = 'Где что лежит'; config_hint = 'ep - открыть папку профиля'
        config_rows = [ordered]@{
            profile = 'профиль PowerShell и команды'; custom = 'своё: функции, сокращения, переключатели'; bin = 'свои команды на любом языке'
            srvcustom = 'свои файлы для серверов (→ ~/.bashrc.d)'; settings = 'тема и язык'; omp = 'тема промпта oh-my-posh'
            completions = 'кэш Tab-дополнений'; predictor = 'кэш плагина подсказок'; wt = 'настройки Windows Terminal'
            vscode = 'настройки VS Code'; gitconfig = 'git: delta и имя'; ssh = 'SSH-хосты (my ssh, jump, srv)'
        }
        config_missing = 'нет'
        doctor_title = 'Проверка'; doctor_hint = 'terminal-setup {0}'
        doctor_tools = 'инструменты'; doctor_files = 'файлы профиля'; doctor_font = 'шрифт для всех пользователей'
        doctor_wt = 'Windows Terminal: схемы и PowerShell 7 по умолчанию'; doctor_psfzf = 'модуль PSFzf'
        doctor_predictor = 'подсказки из истории (до 50)'; doctor_custom = 'custom.ps1 без ошибок'
        doctor_startup = 'старт профиля'; doctor_ok = 'всё в порядке'; doctor_fix = 'починить: update'
        doctor_missing = 'нет: {0}'
        update_start = 'обновляю terminal-setup с GitHub…'; update_done = 'готово - reload или новая вкладка'
        update_fail = 'не удалось скачать установщик: {0}'
        no_insert = '^(Ctrl|Alt|Shift|Win|Tab|F\d|↑|→|начни|набрал|вщслук|g␣)'

        my_topics = [ordered]@{
            sys    = 'процессор, память, диски, топ процессов, контейнеры'
            ssh    = 'SSH-хосты из ~/.ssh/config                     my ssh prod'
            ports  = 'кто слушает порты                              my ports 8080'
            ip     = 'IP-адреса, шлюз · внешний IP                   my ip public'
            k8s    = 'контекст и namespace kubectl, все контексты'
            docker = 'контейнеры и compose-проекты'
            tools  = 'версии установленных инструментов'
            path   = 'PATH: что есть, чего нет, дубли'
            git    = 'имя, почта, remotes, алиасы git'
            cmds   = 'мои команды из bin, функции из custom.ps1, сокращения'
            config = 'где лежат все файлы и настройки'
            keys   = 'горячие клавиши'
        }
        my_title = 'my <тема>'; my_hint = 'Tab дополняет тему'
        units = 'Б', 'КБ', 'МБ', 'ГБ', 'ТБ', 'ПБ'

        sys_uptime = 'работает {0} д {1} ч {2} мин'; sys_cpu = 'процессор'; sys_mem = 'память'; sys_disk = 'диск'
        sys_cores = 'ядер'; of = 'из'; sys_bymem = 'по памяти'; sys_containers = 'контейнеры'
        docker_down = 'docker не отвечает - Docker Desktop выключен?'; docker_none = 'контейнеров нет'; docker_missing = 'docker не установлен'
        docker_hint = 'логи: docker logs -f <имя> · внутрь: docker exec -it <имя> sh'; docker_projects = 'compose-проекты'
        col_container = 'Контейнер'; col_status = 'Статус'; col_ports = 'Порты'
        k8s_missing = 'kubectl не установлен'; k8s_hint = 'сменить: kubectl config use-context <имя> · namespace: kubectl config set-context --current --namespace <ns>'
        k8s_none = 'контекстов нет (kubeconfig пуст)'; col_context = 'Контекст'; col_cluster = 'Кластер'
        ssh_title = 'SSH-хосты'; ssh_hint = 'подключиться: ssh <имя> · jump - выбрать из списка · ssh <Tab>'; ssh_empty = '~/.ssh/config пуст'
        ssh_dup = '⚠ {0} описан в config несколько раз - ssh берёт значения из первого блока (User {1})'
        col_name = 'Имя'; col_address = 'Адрес'; col_user = 'Пользователь'; col_port = 'Порт'; col_key = 'Ключ'
        nothing_found = 'ничего не найдено'
        jump_header = 'Enter - подключиться · Esc - отмена'
        ip_title = 'IP-адреса'; ip_hint = 'my ip public - внешний IP'; col_iface = 'Интерфейс'; ip_gateway = 'шлюз'; ip_public = 'внешний'; ip_public_fail = 'не удалось узнать внешний IP'
        ports_title = 'Слушающие порты'; ports_hint = 'my ports <порт|процесс> · my ports all - вместе с системными 49152+'; col_process = 'Процесс'
        path_title = 'PATH'; path_hint = 'порядок важен: побеждает папка выше'; col_folder = 'Папка'; path_dup = 'дубль'; path_missing = 'нет папки'
        tools_title = 'Инструменты'; tools_hint = 'обновить всё: winget upgrade --all'; col_program = 'Программа'; col_version = 'Версия'; col_where = 'Где'
        git_name = 'имя'; git_email = 'почта'; git_repo = 'репозиторий'; git_branch = 'ветка'; git_none = 'сейчас не в git-репозитории'
        cmds_title = 'Мои команды'; cmds_hint = 'new имя.py - создать · ep - открыть папку · {0}'
        cmds_empty = 'bin\ пуста - new weather.py ''погода'' создаст первую команду'; cmds_abbr = 'сокращения'; cmds_abbr_hint = 'abbr имя ''текст'' - добавить · abbr -Remove имя'

        hist_title = 'История'; hist_filtered = 'История: «{0}»'; hist_hint = 'новые сверху · Ctrl+R - поиск с вставкой в строку'
        hist_more = '… +{0} стр.'; hist_page = '── {0}/{1} · Enter или Пробел - ещё · Q/Esc - хватит ──'

        abbr_title = 'Сокращения'; abbr_hint = 'раскрываются по пробелу · abbr имя ''текст'' - добавить · abbr -Remove имя'
        abbr_usage = 'abbr имя ''во что раскрыть'''; abbr_saved = 'записано в custom.ps1: {0}'

        new_title = 'new имя.расширение [описание]'; new_hint = 'создаёт команду в {0}'; new_run = 'запуск: {0}'; new_need = 'нужен {0}'
        new_missing = 'не установлен'; new_bad_ext = 'не знаю расширение {0} - new без аргументов покажет список'
        new_bad_name = 'имя: латиница, цифры, - и _'; new_taken = 'имя {0} уже занято ({1} {2})'
        new_ready = 'команда готова: '; new_args = '[аргументы]'; new_via = 'запуск через {0}'; new_norunner = 'чтобы запускать, нужен {0}'
        new_default = 'моя команда'; bin_norunner = 'нечем запустить {0}: нужен {1}'

        theme_title = 'Тема'; theme_hint = 'theme <вариант> - переключить всё сразу: терминал, промпт, подсветку'
        theme_dark = 'тёмная'; theme_light = 'светлая'; theme_only = 'есть только: {0}'; theme_done = 'Windows Terminal переключится сам, новые вкладки - тоже'

        lang_title = 'Язык'; lang_hint = 'lang ru · lang en - и перечитать профиль'; lang_ru = 'русский'; lang_en = 'английский'
        lang_only = 'есть только: ru, en'; lang_done = 'язык: {0} - reload или новая вкладка; серверы: srv install <хост>'

        srv_missing = 'нет {0} - запусти setup-terminal.ps1'; srv_env = '-Env: только буквы, цифры, - и _ (none - убрать метку)'
        srv_pick = 'srv {0} - выбери сервер · Esc - отмена'; srv_removed = 'откачено'; srv_restore = '- вернуть: srv install {0}'
        srv_done = 'готово'; srv_relogin = '- перезайди: ssh {0}, затем help'; srv_error = 'ошибка (код {0}) - на сервере ничего не менялось после этой точки'
        srv_title = 'srv - такой же bash на серверах'; srv_templates = 'шаблоны: {0}'
        srv_rows = @(
            , ('srv install [хост…]', 'поставить или обновить (без хоста - выбор из списка)', 'srv install myserver')
            , ('srv install <хост> -Env prod', 'то же + метка в промпте: prod / staging / dev / none')
            , ('srv install <хост> -Lang en', 'язык на сервере (по умолчанию - как здесь)')
            , ('srv remove [хост]', 'откатить: убрать подключение, файлы → *.off')
        )
        srv_gets = 'Что получает сервер'
        srv_gets_rows = @(
            'промпт как здесь (метка окружения, ветка, время долгой команды), большая история, ↑/↓ по началу, help, sys'
            'проекты находятся сами (docker compose ls): <имя> · <имя> logs web · <имя> sh web · proj · app'
            'защита: docker down -v / volume rm / prune просят yes; rm, cp, mv - подтверждение'
            'ничего в фоне и ничего не ставится - только файлы в домашней папке'
        )
        srv_custom = 'Свои команды для серверов'
        srv_custom_rows = @(
            '{0}\custom\*.sh - уезжают на каждый сервер в ~/.bashrc.d/ при srv install'
            'строка # help: имя - описание в файле попадает в help на сервере'
            'на самом сервере: ~/.bashrc.d/*.sh и ~/bin/* - остаются при обновлении'
        )
        srv_note = 'Каждый запуск: бэкап, проверка до изменений, одно ssh-подключение. Повторный запуск ничего не ломает.'
    }

    en = @{
        help_title    = '✦ What my terminal can do'
        help_theme    = 'theme'
        help_hint     = 'F1 - same with search · help <topic> - one section · help <text> - search · my - my data'
        help_found    = 'Found in the cheat sheet'
        help_user     = 'Mine'
        help_custom   = 'function from custom.ps1'
        help_more     = '… {0} more'
        help_abbr_all = 'abbr - all'
        picker_header = 'Enter - insert the command · Esc'
        sections = @(
            @{ Key = 'nav'; Title = 'Navigation'; Rows = @(
                , ('z <part of name>', 'jump to a folder you use often', 'z coding')
                , ('zi', 'same, but pick from a list')
                , ('Alt+C / nav', 'folders and files as a tree with preview: → enter, ← up, Ctrl+E files, Ctrl+F search deep')
                , ('.. / ... / ....', 'one / two / three levels up')
                , ('mkcd <folder>', 'create a folder and enter it', 'mkcd new-app')
                , ('ii .', 'open the current folder in Explorer')
                , ('code .', 'open the folder in VS Code')
            ) }
            @{ Key = 'files'; Title = 'Files'; Rows = @(
                , ('l / ll / lt', 'list · details with git status · tree')
                , ('bat <file>', 'view with highlighting and line numbers', 'bat .env')
                , ('touch <file>', 'create an empty file / update its date')
                , ('which <command>', 'where a program lives', 'which python')
                , ('tldr <command>', 'short cheat sheet with examples', 'tldr tar')
                , ('pv [folder]', 'files with a preview pane: Enter open, Ctrl+P print here, Ctrl+Y path', 'pv src')
                , ('o [path]', 'open a file or folder with the default app', 'o report.pdf')
                , ('ex <archive>', 'extract zip · tar.gz · 7z · xz into a folder next to it', 'ex build.zip')
                , ('bak <file>', 'copy next to it: file.bak-date - before editing', 'bak .env')
                , ('… | cb', 'command output → clipboard', 'll | cb')
            ) }
            @{ Key = 'search'; Title = 'Search'; Rows = @(
                , ('rg <text>', 'find text in all files of the folder', 'rg TODO -t py')
                , ('fd <name>', 'find a file by name', 'fd docker-compose')
                , ('rgi <text>', 'live grep with preview, Enter opens file:line', 'rgi TODO')
                , ('Ctrl+T', 'pick a file with preview and insert its path')
            ) }
            @{ Key = 'keys'; Title = 'Keys'; Rows = @(
                , ('F1', 'this cheat sheet with search - Enter inserts the command')
                , ('Ctrl+R', 'search the whole history: 10 rows, PgUp/PgDn to scroll')
                , ('↑ / ↓', 'history filtered by what you typed', 'type git → ↑')
                , ('→ / Ctrl+→', 'accept the suggestion fully / word by word')
                , ('F2', 'suggestions: list ⇄ grey inline text')
                , ('Tab', 'completion menu (commands, paths, ssh hosts)')
                , ('Ctrl+Backspace / Ctrl+Del', 'delete the word left / right')
                , ('Ctrl+Z / Ctrl+Y', 'undo / redo the edit')
                , ('Shift+Enter', 'new line without running')
                , ('Ctrl+C', 'cancel the line · copy when text is selected')
                , ('Ctrl+Shift+F', 'search the terminal output')
                , ('Alt+Shift+D', 'split the window into two panes')
                , ('Win+`', 'terminal drops down over everything (quake)')
            ) }
            @{ Key = 'input'; Title = 'Input'; Rows = @(
                , ('start typing', 'up to 50 suggestions from history, ↑/↓ to scroll, Esc to hide')
                , ('g␣ k␣ d␣ dc␣', 'abbreviations expand on space: g → git', 'abbr - all')
                , ('abbr gcm ''git commit -m "%"''', 'your own abbreviation, % - where the cursor goes')
                , ('h / h docker', 'last 50 commands, 10 per page · filtered')
            ) }
            @{ Key = 'git'; Title = 'Git'; Rows = @(
                , ('gst', 'short status')
                , ('lg', 'pretty log, 30 commits', 'lg -n 100')
                , ('lazygit', 'full-screen git: stage, commit, branches')
                , ('gbr', 'branches with their log on the right, Enter switches')
                , ('git diff', 'diff with highlighting (delta), n/N - next/previous file')
                , ('gh pr create', 'pull request from the terminal (gh - GitHub CLI)')
                , ('my git', 'name, email, remotes of the current repo')
            ) }
            @{ Key = 'ssh'; Title = 'Servers'; Rows = @(
                , ('my ssh [filter]', 'all SSH hosts from ~/.ssh/config', 'my ssh prod')
                , ('jump [name]', 'pick a server from the list and connect', 'jump prod')
                , ('ssh <Tab>', 'host name completion (also for scp)')
                , ('srv install [host]', 'install/update the same bash on a server', 'srv install myserver -Env prod')
                , ('srv remove [host]', 'roll back the server bashrc')
                , ('srv', 'details: what the server gets, your own files for servers')
            ) }
            @{ Key = 'dev'; Title = 'Tools'; Rows = @(
                , ('docker / kubectl / helm', 'Tab completion of subcommands and flags')
                , ('my k8s', 'current kubectl context and namespace, all contexts')
                , ('my docker', 'containers and compose projects')
                , ('my sys', 'cpu, memory, disks, top processes')
                , ('my ports [port]', 'who listens on which port', 'my ports 5432')
                , ('psg <name>', 'processes by name: PID, memory, command line', 'psg node')
                , ('pk [name]', 'pick a process (Tab for several) and kill it', 'pk node')
                , ('my ip', 'IP addresses and gateway · my ip public - external IP')
                , ('my tools', 'versions of all installed tools')
            ) }
            @{ Key = 'mine'; Title = 'Mine'; Rows = @(
                , ('new name.py', 'your own command: py · ps1 · js · ts · sh · go · rs · clj', 'new weather.py')
                , ('my cmds', 'my commands, functions and abbreviations')
                , ('ep', 'open the profile folder in VS Code: custom.ps1, bin\')
                , ('my config', 'where every file and setting lives')
                , ('theme [name]', '10 themes, switched live: catppuccin, black, gruvbox, dracula, nord…', 'theme latte')
                , ('lang [ru|en]', 'language of the terminal and servers')
                , ('doctor', 'check that everything is in place and works')
                , ('update', 'update terminal-setup from GitHub')
                , ('reload', 're-read the profile after edits')
                , ('Update-Completions', 'refresh Tab completions after updating a CLI')
            ) }
        )
        nav_header = '→ enter  ← up  Enter - go/open  Ctrl+E - files  Ctrl+H - hidden  Ctrl+F - search deep  Ctrl+O - Explorer'
        pv_header = 'Enter - open  Ctrl+P - print here  Ctrl+Y - copy path'; pv_prompt = 'files'
        rgi_header = 'type to search contents  Enter - open file:line  Ctrl+Y - copy'
        pk_header = 'Tab - select several  Enter - kill'; pk_done = 'killed {0}'
        gbr_header = 'Enter - switch to the branch'; gbr_none = 'not a git repository'
        nav_deep = 'all folders under {0}'
        ex_nofile = 'no such file: {0}'; ex_unknown = 'do not know how to extract: {0}'; ex_done = 'extracted to {0}'
        cb_done = 'in the clipboard: {0} lines'
        config_title = 'Where things live'; config_hint = 'ep - open the profile folder'
        config_rows = [ordered]@{
            profile = 'PowerShell profile and commands'; custom = 'yours: functions, abbreviations, switches'; bin = 'your commands in any language'
            srvcustom = 'your files for servers (→ ~/.bashrc.d)'; settings = 'theme and language'; omp = 'oh-my-posh prompt theme'
            completions = 'Tab completion cache'; predictor = 'suggestions plugin cache'; wt = 'Windows Terminal settings'
            vscode = 'VS Code settings'; gitconfig = 'git: delta and identity'; ssh = 'SSH hosts (my ssh, jump, srv)'
        }
        config_missing = 'missing'
        doctor_title = 'Check-up'; doctor_hint = 'terminal-setup {0}'
        doctor_tools = 'tools'; doctor_files = 'profile files'; doctor_font = 'font installed for all users'
        doctor_wt = 'Windows Terminal: schemes and PowerShell 7 as default'; doctor_psfzf = 'PSFzf module'
        doctor_predictor = 'history suggestions (up to 50)'; doctor_custom = 'custom.ps1 has no errors'
        doctor_startup = 'profile startup'; doctor_ok = 'all good'; doctor_fix = 'fix: update'
        doctor_missing = 'missing: {0}'
        update_start = 'updating terminal-setup from GitHub…'; update_done = 'done - reload or open a new tab'
        update_fail = 'could not download the installer: {0}'
        no_insert = '^(Ctrl|Alt|Shift|Win|Tab|F\d|↑|→|start|type|g␣)'

        my_topics = [ordered]@{
            sys    = 'cpu, memory, disks, top processes, containers'
            ssh    = 'SSH hosts from ~/.ssh/config                   my ssh prod'
            ports  = 'who listens on which port                     my ports 8080'
            ip     = 'IP addresses, gateway · external IP           my ip public'
            k8s    = 'kubectl context and namespace, all contexts'
            docker = 'containers and compose projects'
            tools  = 'versions of installed tools'
            path   = 'PATH: present, missing, duplicates'
            git    = 'name, email, remotes, git aliases'
            cmds   = 'my commands from bin, functions from custom.ps1, abbreviations'
            config = 'where every file and setting lives'
            keys   = 'keyboard shortcuts'
        }
        my_title = 'my <topic>'; my_hint = 'Tab completes the topic'
        units = 'B', 'KB', 'MB', 'GB', 'TB', 'PB'

        sys_uptime = 'up {0} d {1} h {2} min'; sys_cpu = 'cpu'; sys_mem = 'memory'; sys_disk = 'disk'
        sys_cores = 'cores'; of = 'of'; sys_bymem = 'by memory'; sys_containers = 'containers'
        docker_down = 'docker is not responding - is Docker Desktop off?'; docker_none = 'no containers'; docker_missing = 'docker is not installed'
        docker_hint = 'logs: docker logs -f <name> · shell: docker exec -it <name> sh'; docker_projects = 'compose projects'
        col_container = 'Container'; col_status = 'Status'; col_ports = 'Ports'
        k8s_missing = 'kubectl is not installed'; k8s_hint = 'switch: kubectl config use-context <name> · namespace: kubectl config set-context --current --namespace <ns>'
        k8s_none = 'no contexts (empty kubeconfig)'; col_context = 'Context'; col_cluster = 'Cluster'
        ssh_title = 'SSH hosts'; ssh_hint = 'connect: ssh <name> · jump - pick from a list · ssh <Tab>'; ssh_empty = '~/.ssh/config is empty'
        ssh_dup = '⚠ {0} appears in config more than once - ssh uses the first block (User {1})'
        col_name = 'Name'; col_address = 'Address'; col_user = 'User'; col_port = 'Port'; col_key = 'Key'
        nothing_found = 'nothing found'
        jump_header = 'Enter - connect · Esc - cancel'
        ip_title = 'IP addresses'; ip_hint = 'my ip public - external IP'; col_iface = 'Interface'; ip_gateway = 'gateway'; ip_public = 'external'; ip_public_fail = 'could not get the external IP'
        ports_title = 'Listening ports'; ports_hint = 'my ports <port|process> · my ports all - including system 49152+'; col_process = 'Process'
        path_title = 'PATH'; path_hint = 'order matters: the folder above wins'; col_folder = 'Folder'; path_dup = 'duplicate'; path_missing = 'missing'
        tools_title = 'Tools'; tools_hint = 'update everything: winget upgrade --all'; col_program = 'Program'; col_version = 'Version'; col_where = 'Where'
        git_name = 'name'; git_email = 'email'; git_repo = 'repository'; git_branch = 'branch'; git_none = 'not in a git repository'
        cmds_title = 'My commands'; cmds_hint = 'new name.py - create · ep - open the folder · {0}'
        cmds_empty = 'bin\ is empty - new weather.py ''weather'' creates the first command'; cmds_abbr = 'abbreviations'; cmds_abbr_hint = 'abbr name ''text'' - add · abbr -Remove name'

        hist_title = 'History'; hist_filtered = 'History: "{0}"'; hist_hint = 'newest first · Ctrl+R - search and insert'
        hist_more = '… +{0} lines'; hist_page = '── {0}/{1} · Enter or Space - more · Q/Esc - stop ──'

        abbr_title = 'Abbreviations'; abbr_hint = 'expand on space · abbr name ''text'' - add · abbr -Remove name'
        abbr_usage = 'abbr name ''expansion'''; abbr_saved = 'saved to custom.ps1: {0}'

        new_title = 'new name.extension [description]'; new_hint = 'creates a command in {0}'; new_run = 'runs with: {0}'; new_need = 'needs {0}'
        new_missing = 'not installed'; new_bad_ext = 'unknown extension {0} - new without arguments shows the list'
        new_bad_name = 'name: latin letters, digits, - and _'; new_taken = 'name {0} is already taken ({1} {2})'
        new_ready = 'command ready: '; new_args = '[arguments]'; new_via = 'runs with {0}'; new_norunner = 'to run it you need {0}'
        new_default = 'my command'; bin_norunner = 'nothing to run {0} with: needs {1}'

        theme_title = 'Theme'; theme_hint = 'theme <variant> - switch everything at once: terminal, prompt, highlighting'
        theme_dark = 'dark'; theme_light = 'light'; theme_only = 'available: {0}'; theme_done = 'Windows Terminal switches by itself, new tabs too'

        lang_title = 'Language'; lang_hint = 'lang ru · lang en - then reload the profile'; lang_ru = 'Russian'; lang_en = 'English'
        lang_only = 'available: ru, en'; lang_done = 'language: {0} - reload or open a new tab; servers: srv install <host>'

        srv_missing = 'missing {0} - run setup-terminal.ps1'; srv_env = '-Env: letters, digits, - and _ only (none - remove the label)'
        srv_pick = 'srv {0} - pick a server · Esc - cancel'; srv_removed = 'rolled back'; srv_restore = '- restore: srv install {0}'
        srv_done = 'done'; srv_relogin = '- reconnect: ssh {0}, then help'; srv_error = 'error (code {0}) - nothing on the server changed after this point'
        srv_title = 'srv - the same bash on servers'; srv_templates = 'templates: {0}'
        srv_rows = @(
            , ('srv install [host…]', 'install or update (no host - pick from a list)', 'srv install myserver')
            , ('srv install <host> -Env prod', 'same + a label in the prompt: prod / staging / dev / none')
            , ('srv install <host> -Lang ru', 'language on the server (default - same as here)')
            , ('srv remove [host]', 'roll back: remove the hook, files → *.off')
        )
        srv_gets = 'What the server gets'
        srv_gets_rows = @(
            'the same prompt (environment label, branch, duration of long commands), big history, ↑/↓ by prefix, help, sys'
            'projects are discovered (docker compose ls): <name> · <name> logs web · <name> sh web · proj · app'
            'guards: docker down -v / volume rm / prune ask for yes; rm, cp, mv ask before mass changes'
            'nothing in the background and nothing installed - only files in the home folder'
        )
        srv_custom = 'Your own commands for servers'
        srv_custom_rows = @(
            '{0}\custom\*.sh - copied to every server into ~/.bashrc.d/ on srv install'
            'a line # help: name - description in a file shows up in help on the server'
            'on the server itself: ~/.bashrc.d/*.sh and ~/bin/* survive updates'
        )
        srv_note = 'Every run: backup, checks before changes, one ssh connection. Running again breaks nothing.'
    }
}
'@
$EmbeddedFiles['toolkit'] = @'
# Core: loaded before the first prompt. Everything the user types lives in toolkit-lazy.ps1,
# which Complete-TerminalSetup loads once the prompt is on screen.
function _tkRgb([int]$hex) { $PSStyle.Foreground.FromRgb($hex) }
function _tkBg([int]$hex) { $PSStyle.Background.FromRgb($hex) }

function Set-TerminalPalette {
    $p = $global:Palette
    $global:TK = @{
        R = $PSStyle.Reset; B = $PSStyle.Bold; I = $PSStyle.Italic
        title = _tkRgb $p.mauve; cmd = _tkRgb $p.blue; text = _tkRgb $p.text; dim = _tkRgb $p.overlay0
        ok = _tkRgb $p.green; warn = _tkRgb $p.yellow; err = _tkRgb $p.red; accent = _tkRgb $p.peach
        teal = _tkRgb $p.teal; lavender = _tkRgb $p.lavender
    }

    $PSStyle.FileInfo.Directory    = _tkRgb $p.blue
    $PSStyle.FileInfo.SymbolicLink = _tkRgb $p.teal
    $PSStyle.FileInfo.Executable   = _tkRgb $p.green
    foreach ($ext in '.zip', '.7z', '.rar', '.tar', '.gz') { $PSStyle.FileInfo.Extension[$ext] = _tkRgb $p.peach }
    foreach ($ext in '.ps1', '.psm1', '.sh', '.py', '.js', '.ts') { $PSStyle.FileInfo.Extension[$ext] = _tkRgb $p.green }
    $PSStyle.Formatting.TableHeader  = (_tkRgb $p.mauve) + $PSStyle.Bold
    $PSStyle.Formatting.FormatAccent = _tkRgb $p.mauve
    $PSStyle.Formatting.Error        = _tkRgb $p.red
    $PSStyle.Formatting.ErrorAccent  = _tkRgb $p.peach
    $PSStyle.Formatting.Warning      = _tkRgb $p.yellow
    $PSStyle.Formatting.Verbose      = _tkRgb $p.overlay1
    $PSStyle.Formatting.Debug        = _tkRgb $p.overlay1
    $PSStyle.Progress.Style          = _tkRgb $p.mauve

    $hex = { param($c) '#{0:x6}' -f $c }
    $env:FZF_DEFAULT_OPTS = @(
        '--height=45% --layout=reverse --border=rounded --info=inline-right'
        '--prompt="❯ " --pointer="▌" --marker="●"'
        "--color=bg:-1,bg+:$(& $hex $p.surface0),fg:$(& $hex $p.text),fg+:$(& $hex $p.text),hl:$(& $hex $p.red),hl+:$(& $hex $p.red)"
        "--color=border:$(& $hex $p.surface2),header:$(& $hex $p.red),info:$(& $hex $p.overlay1),prompt:$(& $hex $p.mauve)"
        "--color=pointer:$(& $hex $p.rosewater),marker:$(& $hex $p.lavender),spinner:$(& $hex $p.rosewater),selected-bg:$(& $hex $p.surface1)"
    ) -join ' '

    if ($global:isInteractive -and (Get-Module PSReadLine)) {
        Set-PSReadLineOption -Colors @{
            Default                = _tkRgb $p.text
            Command                = _tkRgb $p.blue
            Parameter              = _tkRgb $p.teal
            Operator               = _tkRgb $p.sky
            Variable               = _tkRgb $p.flamingo
            String                 = _tkRgb $p.green
            Number                 = _tkRgb $p.peach
            Type                   = _tkRgb $p.yellow
            Member                 = _tkRgb $p.lavender
            Keyword                = _tkRgb $p.mauve
            Comment                = (_tkRgb $p.overlay0) + $PSStyle.Italic
            Error                  = _tkRgb $p.red
            Emphasis               = _tkRgb $p.yellow
            Selection              = _tkBg $p.surface1
            ContinuationPrompt     = _tkRgb $p.overlay0
            InlinePrediction       = _tkRgb $p.overlay0
            ListPrediction         = _tkRgb $p.mauve
            ListPredictionSelected = _tkBg $p.surface0
            ListPredictionTooltip  = _tkRgb $p.overlay1
        }
    }
}

function Write-TkRow([string]$Command, [string]$Description, [string]$Example) {
    $cmdCell = if ($Command.Length -ge 26) { $Command + '  ' } else { $Command.PadRight(26) }
    $line = '    ' + $TK.cmd + $cmdCell + $TK.R + $TK.text + $Description + $TK.R
    if ($Example) { $line += '  ' + $TK.dim + $Example + $TK.R }
    Write-Host $line
}

function Write-TkTitle([string]$Title, [string]$Hint) {
    Write-Host ''
    Write-Host ("  {0}{1}{2}{3}  {4}{5}{6}" -f $TK.title, $TK.B, $Title, $TK.R, $TK.dim, $Hint, $TK.R)
}

function Write-TkTable($Rows, $Columns) {
    $widths = foreach ($col in $Columns) {
        $max = $col.N.Length
        foreach ($r in $Rows) { $len = "$($r.($col.P))".Length; if ($len -gt $max) { $max = $len } }
        $max
    }
    $head = for ($i = 0; $i -lt $Columns.Count; $i++) { $Columns[$i].N.PadRight($widths[$i]) }
    if (($head -join '').Trim()) { Write-Host ('  ' + $TK.dim + ($head -join '   ') + $TK.R) }
    foreach ($r in $Rows) {
        $cells = for ($i = 0; $i -lt $Columns.Count; $i++) {
            $col = $Columns[$i]
            $color = if ($col.C -is [scriptblock]) { $TK[(& $col.C $r)] } else { $TK[$col.C] }
            $color + "$($r.($col.P))".PadRight($widths[$i]) + $TK.R
        }
        Write-Host ('  ' + ($cells -join '   '))
    }
}

function Get-TkBar([double]$Percent, [int]$Width = 20) {
    $filled = [math]::Round([math]::Min(100, [math]::Max(0, $Percent)) / 100 * $Width)
    $color = if ($Percent -ge 90) { $TK.err } elseif ($Percent -ge 70) { $TK.warn } else { $TK.ok }
    $color + ('█' * $filled) + $TK.dim + ('░' * ($Width - $filled)) + $TK.R + (' {0,3:N0}%' -f $Percent)
}

# ── abbreviations (fish-style: expand on space/Enter at command position) ────
$global:Abbreviations = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)

function abbr {
    param([string]$Name, [string]$Expansion, [switch]$Remove)
    $custom = Join-Path $global:ProfileDir 'custom.ps1'
    if ($Remove) {
        [void]$global:Abbreviations.Remove($Name)
        if (Test-Path $custom) {
            $kept = Get-Content $custom | Where-Object { $_ -notmatch "^\s*abbr\s+(['`"]?)$([regex]::Escape($Name))\1\s" }
            [IO.File]::WriteAllLines($custom, [string[]]$kept, [Text.UTF8Encoding]::new($false))
        }
        return
    }
    if (-not $Name) {
        Complete-TerminalSetup
        Write-TkTitle $TkStr.abbr_title $TkStr.abbr_hint
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
        Write-Host ''
        return
    }
    if (-not $Expansion) { Complete-TerminalSetup; Write-Host "  $($TK.err)$($TkStr.abbr_usage)$($TK.R)"; return }
    $global:Abbreviations[$Name] = $Expansion
    # typed interactively (not sourced from a file): persist to custom.ps1
    if ($MyInvocation.ScriptName -eq '' -and $global:isInteractive) {
        $line = "abbr $Name '$($Expansion.Replace("'", "''"))'"
        if (-not (Test-Path $custom) -or -not (Select-String -Path $custom -SimpleMatch $line -Quiet)) {
            Add-Content $custom "`n$line" -Encoding utf8
            Complete-TerminalSetup
            Write-Host ("  {0}{1}{2}" -f $TK.dim, ($TkStr.abbr_saved -f $line), $TK.R)
        }
    }
}

# Returns @{Start; Length; Text; Cursor} when the word before the cursor is an abbreviation
# in command position (line start or after | ; & ( {). '%' in the expansion marks the cursor.
function Expand-Abbreviation([string]$Line, [int]$Cursor) {
    if (-not $global:Abbreviations.Count -or $Cursor -le 0) { return }
    $before = $Line.Substring(0, $Cursor)
    if ($before -notmatch '(?:^|[|;&({])\s*(\S+)$') { return }
    $word = $Matches[1]
    if (-not $global:Abbreviations.ContainsKey($word)) { return }
    $text = $global:Abbreviations[$word]
    $marker = $text.IndexOf('%')
    if ($marker -ge 0) { $text = $text.Remove($marker, 1) }
    $start = $Cursor - $word.Length
    @{ Start = $start; Length = $word.Length; Text = $text; Cursor = $(if ($marker -ge 0) { $start + $marker } else { -1 }) }
}

foreach ($pair in @{ g = 'git'; k = 'kubectl'; d = 'docker'; dc = 'docker compose'; gco = 'git checkout'; gp = 'git push'; gl = 'git pull'; gcm = 'git commit -m "%"'; kgp = 'kubectl get pods'; kga = 'kubectl get all' }.GetEnumerator()) {
    $global:Abbreviations[$pair.Key] = $pair.Value
}

# ── keyboard layout: a command typed in the Russian layout becomes its Latin counterpart ──
$TkLayoutMap = @{}
$ru = 'ёйцукенгшщзхъфывапролджэячсмитьбюЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ'
$en = '`qwertyuiop[]asdfghjkl;''zxcvbnm,.~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>'
for ($i = 0; $i -lt $ru.Length; $i++) { $TkLayoutMap[$ru[$i]] = $en[$i] }
Remove-Variable ru, en, i

function Convert-Layout([string]$Text) {
    $sb = [Text.StringBuilder]::new($Text.Length)
    foreach ($ch in $Text.ToCharArray()) { [void]$sb.Append($(if ($TkLayoutMap.ContainsKey($ch)) { $TkLayoutMap[$ch] } else { $ch })) }
    $sb.ToString()
}

# Only when the first word is Cyrillic, is not a real command, and converts to a known one
function Repair-CommandLayout([string]$Line) {
    if ($Line -notmatch '^\s*[А-Яа-яЁё]') { return }
    $first = ($Line.Trim() -split '\s+', 2)[0]
    if (Get-Command $first -ErrorAction SilentlyContinue) { return }
    $fixed = Convert-Layout $first
    if ($fixed -eq $first) { return }
    if (-not (Get-Command $fixed -ErrorAction SilentlyContinue) -and -not $global:Abbreviations.ContainsKey($fixed)) { return }
    Convert-Layout $Line
}

# ── bin\: every script becomes a command, runner chosen by extension ─────────
$global:ScriptRunners = [ordered]@{
    '.ps1' = @('pwsh -NoProfile -File')
    '.py'  = @('uv run', 'python')
    '.js'  = @('node')
    '.ts'  = @('bun', 'deno run -A', 'node')
    '.sh'  = @('bash')
    '.go'  = @('go run')
    '.rs'  = @('rust-script')
    '.clj' = @('bb')
    '.rb'  = @('ruby')
    '.lua' = @('lua')
    '.php' = @('php')
}

function Get-ScriptRunner([string]$Extension) {
    foreach ($candidate in $global:ScriptRunners[$Extension]) {
        if (Get-Command ($candidate -split ' ')[0] -ErrorAction Ignore) { return $candidate }
    }
}

function Register-BinCommands([string]$Dir) {
    $global:UserCommands = @()
    if (-not (Test-Path $Dir)) { return }
    if (($env:PATH -split ';') -notcontains $Dir) { $env:PATH = "$Dir;$env:PATH" }
    foreach ($f in Get-ChildItem $Dir -File | Sort-Object Name) {
        $name = $f.BaseName
        $ext = $f.Extension.ToLower()
        if (-not $global:ScriptRunners.Contains($ext) -or $name -notmatch '^[A-Za-z_][\w-]*$') { continue }
        # never shadow a real command; bin itself is on PATH, so ignore matches from there
        $taken = Get-Command $name -All -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -notlike "$Dir\*" -and $_.ScriptBlock -notlike '*UserCommand*' } | Select-Object -First 1
        if ($taken) { continue }
        $help = (Get-Content $f.FullName -First 15 | Select-String -Pattern '^\s*(#|//|;;|--)\s*help:\s*(.+)$' | Select-Object -First 1)
        $help = if ($help) { $help.Matches[0].Groups[2].Value.Trim() } else { '' }
        $runner = Get-ScriptRunner $ext
        $body = if ($runner) {
            $parts = ($runner -split ' ') | ForEach-Object { "'$_'" }
            "# UserCommand`n& $($parts -join ' ') '$($f.FullName)' @args"
        } else {
            "# UserCommand`nComplete-TerminalSetup; Write-Host ('  ' + (`$TkStr.bin_norunner -f '$($f.Name)', '$($global:ScriptRunners[$ext] -join ' / ')'))"
        }
        Set-Item "Function:global:$name" -Value ([scriptblock]::Create($body))
        $global:UserCommands += [pscustomobject]@{ Name = $name; File = $f.Name; Help = $help; Runner = $(if ($runner) { $runner } else { '- ' + ($global:ScriptRunners[$ext] -join '/') }); Path = $f.FullName }
    }
}
'@
$EmbeddedFiles['toolkit-lazy'] = @'
# Loaded by Complete-TerminalSetup right after the first prompt (PowerShell.OnIdle), so startup stays fast.

function global:Format-TkSize([double]$Bytes) {
    foreach ($u in $TkStr.units) { if ($Bytes -lt 1024) { return ('{0:N1} {1}' -f $Bytes, $u) -replace '[.,]0 ', ' ' }; $Bytes /= 1024 }
    '{0:N1} {1}' -f $Bytes, $TkStr.units[-1]
}

# docker/kubectl can hang for a long time when their daemon is down
function global:Invoke-WithTimeout([string]$Command, [string[]]$Arguments, [int]$Milliseconds = 3000) {
    $exe = (Get-Command $Command -ErrorAction SilentlyContinue).Source
    if (-not $exe) { return $null }
    $psi = [Diagnostics.ProcessStartInfo]::new($exe)
    foreach ($a in $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $proc = [Diagnostics.Process]::Start($psi)
    $out = $proc.StandardOutput.ReadToEndAsync()
    if (-not $proc.WaitForExit($Milliseconds)) { try { $proc.Kill() } catch {}; return $null }
    if ($proc.ExitCode -ne 0) { return $null }
    $out.Result -split "`n" | Where-Object { $_.Trim() }
}

# ── help ─────────────────────────────────────────────────────────────────────
function global:Get-TkUserSection {
    $rows = @()
    foreach ($c in $global:UserCommands) { $rows += , ($c.Name, $c.Help, ("bin\" + $c.File)) }
    foreach ($f in $global:CustomFunctions) { $rows += , ($f, $TkStr.help_custom) }
    if ($global:Abbreviations.Count) {
        $list = ($global:Abbreviations.GetEnumerator() | Select-Object -First 4 | ForEach-Object { "$($_.Key)→$($_.Value)" }) -join '  '
        if ($global:Abbreviations.Count -gt 4) { $list += '  ' + ($TkStr.help_more -f ($global:Abbreviations.Count - 4)) }
        $rows += , ('abbr', $list, $TkStr.help_abbr_all)
    }
    if ($rows) { @{ Key = 'my'; Title = $TkStr.help_user; Rows = $rows } }
}

function global:Get-TkAllSections { @($TkStr.sections) + @(Get-TkUserSection) }

function global:Show-TkHelp($Sections) {
    if (-not $Sections) { $Sections = Get-TkAllSections }
    Write-Host ''
    Write-Host ("  {0}{1}{2}{3}  {4}{5}: {6}{7}" -f $TK.title, $TK.B, $TkStr.help_title, $TK.R, $TK.dim, $TkStr.help_theme, $global:ThemeName, $TK.R)
    Write-Host ("  {0}{1}{2}" -f $TK.dim, $TkStr.help_hint, $TK.R)
    foreach ($s in $Sections) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}{3}  {4}help {5}{6}" -f $TK.title, $TK.B, $s.Title, $TK.R, $TK.dim, $s.Key, $TK.R)
        foreach ($r in $s.Rows) { Write-TkRow @r }
    }
    Write-Host ''
}

function global:help {
    if (-not $args) { Show-TkHelp; return }
    $query = "$args"
    $all = Get-TkAllSections
    $section = $all | Where-Object { $_.Key -eq $query -or $_.Title -eq $query }
    if ($section) { Show-TkHelp $section; return }

    $hits = @(foreach ($s in $all) {
        foreach ($r in $s.Rows) { if (($r -join ' ').IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) { , $r } }
    })
    $isCmdlet = Get-Command $query -CommandType Cmdlet, Alias -ErrorAction SilentlyContinue
    if ($hits -and $args.Count -eq 1 -and -not $isCmdlet) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}: {3}{4}" -f $TK.title, $TK.B, $TkStr.help_found, $query, $TK.R)
        foreach ($r in $hits) { Write-TkRow @r }
        Write-Host ''
        return
    }
    Get-Help @args
}

function global:Invoke-HelpPicker {
    $lines = foreach ($s in Get-TkAllSections) {
        foreach ($r in $s.Rows) {
            $cmd = $r[0]; $desc = $r[1]
            $shown = '{0,-28} {1}' -f $cmd, $desc
            if ($r.Count -gt 2 -and $r[2]) { $shown += "   $($r[2])" }
            $insert = if ($cmd -match $TkStr.no_insert) { '' } else { ($cmd -split ' / | · | \[| <')[0].Trim() }
            "{0,-12}  {1}`t{2}" -f $s.Title, $shown, $insert
        }
    }
    $pick = $lines | fzf --height=60% --prompt='help ❯ ' --header=$TkStr.picker_header --delimiter="`t" --with-nth=1 --tabstop=4
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($pick) {
        $insert = ($pick -split "`t")[1]
        if ($insert) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($insert) }
    }
}

# ── ssh ──────────────────────────────────────────────────────────────────────
function global:Get-SshHost {
    $config = Join-Path $HOME '.ssh\config'
    if (-not (Test-Path $config)) { return }
    $hosts = [ordered]@{}
    $current = @()
    foreach ($raw in Get-Content $config) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $key, $value = $line -split '\s*=\s*|\s+', 2
        $field = @{ hostname = 'HostName'; user = 'User'; port = 'Port'; identityfile = 'IdentityFile' }[$key.ToLower()]
        if ($key -eq 'Host') {
            $current = foreach ($name in $value -split '\s+') {
                if ($name -match '[*?!]') { continue }
                if ($hosts.Contains($name)) { $hosts[$name].Duplicate = $true }
                else { $hosts[$name] = [pscustomobject]@{ Name = $name; HostName = ''; User = ''; Port = ''; IdentityFile = ''; Duplicate = $false } }
                $hosts[$name]
            }
        } elseif ($key -eq 'Match') {
            $current = @()
        } elseif ($field) {
            # ssh semantics: the first value wins
            foreach ($h in $current) { if (-not $h.$field) { $h.$field = $value } }
        }
    }
    foreach ($h in $hosts.Values) {
        if (-not $h.HostName) { $h.HostName = $h.Name }
        if (-not $h.Port) { $h.Port = '22' }
        if ($h.IdentityFile) { $h.IdentityFile = Split-Path $h.IdentityFile -Leaf }
        $h
    }
}

function global:Select-SshHost([string]$Query, [string]$Header) {
    $hosts = @(Get-SshHost)
    if (-not $hosts) { Write-Host "  $($TkStr.ssh_empty)"; return }
    $width = ($hosts.Name | Measure-Object Length -Maximum).Maximum
    $pick = $hosts | ForEach-Object { '{0}  {1}@{2}' -f $_.Name.PadRight($width), $_.User, $_.HostName } |
        fzf --query=$Query --select-1 --height=14 --header=$Header
    if ($pick) { ($pick -split '\s+')[0] }
}

function global:jump([string]$Query) {
    $name = Select-SshHost $Query $TkStr.jump_header
    if ($name) {
        Write-Host ("  {0}→ ssh {1}{2}" -f $TK.dim, $name, $TK.R)
        ssh $name
    }
}

Register-ArgumentCompleter -Native -CommandName ssh, scp, sftp -ScriptBlock {
    param($wordToComplete, $commandAst)
    $suffix = if ($commandAst.CommandElements[0].Value -eq 'ssh') { '' } else { ':' }
    Get-SshHost | Where-Object Name -like "$wordToComplete*" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_.Name + $suffix, $_.Name, 'ParameterValue', "$($_.User)@$($_.HostName)")
    }
}

# ── srv ──────────────────────────────────────────────────────────────────────
function global:srv {
    param(
        [Parameter(Position = 0)][ValidateSet('install', 'remove', 'help')][string]$Action = 'help',
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [ArgumentCompleter({ param($c, $p, $word) (Get-SshHost).Name | Where-Object { $_ -like "$word*" } })]
        [string[]]$Hosts,
        [string]$Env,
        [ValidateSet('', 'ru', 'en')][string]$Lang = ''
    )
    $dir = Join-Path $global:ProfileDir 'server'
    if ($Action -eq 'help') { Show-SrvHelp $dir; return }
    foreach ($f in 'bashrc.local', 'inputrc', 'install.sh') {
        if (-not (Test-Path (Join-Path $dir $f))) { Write-Host "  $($TK.err)$($TkStr.srv_missing -f "$dir\$f")$($TK.R)"; return }
    }
    if ($Env -and $Env -notmatch '^[A-Za-z0-9_-]{1,20}$') { Write-Host "  $($TK.err)$($TkStr.srv_env)$($TK.R)"; return }
    if (-not $Hosts) {
        $picked = Select-SshHost '' ($TkStr.srv_pick -f $Action)
        if (-not $picked) { return }
        $Hosts = @($picked)
    }
    if (-not $Lang) { $Lang = $global:LangName }

    $read = { param($path) [IO.File]::ReadAllText($path) -replace "`r`n", "`n" }
    $b64 = { param($text) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)) }
    $custom = foreach ($f in Get-ChildItem (Join-Path $dir 'custom') -File -Filter *.sh -ErrorAction SilentlyContinue) {
        "__put '.bashrc.d/$($f.Name)' '$(& $b64 (& $read $f.FullName))'"
    }
    $script = (& $read (Join-Path $dir 'install.sh')).Replace('__ACTION__', $Action).Replace('__ENV__', $Env).Replace('__LANG__', $Lang)
    $script = $script.Replace('__BASHRC_B64__', (& $b64 (& $read (Join-Path $dir 'bashrc.local'))))
    $script = $script.Replace('__INPUTRC_B64__', (& $b64 (& $read (Join-Path $dir 'inputrc'))))
    $script = $script.Replace('__CUSTOM_FILES__', ($custom -join "`n"))
    # the trailing newline PowerShell adds on pipe lands inside the final "# end" comment
    $script = $script.TrimEnd()

    foreach ($h in $Hosts) {
        Write-TkTitle "srv $Action → $h" ''
        $script | ssh $h 'bash -s'
        if ($LASTEXITCODE -eq 0 -and $Action -eq 'remove') { Write-Host "  $($TK.ok)$($TkStr.srv_removed)$($TK.R) $($TK.dim)$($TkStr.srv_restore -f $h)$($TK.R)" }
        elseif ($LASTEXITCODE -eq 0) { Write-Host "  $($TK.ok)$($TkStr.srv_done)$($TK.R) $($TK.dim)$($TkStr.srv_relogin -f $h)$($TK.R)" }
        else { Write-Host "  $($TK.err)$($TkStr.srv_error -f $LASTEXITCODE)$($TK.R)" }
        Write-Host ''
    }
}

function global:Show-SrvHelp([string]$Dir) {
    Write-TkTitle $TkStr.srv_title ($TkStr.srv_templates -f $Dir)
    foreach ($r in $TkStr.srv_rows) { Write-TkRow @r }
    Write-Host ''
    Write-Host "  $($TK.title)$($TkStr.srv_gets)$($TK.R)"
    foreach ($line in $TkStr.srv_gets_rows) { Write-Host "    $line" }
    Write-Host ''
    Write-Host "  $($TK.title)$($TkStr.srv_custom)$($TK.R)"
    foreach ($line in $TkStr.srv_custom_rows) { Write-Host "    $($line -f $Dir)" }
    Write-Host ''
    Write-Host "  $($TK.dim)$($TkStr.srv_note)$($TK.R)"
    Write-Host ''
}

# ── my ───────────────────────────────────────────────────────────────────────
function global:my {
    param(
        [Parameter(Position = 0)][ArgumentCompleter({
            param($c, $p, $word) $TkStr.my_topics.get_Keys() | Where-Object { $_ -like "$word*" }
        })][string]$Topic,
        [Parameter(Position = 1)][string]$Filter
    )
    switch ($Topic) {
        'sys'    { Show-MySys }
        'ssh'    { Show-MySsh $Filter }
        'ports'  { Show-MyPorts $Filter }
        'ip'     { Show-MyIp $Filter }
        'k8s'    { Show-MyK8s }
        'docker' { Show-MyDocker }
        'tools'  { Show-MyTools }
        'path'   { Show-MyPath }
        'git'    { Show-MyGit }
        'cmds'   { Show-MyCommands }
        'config' { Show-MyConfig }
        'keys'   { Show-TkHelp ($TkStr.sections | Where-Object { $_.Key -in 'keys', 'input' }) }
        default {
            Write-TkTitle $TkStr.my_title $TkStr.my_hint
            # get_Keys(): the dictionary has a 'keys' entry, so .Keys would return it
            foreach ($k in $TkStr.my_topics.get_Keys()) { Write-TkRow "my $k" $TkStr.my_topics[$k] }
            Write-Host ''
        }
    }
}

function global:Show-MySys {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $up = (Get-Date) - $os.LastBootUpTime
    Write-TkTitle $env:COMPUTERNAME (($TkStr.sys_uptime -f [int]$up.TotalDays, $up.Hours, $up.Minutes) + ' · ' + $os.Caption.Replace('Microsoft ', ''))
    $cpuName = ($cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)|CPU|Processor', '').Trim()
    $row = { param($label, $percent, $note) Write-Host ("  {0}{1}{2}  {3}  {4}{5}{6}" -f $TK.dim, $label.PadRight(10), $TK.R, (Get-TkBar $percent), $TK.dim, $note, $TK.R) }
    & $row $TkStr.sys_cpu $cpu.LoadPercentage "$cpuName · $($TkStr.sys_cores): $([Environment]::ProcessorCount)"
    $memUsed = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
    $memTotal = $os.TotalVisibleMemorySize * 1KB
    & $row $TkStr.sys_mem ($memUsed / $memTotal * 100) "$(Format-TkSize $memUsed) $($TkStr.of) $(Format-TkSize $memTotal)"
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Sort-Object DeviceID) {
        if (-not $d.Size) { continue }
        $used = $d.Size - $d.FreeSpace
        & $row "$($TkStr.sys_disk) $($d.DeviceID)" ($used / $d.Size * 100) "$(Format-TkSize $used) $($TkStr.of) $(Format-TkSize $d.Size)$(if ($d.VolumeName) { " · $($d.VolumeName)" })"
    }

    Write-Host ''
    Write-Host ("  {0}{1}{2}" -f $TK.title, $TkStr.sys_bymem, $TK.R)
    $top = Get-Process | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Memory = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum; Count = $_.Count }
    } | Sort-Object Memory -Descending | Select-Object -First 6
    foreach ($t in $top) {
        Write-Host ("  {0}{1,-26}{2} {3,9}{4}{5}" -f $TK.cmd, $t.Name, $TK.R, (Format-TkSize $t.Memory), $TK.dim, $(if ($t.Count -gt 1) { "  ×$($t.Count)" }), $TK.R)
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}" -f $TK.title, $TkStr.sys_containers, $TK.R)
        $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}')
        if ($null -eq $rows) { Write-Host "  $($TK.dim)$($TkStr.docker_down)$($TK.R)" }
        elseif (-not $rows) { Write-Host "  $($TK.dim)$($TkStr.docker_none)$($TK.R)" }
        foreach ($r in $rows) {
            $name, $state = $r -split "`t"
            $dot = if ($state -match 'unhealthy|Restarting') { $TK.err } elseif ($state -like 'Up*') { $TK.ok } elseif ($state -like 'Exited (0)*') { $TK.dim } else { $TK.err }
            Write-Host ("  {0}●{1} {2,-30} {3}{4}{5}" -f $dot, $TK.R, $name, $TK.dim, $state, $TK.R)
        }
    }
    Write-Host ''
}

function global:Show-MyK8s {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Host "  $($TK.dim)$($TkStr.k8s_missing)$($TK.R)"; return }
    $rows = Invoke-WithTimeout kubectl @('config', 'get-contexts', '--no-headers') 5000
    Write-TkTitle 'Kubernetes' $TkStr.k8s_hint
    if (-not $rows) { Write-Host "  $($TK.dim)$($TkStr.k8s_none)$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $f = $r -split '\s+'
        $cur = $f[0] -eq '*'
        if ($cur) { $f = $f[1..($f.Count - 1)] }
        [pscustomobject]@{ Mark = $(if ($cur) { '●' } else { ' ' }); Name = $f[0]; Cluster = $f[1]; Namespace = $(if ($f.Count -gt 3) { $f[3] } else { 'default' }) }
    }
    Write-TkTable $list @(
        @{ N = ' '; P = 'Mark'; C = 'ok' }
        @{ N = $TkStr.col_context; P = 'Name'; C = { param($r) if ($r.Mark -eq '●') { 'cmd' } else { 'text' } } }
        @{ N = $TkStr.col_cluster; P = 'Cluster'; C = 'dim' }
        @{ N = 'Namespace'; P = 'Namespace'; C = 'accent' }
    )
    Write-Host ''
}

function global:Show-MyDocker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Host "  $($TK.dim)$($TkStr.docker_missing)$($TK.R)"; return }
    $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}\t{{.Ports}}')
    Write-TkTitle 'Docker' $TkStr.docker_hint
    if ($null -eq $rows) { Write-Host "  $($TK.dim)$($TkStr.docker_down)$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $name, $state, $ports = $r -split "`t"
        $ports = ($ports -replace '0\.0\.0\.0:|\[::\]:|/tcp', '' -split ', ' | Sort-Object -Unique) -join ' '
        [pscustomobject]@{ Dot = '●'; Name = $name; State = $state; Ports = $ports }
    }
    if (-not $list) { Write-Host "  $($TK.dim)$($TkStr.docker_none)$($TK.R)" }
    else {
        Write-TkTable $list @(
            @{ N = ' '; P = 'Dot'; C = { param($r) if ($r.State -match 'unhealthy|Restarting') { 'err' } elseif ($r.State -like 'Up*') { 'ok' } elseif ($r.State -like 'Exited (0)*') { 'dim' } else { 'err' } } }
            @{ N = $TkStr.col_container; P = 'Name'; C = 'cmd' }
            @{ N = $TkStr.col_status; P = 'State'; C = 'dim' }
            @{ N = $TkStr.col_ports; P = 'Ports'; C = 'accent' }
        )
    }
    $projects = Invoke-WithTimeout docker @('compose', 'ls', '-a', '--format', '{{.Name}}\t{{.Status}}\t{{.ConfigFiles}}') 5000
    if ($projects) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}" -f $TK.title, $TkStr.docker_projects, $TK.R)
        foreach ($p in $projects) {
            $name, $state, $files = $p -split "`t"
            Write-Host ("  {0}{1,-20}{2} {3,-24} {4}{5}{6}" -f $TK.cmd, $name, $TK.R, $state, $TK.dim, (Split-Path ($files -split ',')[0]), $TK.R)
        }
    }
    Write-Host ''
}

function global:Show-MySsh([string]$Filter) {
    $hosts = @(Get-SshHost | Where-Object { -not $Filter -or "$($_.Name) $($_.HostName) $($_.User)" -like "*$Filter*" })
    Write-TkTitle $TkStr.ssh_title $TkStr.ssh_hint
    if (-not $hosts) { Write-Host "  $($TK.dim)$($TkStr.nothing_found)$($TK.R)"; Write-Host ''; return }
    Write-TkTable $hosts @(
        @{ N = $TkStr.col_name; P = 'Name'; C = 'cmd' }
        @{ N = $TkStr.col_address; P = 'HostName'; C = 'text' }
        @{ N = $TkStr.col_user; P = 'User'; C = { param($r) if ($r.User -eq 'root') { 'err' } else { 'ok' } } }
        @{ N = $TkStr.col_port; P = 'Port'; C = 'dim' }
        @{ N = $TkStr.col_key; P = 'IdentityFile'; C = 'dim' }
    )
    foreach ($d in $hosts | Where-Object Duplicate) { Write-Host ("  {0}{1}{2}" -f $TK.warn, ($TkStr.ssh_dup -f $d.Name, $d.User), $TK.R) }
    Write-Host ''
}

function global:Show-MyIp([string]$Mode) {
    $rows = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Sort-Object InterfaceMetric |
        ForEach-Object { [pscustomobject]@{ Interface = $_.InterfaceAlias; Address = "$($_.IPAddress)/$($_.PrefixLength)" } }
    Write-TkTitle $TkStr.ip_title $TkStr.ip_hint
    Write-TkTable $rows @(@{ N = $TkStr.col_iface; P = 'Interface'; C = 'text' }, @{ N = $TkStr.col_address; P = 'Address'; C = 'cmd' })
    $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
    if ($gw) { Write-Host ("  {0}{1}{2}  {3} {4}({5}){6}" -f $TK.dim, $TkStr.ip_gateway, $TK.R, $gw.NextHop, $TK.dim, $gw.InterfaceAlias, $TK.R) }
    if ($Mode -eq 'public') {
        try { $ip = Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5; Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $TK.dim, $TkStr.ip_public, $TK.R, $TK.accent, $ip, $TK.R) }
        catch { Write-Host "  $($TK.err)$($TkStr.ip_public_fail)$($TK.R)" }
    }
    Write-Host ''
}

function global:Show-MyPorts([string]$Filter) {
    $names = @{}; Get-Process | ForEach-Object { $names[$_.Id] = $_.ProcessName }
    $all = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Group-Object LocalPort | ForEach-Object {
        $c = $_.Group[0]
        [pscustomobject]@{
            Port = [int]$c.LocalPort
            Address = ($_.Group.LocalAddress | Sort-Object -Unique) -join ', '
            Process = $names[[int]$c.OwningProcess]
            PID = $c.OwningProcess
        }
    } | Sort-Object Port
    $rows = if ($Filter -eq 'all') { $all }
            elseif ($Filter) { $all | Where-Object { "$($_.Port)" -eq $Filter -or $_.Process -like "*$Filter*" } }
            else { $all | Where-Object Port -lt 49152 }
    Write-TkTitle $TkStr.ports_title $TkStr.ports_hint
    Write-TkTable $rows @(
        @{ N = $TkStr.col_port; P = 'Port'; C = 'accent' }
        @{ N = $TkStr.col_process; P = 'Process'; C = 'cmd' }
        @{ N = 'PID'; P = 'PID'; C = 'dim' }
        @{ N = $TkStr.col_address; P = 'Address'; C = 'dim' }
    )
    Write-Host ''
}

function global:Show-MyPath {
    $seen = @{}
    $rows = foreach ($p in $env:PATH -split ';' | Where-Object { $_ }) {
        $state = if ($seen.ContainsKey($p.TrimEnd('\'))) { $TkStr.path_dup } elseif (-not (Test-Path $p)) { $TkStr.path_missing } else { '' }
        $seen[$p.TrimEnd('\')] = $true
        [pscustomobject]@{ Path = $p; State = $state }
    }
    Write-TkTitle $TkStr.path_title $TkStr.path_hint
    Write-TkTable $rows @(
        @{ N = $TkStr.col_folder; P = 'Path'; C = { param($r) if ($r.State) { 'dim' } else { 'text' } } }
        @{ N = ''; P = 'State'; C = { param($r) if ($r.State -eq $TkStr.path_dup) { 'warn' } else { 'err' } } }
    )
    Write-Host ''
}

function global:Show-MyTools {
    $specs = [ordered]@{
        pwsh = '--version'; git = '--version'; gh = '--version'; lazygit = '--version'; node = '--version'; python = '--version'
        uv = '--version'; docker = '--version'; kubectl = 'version --client'; helm = 'version --short'; kind = 'version'
        minikube = 'version --short'; code = '--version'; 'oh-my-posh' = 'version'; fzf = '--version'; zoxide = '--version'
        eza = '--version'; bat = '--version'; rg = '--version'; fd = '--version'; delta = '--version'; tldr = '--version'
    }
    $rows = $specs.GetEnumerator() | ForEach-Object -ThrottleLimit 10 -Parallel {
        $name, $argLine = $_.Key, $_.Value
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { return }
        $out = (& $name ($argLine -split ' ') 2>&1 | Select-Object -First 3) -join ' '
        [pscustomobject]@{ Name = $name; Version = ([regex]::Match($out, '\d+\.\d+(\.\d+)?')).Value; Path = $cmd.Source }
    } | Sort-Object Name
    Write-TkTitle $TkStr.tools_title $TkStr.tools_hint
    Write-TkTable $rows @(
        @{ N = $TkStr.col_program; P = 'Name'; C = 'cmd' }
        @{ N = $TkStr.col_version; P = 'Version'; C = 'ok' }
        @{ N = $TkStr.col_where; P = 'Path'; C = 'dim' }
    )
    Write-Host ''
}

function global:Show-MyGit {
    Write-TkTitle 'Git' ''
    Write-TkRow $TkStr.git_name (git config --global user.name)
    Write-TkRow $TkStr.git_email (git config --global user.email)
    $root = git rev-parse --show-toplevel 2>$null
    if ($root) {
        Write-TkRow $TkStr.git_repo $root
        Write-TkRow $TkStr.git_branch (git branch --show-current)
        foreach ($r in git remote -v | Where-Object { $_ -like '*(fetch)' }) {
            $name, $url = $r -split '\s+'
            Write-TkRow "remote $name" $url
        }
    } else {
        Write-Host "    $($TK.dim)$($TkStr.git_none)$($TK.R)"
    }
    $aliases = git config --global --get-regexp '^alias\.' 2>$null
    foreach ($a in $aliases) { $k, $v = $a -split ' ', 2; Write-TkRow ('git ' + $k.Substring(6)) $v }
    Write-Host ''
}

function global:Show-MyCommands {
    Write-TkTitle $TkStr.cmds_title ($TkStr.cmds_hint -f $global:ProfileDir)
    if ($global:UserCommands) {
        Write-Host ("  {0}bin\{1}" -f $TK.title, $TK.R)
        foreach ($c in $global:UserCommands) { Write-TkRow $c.Name $c.Help "$($c.File) · $($c.Runner)" }
    } else {
        Write-Host ("  {0}{1}{2}" -f $TK.dim, $TkStr.cmds_empty, $TK.R)
    }
    if ($global:CustomFunctions) {
        Write-Host ''
        Write-Host ("  {0}custom.ps1{1}" -f $TK.title, $TK.R)
        foreach ($f in $global:CustomFunctions) { Write-TkRow $f ((Get-Command $f).Definition.Trim() -split "`n")[0].Trim() }
    }
    if ($global:Abbreviations.Count) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}  {3}{4}{5}" -f $TK.title, $TkStr.cmds_abbr, $TK.R, $TK.dim, $TkStr.cmds_abbr_hint, $TK.R)
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
    }
    Write-Host ''
}

# ── history ──────────────────────────────────────────────────────────────────
if (Test-Path Alias:h) { Remove-Item Alias:h -Force }
function global:h {
    param([string]$Filter, [int]$Count = 50, [int]$PageSize = 10)
    $path = (Get-PSReadLineOption).HistorySavePath
    if (-not (Test-Path $path)) { return }

    # multi-line entries are stored as lines ending with a backtick
    $entries = [System.Collections.Generic.List[string]]::new()
    $buffer = ''
    foreach ($line in [IO.File]::ReadLines($path)) {
        if ($line.EndsWith('`')) { $buffer += $line.Substring(0, $line.Length - 1) + "`n"; continue }
        $entries.Add($buffer + $line); $buffer = ''
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $list = [System.Collections.Generic.List[string]]::new()
    for ($i = $entries.Count - 1; $i -ge 0 -and $list.Count -lt $Count; $i--) {
        $e = $entries[$i].Trim()
        if (-not $e -or $e -match '^h(\s|$)') { continue }
        if ($Filter -and $e.IndexOf($Filter, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        if ($seen.Add($e)) { $list.Add($e) }
    }

    Write-TkTitle $(if ($Filter) { $TkStr.hist_filtered -f $Filter } else { $TkStr.hist_title }) $TkStr.hist_hint
    $paging = -not [Console]::IsInputRedirected
    for ($i = 0; $i -lt $list.Count; $i++) {
        $lines = $list[$i] -split "`n"
        $text = $lines[0]
        if ($Filter) { $text = $text -ireplace [regex]::Escape($Filter), ($TK.accent + '$0' + $TK.R) }
        if ($lines.Count -gt 1) { $text += "  $($TK.dim)$($TkStr.hist_more -f ($lines.Count - 1))$($TK.R)" }
        Write-Host ("  {0}{1,3}{2}  {3}" -f $TK.dim, ($i + 1), $TK.R, $text)

        if ($paging -and ($i + 1) % $PageSize -eq 0 -and $i + 1 -lt $list.Count) {
            Write-Host -NoNewline ("  {0}{1}{2}" -f $TK.dim, ($TkStr.hist_page -f ($i + 1), $list.Count), $TK.R)
            $key = [Console]::ReadKey($true).Key
            Write-Host -NoNewline "`r$([char]27)[2K"
            if ($key -in 'Q', 'Escape') { break }
        }
    }
    if (-not $list.Count) { Write-Host "  $($TK.dim)$($TkStr.nothing_found)$($TK.R)" }
    Write-Host ''
}

$global:TkTemplates = @{
    '.ps1' = "# help: {desc}`nparam([Parameter(ValueFromRemainingArguments)][string[]]`$Args)`n`n`"hello from {name}: `$Args`"`n"
    '.py'  = "# help: {desc}`n# /// script`n# dependencies = []`n# ///`nimport sys`n`n`ndef main(args: list[str]) -> None:`n    print(`"hello from {name}`", args)`n`n`nif __name__ == `"__main__`":`n    main(sys.argv[1:])`n"
    '.js'  = "// help: {desc}`nconsole.log('hello from {name}', process.argv.slice(2));`n"
    '.ts'  = "// help: {desc}`nconsole.log('hello from {name}', process.argv.slice(2));`n"
    '.sh'  = "#!/usr/bin/env bash`n# help: {desc}`necho `"hello from {name}: `$*`"`n"
    '.go'  = "// help: {desc}`npackage main`n`nimport (`n`t`"fmt`"`n`t`"os`"`n)`n`nfunc main() {`n`tfmt.Println(`"hello from {name}`", os.Args[1:])`n}`n"
    '.rs'  = "// help: {desc}`nfn main() {`n    let args: Vec<String> = std::env::args().skip(1).collect();`n    println!(`"hello from {name} {:?}`", args);`n}`n"
    '.clj' = ";; help: {desc}`n(println `"hello from {name}`" *command-line-args*)`n"
    '.rb'  = "# help: {desc}`nputs `"hello from {name}: #{ARGV.join(' ')}`"`n"
    '.lua' = "-- help: {desc}`nprint('hello from {name}', table.concat(arg, ' '))`n"
    '.php' = "<?php`n// help: {desc}`necho 'hello from {name}: ', implode(' ', array_slice(`$argv, 1)), PHP_EOL;`n"
}

function global:new {
    param([Parameter(Position = 0)][string]$FileName, [Parameter(Position = 1)][string]$Description)
    if (-not $Description) { $Description = $TkStr.new_default }
    $bin = Join-Path $global:ProfileDir 'bin'
    if (-not $FileName) {
        Write-TkTitle $TkStr.new_title ($TkStr.new_hint -f $bin)
        foreach ($ext in $global:ScriptRunners.Keys) {
            $runner = Get-ScriptRunner $ext
            Write-TkRow "new name$ext" $(if ($runner) { $TkStr.new_run -f $runner } else { $TkStr.new_need -f ($global:ScriptRunners[$ext] -join ' / ') }) $(if ($runner) { '' } else { $TkStr.new_missing })
        }
        Write-Host ''
        return
    }
    $ext = [IO.Path]::GetExtension($FileName).ToLower()
    $name = [IO.Path]::GetFileNameWithoutExtension($FileName)
    if (-not $TkTemplates.ContainsKey($ext)) { Write-Host "  $($TK.err)$($TkStr.new_bad_ext -f $ext)$($TK.R)"; return }
    if ($name -notmatch '^[A-Za-z_][\w-]*$') { Write-Host "  $($TK.err)$($TkStr.new_bad_name)$($TK.R)"; return }
    $taken = Get-Command $name -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notlike "$bin\*" -and $_.ScriptBlock -notlike '*UserCommand*' } | Select-Object -First 1
    if ($taken) { Write-Host "  $($TK.err)$($TkStr.new_taken -f $name, $taken.CommandType, $taken.Source)$($TK.R)"; return }
    New-Item -ItemType Directory -Force $bin | Out-Null
    $path = Join-Path $bin "$name$ext"
    if (-not (Test-Path $path)) {
        $text = $TkTemplates[$ext].Replace('{desc}', $Description).Replace('{name}', $name)
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
        Write-Host ("  {0}✓ {1}{2}" -f $TK.ok, $path, $TK.R)
    }
    Register-BinCommands $bin
    $runner = Get-ScriptRunner $ext
    if ($runner) { Write-Host ("  {0}{1}{2}{3}{4} {5}{6}  {7}{8}{9}" -f $TK.dim, $TkStr.new_ready, $TK.cmd, $name, $TK.R, $TK.dim, $TkStr.new_args, $TK.dim, ($TkStr.new_via -f $runner), $TK.R) }
    else { Write-Host ("  {0}{1}{2}" -f $TK.warn, ($TkStr.new_norunner -f ($global:ScriptRunners[$ext] -join ' / ')), $TK.R) }
    if (Get-Command code -ErrorAction SilentlyContinue) { code $path }
}

# ── theme / lang ─────────────────────────────────────────────────────────────
function global:Get-TerminalSettingsPaths {
    $paths = foreach ($pkg in 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') {
        Join-Path $env:LOCALAPPDATA "Packages\$pkg\LocalState\settings.json"
    }
    $paths += Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    $paths | Where-Object { Test-Path $_ }
}

function global:theme {
    param([Parameter(Position = 0)][ArgumentCompleter({ param($c, $p, $word) $Themes.Keys | Where-Object { $_ -like "$word*" } })][string]$Name)
    if (-not $Name) {
        Write-TkTitle $TkStr.theme_title $TkStr.theme_hint
        foreach ($f in $Themes.Keys) {
            $p = $Themes[$f]
            $swatch = ($p.red, $p.peach, $p.yellow, $p.green, $p.teal, $p.blue, $p.mauve | ForEach-Object { (_tkRgb $_) + '●' }) -join ' '
            $mark = if ($f -eq $global:ThemeName) { $TK.ok + '● ' } else { '  ' }
            $kind = if ($p.dark) { $TkStr.theme_dark } else { $TkStr.theme_light }
            Write-Host ("  {0}{1}{2,-11}{3} {4}{5}  {6}{7,-20} {8}{9}{10}" -f $mark, $TK.cmd, $f, $TK.R, $swatch, $TK.R, $TK.text, $p.title, $TK.dim, $kind, $TK.R)
        }
        Write-Host ''
        return
    }
    $Name = $Name.ToLower()
    if (-not $Themes.Contains($Name)) { Write-Host "  $($TK.err)$($TkStr.theme_only -f ($Themes.Keys -join ', '))$($TK.R)"; return }
    New-Item -ItemType Directory -Force (Split-Path $ThemeFile) | Out-Null
    [IO.File]::WriteAllText($ThemeFile, "$Name`n")
    $global:ThemeName = $Name
    $global:Palette = $Themes[$Name]
    $env:TERMINAL_THEME = $Name
    Set-TerminalPalette
    $title = $Themes[$Name].title
    $known = ($Themes.Values.title + 'Catppuccin [A-Za-z]+' | ForEach-Object { if ($_ -like 'Catppuccin [[]*') { $_ } else { [regex]::Escape($_) } }) -join '|'
    foreach ($path in Get-TerminalSettingsPaths) {
        $raw = [IO.File]::ReadAllText($path)
        $new = $raw -replace "(`"colorScheme`"\s*:\s*)`"($known)`"", "`$1`"$title`"" -replace "(`"theme`"\s*:\s*)`"($known)`"", "`$1`"$title`""
        if ($new -ne $raw) { [IO.File]::WriteAllText($path, $new, [Text.UTF8Encoding]::new($false)) }
    }
    $omp = "$HOME\.config\ohmyposh\soft.omp.json"
    if (Test-Path $omp) { [IO.File]::WriteAllText($omp, (Set-OmpPalettes ([IO.File]::ReadAllText($omp)) $Name), [Text.UTF8Encoding]::new($false)) }
    Write-Host ("  {0}✓ {1}{2}  {3}{4}{5}" -f $TK.ok, $title, $TK.R, $TK.dim, $TkStr.theme_done, $TK.R)
}

function global:lang {
    param([Parameter(Position = 0)][ValidateSet('', 'ru', 'en')][string]$Name = '')
    if (-not $Name) {
        Write-TkTitle $TkStr.lang_title $TkStr.lang_hint
        foreach ($l in 'ru', 'en') {
            $mark = if ($l -eq $global:LangName) { $TK.ok + '● ' } else { '  ' }
            Write-Host ("  {0}{1}{2,-6}{3} {4}{5}{6}" -f $mark, $TK.cmd, $l, $TK.R, $TK.dim, $TkStr["lang_$l"], $TK.R)
        }
        Write-Host ''
        return
    }
    New-Item -ItemType Directory -Force (Split-Path $LangFile) | Out-Null
    [IO.File]::WriteAllText($LangFile, "$Name`n")
    $global:LangName = $Name
    $global:TkStr = $Strings[$Name]
    Write-Host ("  {0}✓ {1}{2}" -f $TK.ok, ($TkStr.lang_done -f $TkStr["lang_$Name"]), $TK.R)
}

function global:ep { code $global:ProfileDir }

# ── fzf helpers ──────────────────────────────────────────────────────────────
# PowerShell piping into fzf throws "pipe is being closed" when fzf exits before the producer is done;
# short lists go through Invoke-Fzf, long ones (fd, rg) are started by fzf itself via FZF_DEFAULT_COMMAND.
function global:Invoke-Fzf([string[]]$Lines, [string[]]$Arguments) {
    try { @($Lines | fzf @Arguments) } catch { if ("$_" -notmatch 'pipe|канал') { throw } }
}

function global:Invoke-FzfCommand([string]$Command, [string[]]$Arguments) {
    $saved = $env:FZF_DEFAULT_COMMAND
    $env:FZF_DEFAULT_COMMAND = $Command
    try { @(fzf @Arguments) } finally { $env:FZF_DEFAULT_COMMAND = $saved }
}

# Preview script for fzf: folders through eza, files through bat. cmd runs it with UTF-8 so Cyrillic paths work.
function global:Get-TsPreview {
    $p = "$HOME\.cache\terminal-setup\preview.cmd"
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
        $lines = '@echo off', 'chcp 65001 >nul', 'if exist "%~1\" (', '  eza --icons=always --color=always --group-directories-first -1 "%~1"', ') else (', '  bat --color=always --style=numbers,header-filename --line-range :300 "%~1"', ')'
        [IO.File]::WriteAllLines($p, $lines, [Text.ASCIIEncoding]::new())
    }
    $p
}

function global:Open-TsFile([string]$Path) {
    if (Get-Command code -ErrorAction SilentlyContinue) { code $Path } else { Invoke-Item $Path }
}

# ── nav: folders (and files with Ctrl+E) as a tree on fzf ────────────────────
function global:nav {
    param([string]$Start = (Get-Location).Path)
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { return }
    $dir = (Resolve-Path -LiteralPath $Start).Path
    $preview = "$(Get-TsPreview) {2}"
    $files = $false; $hidden = $false
    while ($true) {
        $parent = Split-Path $dir -Parent
        $entries = @()
        if ($parent) { $entries += "..`t$parent`td" }
        $items = @(Get-ChildItem -LiteralPath $dir -Force:$hidden -ErrorAction SilentlyContinue | Where-Object { $files -or $_.PSIsContainer })
        $entries += $items | Sort-Object { -not $_.PSIsContainer }, Name | ForEach-Object {
            if ($_.PSIsContainer) { "$($_.Name)`t$($_.FullName)`td" } else { "  $($_.Name)`t$($_.FullName)`tf" }
        }
        $mode = @($(if ($files) { 'files' }), $(if ($hidden) { 'hidden' })) -ne $null -join ' '
        $out = Invoke-Fzf $entries @('--expect=right,left,ctrl-f,ctrl-o,ctrl-e,ctrl-h', "--delimiter=`t", '--with-nth=1', '--cycle', '--height=70%',
            "--header=$($TkStr.nav_header)", "--prompt=$($dir.Replace($HOME, '~')) $(if ($mode) { "[$mode] " })❯ ", "--preview=$preview", '--preview-window=right:50%')
        if (-not $out) { return }
        $key = $out[0]
        $fields = if ($out.Count -gt 1) { $out[1] -split "`t" } else { $null }
        $sel = if ($fields) { $fields[1] } else { $null }
        $isDir = $fields -and $fields[2] -eq 'd'
        switch ($key) {
            'left'   { if ($parent) { $dir = $parent } }
            'right'  { if ($sel -and $isDir) { $dir = $sel } }
            'ctrl-e' { $files = -not $files }
            'ctrl-h' { $hidden = -not $hidden }
            'ctrl-o' { Invoke-Item $dir }
            'ctrl-f' {
                $cmd = "fd --hidden --exclude .git --exclude node_modules --type d$(if ($files) { ' --type f' }) . `"$dir`""
                $pick = Invoke-FzfCommand $cmd @('--height=70%', "--prompt=$($TkStr.nav_deep -f $dir.Replace($HOME, '~')) ❯ ", "--preview=$(Get-TsPreview) {}", '--preview-window=right:50%')
                if ($pick) {
                    if (Test-Path -LiteralPath $pick -PathType Container) { Set-Location -LiteralPath $pick } else { Open-TsFile $pick }
                }
                return
            }
            default {
                if (-not $sel) { Set-Location -LiteralPath $dir; return }
                if ($isDir) { Set-Location -LiteralPath $sel } else { Open-TsFile $sel }
                return
            }
        }
    }
}

# ── pv: files with a preview pane; rgi: live grep; pk: kill picker; gbr: branch picker ──
function global:pv {
    param([string]$Dir = '.', [string]$Query = '')
    $dir = (Resolve-Path -LiteralPath $Dir).Path
    $out = Invoke-FzfCommand "fd --type f --hidden --exclude .git --exclude node_modules . `"$dir`"" @('--expect=ctrl-p,ctrl-y', "--query=$Query", '--height=80%',
        "--header=$($TkStr.pv_header)", "--prompt=$($TkStr.pv_prompt) ❯ ", "--preview=$(Get-TsPreview) {}", '--preview-window=right:60%')
    if ($out.Count -lt 2) { return }
    $file = $out[1]
    switch ($out[0]) {
        'ctrl-p' { bat --color=always --style=numbers,header-filename --paging=never $file }
        'ctrl-y' { Set-Clipboard $file; Write-Host "  $($TK.dim)$file$($TK.R)" }
        default  { Open-TsFile $file }
    }
}

function global:rgi {
    param([string]$Text = '', [string]$Dir = '.')
    Push-Location -LiteralPath $Dir
    try {
        $rg = 'rg --line-number --no-heading --color=always --smart-case --hidden --glob !.git --glob !node_modules -- {q} .'
        $initial = if ($Text) { $rg.Replace('{q}', "`"$Text`"") } else { 'cd.' }
        $out = Invoke-FzfCommand $initial @('--disabled', '--ansi', "--query=$Text", '--expect=ctrl-y', '--delimiter=:', '--height=80%',
            "--header=$($TkStr.rgi_header)", '--prompt=rg ❯ ', "--bind=change:reload:$rg",
            '--preview=bat --color=always --style=numbers --highlight-line {2} {1}', '--preview-window=right:55%,+{2}-10')
        if ($out.Count -lt 2) { return }
        $file, $line = ($out[1] -split ':', 3)[0, 1]
        $full = (Resolve-Path -LiteralPath $file).Path
        if ($out[0] -eq 'ctrl-y') { Set-Clipboard "${full}:$line"; Write-Host "  $($TK.dim)${full}:$line$($TK.R)"; return }
        if (Get-Command code -ErrorAction SilentlyContinue) { code -g "${full}:$line" }
        else { bat --color=always --style=numbers --highlight-line $line --paging=never $full }
    } finally { Pop-Location }
}

function global:pk([string]$Name) {
    $procs = Get-Process | Where-Object { -not $Name -or $_.ProcessName -like "*$Name*" } | Sort-Object WorkingSet64 -Descending
    $lines = $procs | ForEach-Object { "{0,-28} {1,10} {2,7}  {3}`t{2}`t{0}" -f $_.ProcessName, (Format-TkSize $_.WorkingSet64), $_.Id, $_.MainWindowTitle }
    $out = Invoke-Fzf $lines @('--multi', '--height=60%', "--header=$($TkStr.pk_header)", '--prompt=kill ❯ ', "--delimiter=`t", '--with-nth=1')
    foreach ($line in $out) {
        $fields = $line -split "`t"
        try { Stop-Process -Id ([int]$fields[1]) -Force -ErrorAction Stop; Write-Host "  $($TK.ok)✓$($TK.R) $($TkStr.pk_done -f $fields[2])" }
        catch { Write-Host "  $($TK.err)$($fields[2]): $($_.Exception.Message)$($TK.R)" }
    }
}

function global:gbr {
    if (-not (git rev-parse --is-inside-work-tree 2>$null)) { Write-Host "  $($TK.dim)$($TkStr.gbr_none)$($TK.R)"; return }
    $branches = @(git branch --all --format='%(refname:short)' | Where-Object { $_ -and $_ -notmatch '/HEAD$' })
    $pick = Invoke-Fzf $branches @('--height=60%', "--header=$($TkStr.gbr_header)", '--prompt=branch ❯ ', '--preview=git log --oneline --color=always -25 {}', '--preview-window=right:55%')
    if ($pick) { git checkout ($pick -replace '^origin/', '') }
}

function global:o { param([string]$Path = '.') Invoke-Item -LiteralPath $Path }

# ── small helpers, same names as on the server ───────────────────────────────
function global:ex([string]$Archive) {
    if (-not (Test-Path -LiteralPath $Archive)) { Write-Host "  $($TK.err)$($TkStr.ex_nofile -f $Archive)$($TK.R)"; return }
    $file = Get-Item -LiteralPath $Archive
    $name = $file.Name -replace '\.(tar\.(gz|xz|bz2|zst)|tgz|txz|zip|7z|tar|rar)$', ''
    $dest = Join-Path $file.DirectoryName $name
    if ($file.Name -notmatch '\.(tar\.(gz|xz|bz2|zst)|tgz|txz|zip|7z|tar)$') { Write-Host "  $($TK.err)$($TkStr.ex_unknown -f $file.Name)$($TK.R)"; return }
    New-Item -ItemType Directory -Force $dest | Out-Null
    tar -xf $file.FullName -C $dest
    if ($LASTEXITCODE -eq 0) { Write-Host "  $($TK.ok)✓ $($TkStr.ex_done -f $dest)$($TK.R)" }
}

function global:bak {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    foreach ($f in $args) {
        if (-not (Test-Path -LiteralPath $f)) { Write-Host "  $($TK.err)$($TkStr.ex_nofile -f $f)$($TK.R)"; continue }
        Copy-Item -LiteralPath $f "$f.bak-$stamp" -Recurse
        Write-Host "  → $f.bak-$stamp"
    }
}

function global:psg([string]$Name) {
    Get-Process | Where-Object { $_.ProcessName -like "*$Name*" } | Sort-Object WorkingSet64 -Descending |
        Select-Object Id, @{ N = 'Memory'; E = { Format-TkSize $_.WorkingSet64 } }, @{ N = 'CPU(s)'; E = { [math]::Round($_.CPU, 1) } }, ProcessName, @{ N = 'Path'; E = { $_.Path } } |
        Format-Table -AutoSize
}

function global:cb {
    $lines = @($input | ForEach-Object { "$_" -replace "`e\[[0-9;]*m", '' })
    if (-not $lines) { Get-Clipboard; return }
    $lines | Set-Clipboard
    Write-Host ("  {0}{1}{2}" -f $TK.dim, ($TkStr.cb_done -f $lines.Count), $TK.R)
}

# ── my config / doctor / update ──────────────────────────────────────────────
function global:Get-ConfigLocations {
    $wt = Get-TerminalSettingsPaths | Select-Object -First 1
    [ordered]@{
        profile     = $global:ProfileDir
        custom      = Join-Path $global:ProfileDir 'custom.ps1'
        bin         = Join-Path $global:ProfileDir 'bin'
        srvcustom   = Join-Path $global:ProfileDir 'server\custom'
        settings    = Join-Path $HOME '.config\terminal-setup'
        omp         = Join-Path $HOME '.config\ohmyposh\soft.omp.json'
        completions = Join-Path $HOME '.cache\pwsh-completions'
        predictor   = Join-Path $HOME '.cache\pwsh-predictor'
        wt          = $(if ($wt) { $wt } else { Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json' })
        vscode      = Join-Path $env:APPDATA 'Code\User\settings.json'
        gitconfig   = Join-Path $HOME '.gitconfig'
        ssh         = Join-Path $HOME '.ssh\config'
    }
}

function global:Show-MyConfig {
    Write-TkTitle $TkStr.config_title $TkStr.config_hint
    $loc = Get-ConfigLocations
    $rows = foreach ($k in $loc.Keys) {
        [pscustomobject]@{ What = $TkStr.config_rows[$k]; Path = $loc[$k].Replace($HOME, '~'); State = $(if (Test-Path -LiteralPath $loc[$k]) { '✓' } else { $TkStr.config_missing }) }
    }
    Write-TkTable $rows @(
        @{ N = ' '; P = 'State'; C = { param($r) if ($r.State -eq '✓') { 'ok' } else { 'dim' } } }
        @{ N = ''; P = 'What'; C = 'text' }
        @{ N = ''; P = 'Path'; C = 'cmd' }
    )
    Write-Host ''
}

function global:doctor {
    Write-TkTitle $TkStr.doctor_title ($TkStr.doctor_hint -f $global:TerminalSetupVersion)
    $state = @{ problems = 0 }
    $check = { param($ok, $label, $detail) if ($ok) { Write-Host "  $($TK.ok)✓$($TK.R) $label $($TK.dim)$detail$($TK.R)" } else { $state.problems++; Write-Host "  $($TK.err)✗$($TK.R) $label $($TK.dim)$detail$($TK.R)" } }

    $tools = 'git', 'oh-my-posh', 'fzf', 'zoxide', 'eza', 'bat', 'rg', 'fd', 'delta', 'lazygit', 'tldr', 'gh'
    $missing = @($tools | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
    & $check (-not $missing) $TkStr.doctor_tools $(if ($missing) { $TkStr.doctor_missing -f ($missing -join ', ') } else { $tools -join ' ' })

    $files = 'Microsoft.PowerShell_profile.ps1', 'palette.ps1', 'lang.ps1', 'toolkit.ps1', 'toolkit-lazy.ps1', 'DeepHistoryPredictor.cs', 'server\bashrc.local', 'server\install.sh', 'server\inputrc'
    $lost = @($files | Where-Object { -not (Test-Path (Join-Path $global:ProfileDir $_)) })
    if (-not (Test-Path "$HOME\.config\ohmyposh\soft.omp.json")) { $lost += 'soft.omp.json' }
    & $check (-not $lost) $TkStr.doctor_files $(if ($lost) { $TkStr.doctor_missing -f ($lost -join ', ') } else { $global:ProfileDir.Replace($HOME, '~') })

    & $check (Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-Regular.ttf") $TkStr.doctor_font 'JetBrainsMono NF'

    $wtOk = $false
    foreach ($path in Get-TerminalSettingsPaths) {
        try { $s = Get-Content $path -Raw | ConvertFrom-Json; $wtOk = ($s.schemes.name -contains $Themes[$global:ThemeName].title) -and ($s.defaultProfile -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}') } catch {}
    }
    & $check $wtOk $TkStr.doctor_wt ''
    & $check ([bool](Get-Module -ListAvailable PSFzf)) $TkStr.doctor_psfzf 'Ctrl+R · Ctrl+T'
    if ($global:isInteractive) {
        $pred = (Get-PSSubsystem -Kind CommandPredictor).Implementations | Where-Object Name -eq 'History'
        & $check ([bool]$pred) $TkStr.doctor_predictor ''
    }

    $customFile = Join-Path $global:ProfileDir 'custom.ps1'
    $customOk = $true; $detail = ''
    if (Test-Path $customFile) {
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($customFile, [ref]$null, [ref]$errors)
        if ($errors) { $customOk = $false; $detail = "$($errors[0].Extent.StartLineNumber): $($errors[0].Message)" }
    }
    & $check $customOk $TkStr.doctor_custom $detail

    $ms = [int](Measure-Command { & (Get-Process -Id $PID).Path -NoLogo -Command 'exit' }).TotalMilliseconds
    & $check ($ms -lt 3500) $TkStr.doctor_startup "$ms ms"

    Write-Host ''
    if ($state.problems) { Write-Host "  $($TK.warn)$($TkStr.doctor_fix)$($TK.R)" } else { Write-Host "  $($TK.ok)$($TkStr.doctor_ok)$($TK.R)" }
    Write-Host ''
}

function global:update {
    Write-Host "  $($TK.dim)$($TkStr.update_start)$($TK.R)"
    try { $installer = Invoke-RestMethod 'https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1' -TimeoutSec 20 }
    catch { Write-Host "  $($TK.err)$($TkStr.update_fail -f $_.Exception.Message)$($TK.R)"; return }
    & ([scriptblock]::Create($installer)) -Lang $global:LangName
    Write-Host "  $($TK.ok)$($TkStr.update_done)$($TK.R)"
}

$global:CompletionGenerators = [ordered]@{
    kubectl  = { kubectl completion powershell }
    helm     = { helm completion powershell }
    kind     = { kind completion powershell }
    k3d      = { k3d completion powershell }
    minikube = { minikube completion powershell }
    docker   = { docker completion powershell }
    gh       = { gh completion -s powershell }
}
# Cobra completion scripts define helper functions without a scope; they are loaded from inside
# a function, so the definitions are rewritten to global: and the file gets a marker line.
function global:Update-Completions {
    $dir = "$HOME\.cache\pwsh-completions"
    New-Item -ItemType Directory -Force $dir | Out-Null
    foreach ($name in $global:CompletionGenerators.Keys) {
        $file = Join-Path $dir "$name.ps1"
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            $text = (& $global:CompletionGenerators[$name] | Out-String)
            $text = [regex]::Replace($text, '(?m)^(\s*)(function|filter)\s+(?!global:)(\S+)', '$1$2 global:$3')
            Set-Content $file ("# global`n" + $text) -Encoding utf8
            Write-Host "  ✓ $name" -ForegroundColor Green
        } elseif (Test-Path $file) {
            Remove-Item $file
        }
    }
}
'@
$EmbeddedFiles['custom'] = @'
# custom.ps1 - yours. setup-terminal.ps1 never overwrites this file. Loaded after toolkit.ps1; check with: reload
#
#   $TerminalSetup.Abbreviations = $false     # g␣ → git␣
#   $TerminalSetup.LayoutFix     = $false     # Russian layout fix on Enter
#   $TerminalSetup.Predictions   = 20         # history suggestions (0 - PSReadLine default 10)
#
#   abbr gcm 'git commit -m "%"'              # % - cursor position
#   abbr -Remove d
#
#   function deploy { ssh prod 'cd app && git pull && docker compose up -d' }   # shows up in help
#
#   Commands in other languages: files in bin\ next to this file (new name.py); "# help: ..." is the caption.
#   $ScriptRunners['.ts'] = @('bun', 'node')  # which runner to use per extension
'@
$EmbeddedFiles['predictor'] = @'
// History suggestions without PSReadLine's built-in cap: the History source is hard-limited
// to 10 entries, plugins get up to 50. Compiled by the profile into ~/.cache/pwsh-predictor.

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Management.Automation.Subsystem;
using System.Management.Automation.Subsystem.Prediction;

public sealed class DeepHistoryPredictor : ICommandPredictor
{
    public static readonly Guid PredictorId = new Guid("6f0c5a4e-2b7d-4c1e-9a3f-1d8e5b7c2a90");

    private readonly string _path;
    private readonly int _max;
    private volatile string[] _entries = Array.Empty<string>();   // новые первыми, без дублей
    private long _loadedLength = -1;
    private int _loading;

    public DeepHistoryPredictor(string historyPath, int maxCount)
    {
        _path = historyPath;
        _max = maxCount;
        Reload();
    }

    public Guid Id => PredictorId;
    public string Name => "History";
    public string Description => "History suggestions without the 10-item limit";
    Dictionary<string, string> ISubsystem.FunctionsToDefine => null;

    public SuggestionPackage GetSuggestion(PredictionClient client, PredictionContext context, CancellationToken cancellationToken)
    {
        string input = context.InputAst.Extent.Text;
        if (string.IsNullOrWhiteSpace(input)) return default;
        RefreshIfChanged();

        var entries = _entries;
        var result = new List<PredictiveSuggestion>();
        // prefix matches first, then substring matches
        foreach (var e in entries)
        {
            if (e.Length > input.Length && e.StartsWith(input, StringComparison.OrdinalIgnoreCase))
            {
                result.Add(new PredictiveSuggestion(e));
                if (result.Count == _max) break;
            }
        }
        if (result.Count < _max)
        {
            foreach (var e in entries)
            {
                if (e.IndexOf(input, 1, StringComparison.OrdinalIgnoreCase) > 0 && !e.StartsWith(input, StringComparison.OrdinalIgnoreCase))
                {
                    result.Add(new PredictiveSuggestion(e));
                    if (result.Count == _max) break;
                }
            }
        }
        return result.Count == 0 ? default : new SuggestionPackage(result);
    }

    // PSReadLine gives a plugin ~20 ms, so the file is re-read in the background
    private void RefreshIfChanged()
    {
        long length;
        try { length = new FileInfo(_path).Length; } catch { return; }
        if (length == Interlocked.Read(ref _loadedLength)) return;
        if (Interlocked.CompareExchange(ref _loading, 1, 0) != 0) return;
        Task.Run(() => { try { Reload(); } finally { Volatile.Write(ref _loading, 0); } });
    }

    private void Reload()
    {
        if (!File.Exists(_path)) return;
        long length = new FileInfo(_path).Length;
        var lines = new List<string>();
        using (var fs = new FileStream(_path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        using (var reader = new StreamReader(fs))
        {
            // multi-line entries are stored as lines ending with a backtick; skipped entirely
            bool continuation = false;
            string line;
            while ((line = reader.ReadLine()) != null)
            {
                bool endsWithTick = line.EndsWith("`");
                if (!continuation && !endsWithTick) lines.Add(line);
                continuation = endsWithTick;
            }
        }

        var seen = new HashSet<string>(StringComparer.Ordinal);
        var result = new List<string>(lines.Count);
        for (int i = lines.Count - 1; i >= 0; i--)
        {
            string t = lines[i].Trim();
            if (t.Length > 0 && seen.Add(t)) result.Add(t);
        }
        _entries = result.ToArray();
        Interlocked.Exchange(ref _loadedLength, length);
    }

    public bool CanAcceptFeedback(PredictionClient client, PredictorFeedbackKind feedback) => false;
    public void OnSuggestionDisplayed(PredictionClient client, uint session, int countOrIndex) { }
    public void OnSuggestionAccepted(PredictionClient client, uint session, string acceptedSuggestion) { }
    public void OnCommandLineAccepted(PredictionClient client, IReadOnlyList<string> history) { }
    public void OnCommandLineExecuted(PredictionClient client, string commandLine, bool success) { }
}
'@
$EmbeddedFiles['omp-theme'] = @'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 3,
  "final_space": true,
  "console_title_template": "{{ .Folder }}",
  "palettes": {
    "template": "{{ .Env.TERMINAL_THEME }}",
    "list": {
      "mocha":     { "text": "#CDD6F4", "subtext": "#A6ADC8", "overlay": "#7F849C", "dim": "#6C7086", "blue": "#89B4FA", "mauve": "#CBA6F7", "green": "#A6E3A1", "red": "#F38BA8", "peach": "#FAB387", "yellow": "#F9E2AF", "teal": "#94E2D5", "lavender": "#B4BEFE", "sapphire": "#74C7EC" },
      "macchiato": { "text": "#CAD3F5", "subtext": "#A5ADCB", "overlay": "#8087A2", "dim": "#6E738D", "blue": "#8AADF4", "mauve": "#C6A0F6", "green": "#A6DA95", "red": "#ED8796", "peach": "#F5A97F", "yellow": "#EED49F", "teal": "#8BD5CA", "lavender": "#B7BDF8", "sapphire": "#7DC4E4" },
      "frappe":    { "text": "#C6D0F5", "subtext": "#A5ADCE", "overlay": "#838BA7", "dim": "#737994", "blue": "#8CAAEE", "mauve": "#CA9EE6", "green": "#A6D189", "red": "#E78284", "peach": "#EF9F76", "yellow": "#E5C890", "teal": "#81C8BE", "lavender": "#BABBF1", "sapphire": "#85C1DC" },
      "latte":     { "text": "#4C4F69", "subtext": "#6C6F85", "overlay": "#8C8FA1", "dim": "#9CA0B0", "blue": "#1E66F5", "mauve": "#8839EF", "green": "#40A02B", "red": "#D20F39", "peach": "#FE640B", "yellow": "#DF8E1D", "teal": "#179299", "lavender": "#7287FD", "sapphire": "#209FB5" }
    }
  },
  "palette": { "text": "#CDD6F4", "subtext": "#A6ADC8", "overlay": "#7F849C", "dim": "#6C7086", "blue": "#89B4FA", "mauve": "#CBA6F7", "green": "#A6E3A1", "red": "#F38BA8", "peach": "#FAB387", "yellow": "#F9E2AF", "teal": "#94E2D5", "lavender": "#B4BEFE", "sapphire": "#74C7EC" },
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        { "type": "text", "style": "plain", "foreground": "p:dim", "template": "╭─" },
        { "type": "root", "style": "plain", "foreground": "p:red", "template": "  admin" },
        { "type": "session", "style": "plain", "foreground": "p:peach", "template": "{{ if .SSHSession }}  {{ .UserName }}@{{ .HostName }}{{ end }}" },
        {
          "type": "path", "style": "plain", "foreground": "p:blue",
          "template": "  {{ .Path }}",
          "options": { "style": "agnoster_short", "max_depth": 3, "home_icon": "~" }
        },
        {
          "type": "git", "style": "plain", "foreground": "p:mauve",
          "template": "   {{ .HEAD }}{{ if .Staging.Changed }} <p:green>{{ .Staging.String }}</>{{ end }}{{ if .Working.Changed }} <p:peach>{{ .Working.String }}</>{{ end }}{{ if gt .StashCount 0 }} <p:overlay>{{ .StashCount }}</>{{ end }}{{ if gt .Ahead 0 }} <p:teal>⇡{{ .Ahead }}</>{{ end }}{{ if gt .Behind 0 }} <p:teal>⇣{{ .Behind }}</>{{ end }}",
          "options": { "fetch_status": true, "fetch_stash_count": true, "branch_icon": "" }
        },
        { "type": "python", "style": "plain", "foreground": "p:yellow", "template": "   {{ .Major }}.{{ .Minor }}{{ if .Venv }} ({{ .Venv }}){{ end }}", "options": { "display_mode": "files", "fetch_virtual_env": true } },
        { "type": "node", "style": "plain", "foreground": "p:green", "template": "   {{ .Major }}", "options": { "display_mode": "files" } },
        { "type": "go", "style": "plain", "foreground": "p:sapphire", "template": "   {{ .Major }}.{{ .Minor }}", "options": { "display_mode": "files" } },
        { "type": "rust", "style": "plain", "foreground": "p:peach", "template": "   {{ .Major }}.{{ .Minor }}", "options": { "display_mode": "files" } }
      ]
    },
    {
      "type": "prompt",
      "alignment": "right",
      "segments": [
        { "type": "kubectl", "style": "plain", "foreground": "p:overlay", "template": "󱃾 {{ .Context }}{{ if and .Namespace (ne .Namespace \"default\") }}/{{ .Namespace }}{{ end }}  ", "options": { "parse_kubeconfig": true } },
        { "type": "executiontime", "style": "plain", "foreground": "p:overlay", "template": " {{ .FormattedMs }}  ", "options": { "threshold": 2000, "style": "austin" } },
        { "type": "status", "style": "plain", "foreground": "p:red", "template": " {{ .Code}}" }
      ]
    },
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        { "type": "text", "style": "plain", "foreground": "p:dim", "template": "╰─" },
        {
          "type": "status", "style": "plain", "foreground": "p:green",
          "foreground_templates": [ "{{ if gt .Code 0 }}p:red{{ end }}" ],
          "template": "❯",
          "options": { "always_enabled": true }
        }
      ]
    }
  ],
  "transient_prompt": { "foreground": "p:overlay", "template": "{{ .Folder }} <p:green>❯</> " },
  "secondary_prompt": { "foreground": "p:dim", "template": "❯❯ " }
}
'@
$EmbeddedFiles['srv-bashrc'] = @'
# ~/.bashrc.local - installed by `srv install <host>` from terminal-setup. Nothing runs in the background.
# version: 2.1.0
# Per-server settings: ~/.config/bashrc-local.conf (PROMPT_ENV=prod, LANG_UI=en)
# Your own: ~/.bashrc.d/*.sh and ~/bin/* (a "# help: ..." line shows up in help)

[[ $- == *i* ]] || return

PROMPT_ENV=''
LANG_UI=''
[[ -f ~/.config/bashrc-local.conf ]] && . ~/.config/bashrc-local.conf
[[ $LANG_UI == en ]] || LANG_UI=ru

declare -A T_ru=(
    [help_hint]='help <слово> - поиск · help <встроенная> - справка bash'
    [projects]='проекты' [own]='Своё  (~/bin, ~/.bashrc.d)' [own_script]='скрипт в ~/bin'
    [s_proj]='Проекты  (находятся сами: docker compose ls)' [s_docker]='Docker' [s_server]='Сервер' [s_files]='Файлы'
    [s_hist]='История и ввод' [s_guard]='Подстраховка'
    [r_proj]='все проекты: статус и папка' [r_status]='статус контейнеров' [r_logs]='логи: 200 строк и дальше поток'
    [r_sh]='shell внутри контейнера' [r_any]='любая docker compose команда' [r_cd]='перейти в папку проекта'
    [r_dsh]='shell в контейнере проекта, где ты сейчас' [r_add]='добавить вручную (по умолчанию - текущую)' [r_rm]='скрыть из списка'
    [r_dps]='все контейнеры: статус и порты' [r_dc]='docker compose / логи в текущей папке'
    [r_sys]='нагрузка, память, диск, процессы, контейнеры' [r_ports]='кто слушает порты' [r_psg]='процессы по имени'
    [r_df]='диск · память · размер папок здесь' [r_ll]='подробный список · со скрытыми'
    [r_bak]='копия рядом: файл.bak-дата - перед правкой на проде' [r_ex]='распаковать: tar.gz, zip, xz, 7z…'
    [r_up]='вверх · два вверх · создать и зайти' [r_h]='последние 50 команд · поиск' [r_arrows]='листать только подходящие из истории'
    [r_ctrlr]='поиск по всей истории' [r_tab]='дополнение без учёта регистра (и сервисов)' [r_space]='не сохранится в историю - для паролей'
    [r_rm_guard]='спрашивают перед массовым удалением' [r_down]='docker требует набрать yes' [r_noguard]='без подтверждения (обход алиаса)'
    [r_env]='метка сервера: ~/.config/bashrc-local.conf'
    [k_arrows]='начало команды + ↑/↓' [k_space]=' команда (с пробелом)' [k_env]='● prod в промпте' [k_proj]='<проект>' [k_svc]='сервис' [k_folder]='папка' [k_name]='имя' [k_file]='файл' [k_archive]='архив'
    [sys_load]='нагрузка' [sys_mem]='память' [sys_disk]='диск /' [sys_cores]='ядер' [sys_top]='топ процессов' [sys_cont]='контейнеры' [sys_nolabel]='без метки' [of]='из'
    [p_title]='Проекты' [p_hint]='proj add - добавить текущую папку · proj rm <имя> - скрыть'
    [p_none]='пока нет: запусти docker compose up в папке проекта или proj add' [p_stopped]='не запущен'
    [p_nodir]='нет папки: %s\n' [p_badname]='плохое имя: %s\n' [p_added]='добавлен: %s → %s\n' [p_rmname]='укажи имя: proj rm <имя>'
    [p_hidden]='скрыт: %s (вернуть: proj add %s <папка>)\n' [p_unknown]='нет проекта «%s» - список: proj\n' [p_svc]='укажи сервис: %s sh <Tab>\n'
    [p_cmds]='%s logs <сервис> · %s sh <сервис> · %s restart <сервис> · %s cd' [p_many]='проектов несколько - зайди в папку проекта или: <проект> sh <сервис>'
    [d_warn]='⚠ %s: «docker %s» удалит данные (тома, базы).' [d_ask]='Напиши yes, чтобы продолжить: ' [d_cancel]='Отменено.'
    [ex_nofile]='нет файла: %s\n' [ex_unknown]='не знаю, чем распаковать: %s\n'
    [banner]='help - шпаргалка · sys - состояние сервера'
)
declare -A T_en=(
    [help_hint]='help <word> - search · help <builtin> - bash help'
    [projects]='projects' [own]='Mine  (~/bin, ~/.bashrc.d)' [own_script]='script in ~/bin'
    [s_proj]='Projects  (discovered: docker compose ls)' [s_docker]='Docker' [s_server]='Server' [s_files]='Files'
    [s_hist]='History and input' [s_guard]='Guards'
    [r_proj]='all projects: status and folder' [r_status]='container status' [r_logs]='logs: last 200 lines, then follow'
    [r_sh]='shell inside a container' [r_any]='any docker compose command' [r_cd]='go to the project folder'
    [r_dsh]='shell in a container of the project you are in' [r_add]='add manually (default - current folder)' [r_rm]='hide from the list'
    [r_dps]='all containers: status and ports' [r_dc]='docker compose / logs in the current folder'
    [r_sys]='load, memory, disk, processes, containers' [r_ports]='who listens on which port' [r_psg]='processes by name'
    [r_df]='disk · memory · folder sizes here' [r_ll]='detailed list · with hidden files'
    [r_bak]='copy next to it: file.bak-date - before editing on prod' [r_ex]='extract: tar.gz, zip, xz, 7z…'
    [r_up]='up · two up · create and enter' [r_h]='last 50 commands · search' [r_arrows]='scroll only matching history'
    [r_ctrlr]='search the whole history' [r_tab]='case-insensitive completion (and services)' [r_space]='not saved to history - for passwords'
    [r_rm_guard]='ask before mass deletion' [r_down]='docker asks you to type yes' [r_noguard]='no confirmation (bypass the alias)'
    [r_env]='server label: ~/.config/bashrc-local.conf'
    [k_arrows]='command prefix + ↑/↓' [k_space]=' command (leading space)' [k_env]='● prod in the prompt' [k_proj]='<project>' [k_svc]='service' [k_folder]='folder' [k_name]='name' [k_file]='file' [k_archive]='archive'
    [sys_load]='load' [sys_mem]='memory' [sys_disk]='disk /' [sys_cores]='cores' [sys_top]='top processes' [sys_cont]='containers' [sys_nolabel]='no label' [of]='of'
    [p_title]='Projects' [p_hint]='proj add - add the current folder · proj rm <name> - hide'
    [p_none]='none yet: run docker compose up in a project folder or proj add' [p_stopped]='not running'
    [p_nodir]='no such folder: %s\n' [p_badname]='bad name: %s\n' [p_added]='added: %s → %s\n' [p_rmname]='give a name: proj rm <name>'
    [p_hidden]='hidden: %s (restore: proj add %s <folder>)\n' [p_unknown]='no project "%s" - list: proj\n' [p_svc]='give a service: %s sh <Tab>\n'
    [p_cmds]='%s logs <service> · %s sh <service> · %s restart <service> · %s cd' [p_many]='several projects - enter a project folder or: <project> sh <service>'
    [d_warn]='⚠ %s: "docker %s" deletes data (volumes, databases).' [d_ask]='Type yes to continue: ' [d_cancel]='Cancelled.'
    [ex_nofile]='no such file: %s\n' [ex_unknown]='do not know how to extract: %s\n'
    [banner]='help - cheat sheet · sys - server status'
)
__t() { local v="T_${LANG_UI}[$1]"; printf '%s' "${!v}"; }

HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '
HISTIGNORE='ls:ll:la:pwd:exit:clear:history:h'
shopt -s histappend cmdhist checkwinsize globstar

__git_branch() {
    local b dirty=
    b=$(GIT_OPTIONAL_LOCKS=0 git symbolic-ref --short HEAD 2>/dev/null || GIT_OPTIONAL_LOCKS=0 git rev-parse --short HEAD 2>/dev/null) || return
    [[ -n $(GIT_OPTIONAL_LOCKS=0 git status --porcelain --untracked-files=no 2>/dev/null | head -n1) ]] && dirty='*'
    printf ' ⎇ %s%s' "$b" "$dirty"
}

# DEBUG trap remembers when the first top-level command after the prompt started;
# commands that are part of PROMPT_COMMAND are skipped so idle time is never counted.
__cmd_start() { [[ "${PROMPT_COMMAND[*]}" == *"$BASH_COMMAND"* ]] || __ts=${__ts:-$SECONDS}; }
trap __cmd_start DEBUG

__fmt_duration() {
    local s=$1
    if (( s >= 3600 )); then printf '%dh %dm' $((s/3600)) $((s%3600/60))
    elif (( s >= 60 )); then printf '%dm %ds' $((s/60)) $((s%60))
    else printf '%ds' "$s"; fi
}

__prompt() {
    local code=$?
    local elapsed=$(( SECONDS - ${__ts:-$SECONDS} )); unset __ts
    history -a

    local r='\[\e[0m\]' dim='\[\e[90m\]' red='\[\e[31m\]' green='\[\e[32m\]'
    local yellow='\[\e[33m\]' blue='\[\e[34m\]' mauve='\[\e[35m\]' cyan='\[\e[36m\]'

    local user=$cyan;  (( EUID == 0 )) && user=$red
    local arrow=$green status= env= venv= took=
    (( code != 0 )) && { arrow=$red; status="  ${red}✘ ${code}${r}"; }
    (( elapsed >= 3 )) && took="  ${dim}⏱ $(__fmt_duration $elapsed)${r}"
    if [[ -n $PROMPT_ENV ]]; then
        local envc=$blue
        case $PROMPT_ENV in prod*) envc=$red ;; stag*|test*|qa*) envc=$yellow ;; dev*) envc=$green ;; esac
        env="${envc}● ${PROMPT_ENV}${r} "
    fi
    [[ -n $VIRTUAL_ENV ]] && venv="  ${yellow}($(basename "$VIRTUAL_ENV"))${r}"

    PS1="\[\e]0;${PROMPT_ENV:+[$PROMPT_ENV] }\u@\h: \w\a\]"
    PS1+="\n${dim}┌─${r} ${env}${user}\u${dim}@${r}${yellow}\h${r} ${blue}\w${r}${mauve}$(__git_branch)${r}${venv}${took}${status}"
    PS1+="\n${dim}└─${arrow}❯${r} "
}
[[ "${PROMPT_COMMAND[*]}" == *__prompt* ]] || PROMPT_COMMAND="__prompt${PROMPT_COMMAND:+; ${PROMPT_COMMAND[*]}}"

export LESS='-R -F -X -i'
export LESS_TERMCAP_md=$'\e[1;34m' LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;32m' LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_so=$'\e[30;43m' LESS_TERMCAP_se=$'\e[0m'
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah --color=auto --group-directories-first --time-style=long-iso'
alias la='ls -A'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'

alias rm='rm -I'
alias cp='cp -i'
alias mv='mv -i'

alias ..='cd ..'
alias ...='cd ../..'
alias df='df -h'
alias free='free -h'
alias du1='du -h --max-depth=1 2>/dev/null | sort -h'
alias ports='ss -tulpn'
mkcd() { mkdir -p "$1" && cd "$1"; }
psg() { ps aux | grep -i --color=auto -- "[${1:0:1}]${1:1}"; }
bak() { local f s; s=$(date +%Y%m%d-%H%M%S); for f in "$@"; do command cp -a "$f" "$f.bak-$s" && echo "→ $f.bak-$s"; done; }
ex() {
    [[ -f $1 ]] || { printf "$(__t ex_nofile)" "$1"; return 1; }
    case $1 in
        *.tar.gz|*.tgz)  tar xzf "$1" ;;   *.tar.xz|*.txz) tar xJf "$1" ;;   *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar|*.tar.zst) tar xf "$1" ;;    *.gz)  gunzip -k "$1" ;;          *.bz2) bunzip2 -k "$1" ;;
        *.xz)  unxz -k "$1" ;;             *.zip) unzip -q "$1" ;;           *.7z)  7z x "$1" ;;
        *) printf "$(__t ex_unknown)" "$1"; return 1 ;;
    esac
}
h() {
    if (( $# )); then history | grep -i -- "$*" | tail -n 30
    else history | tail -n 50; fi
}

# printf %-Ns counts bytes, which breaks alignment with Cyrillic - pad by characters instead
__pad() { local s=$1 n=$(( $2 - ${#1} )); (( n < 1 )) && n=1; printf '%s%*s' "$s" "$n" ''; }

__dot() {
    case $1 in
        *unhealthy*|Restarting*) printf '\e[31m●\e[0m' ;;
        Up*starting*)            printf '\e[33m●\e[0m' ;;
        Up*)                     printf '\e[32m●\e[0m' ;;
        'Exited (0)'*|Created*)  printf '\e[90m●\e[0m' ;;
        *)                       printf '\e[31m●\e[0m' ;;
    esac
}

if command -v docker >/dev/null; then
    docker() {
        local args=" $* "
        local wipe_volumes=' down .*(-v|--volumes) ' remove_volumes=' volume (rm|prune) ' prune=' system prune '
        if [[ $args =~ $wipe_volumes || $args =~ $remove_volumes || $args =~ $prune ]]; then
            printf "\e[1;31m$(__t d_warn)\e[0m\n" "${PROMPT_ENV:-$(hostname)}" "$*"
            local answer
            read -r -p "$(__t d_ask)" answer
            [[ $answer == yes ]] || { __t d_cancel; echo; return 1; }
        fi
        command docker "$@"
    }
    alias dc='docker compose'
    alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    alias dlogs='docker compose logs -f --tail=200'
fi

# ── projects: discovered from docker compose, remembered in ~/.config/projects ("name<TAB>dir", "-" = hidden)
PROJ_FILE=~/.config/projects
declare -gA PROJ_DIR=() PROJ_STATUS=()
declare -gA __PROJ_FUNCS __PROJ_SVC
__PROJ_SUBCOMMANDS='cd sh logs ps up down restart stop start pull build exec run top config images'

__proj_load() {
    PROJ_DIR=(); PROJ_STATUS=()
    local -A hidden=()
    local name dir
    if [[ -f $PROJ_FILE ]]; then
        while IFS=$'\t' read -r name dir; do
            [[ -n $name ]] || continue
            if [[ $dir == - ]]; then hidden[$name]=1; unset "PROJ_DIR[$name]"
            elif [[ -d $dir ]]; then PROJ_DIR[$name]=$dir; fi
        done < "$PROJ_FILE"
    fi
    command -v docker >/dev/null || return 0
    local json re='"Name":"([^"]*)","Status":"([^"]*)","ConfigFiles":"([^"]*)"'
    json=$(timeout 3 docker compose ls -a --format json 2>/dev/null)
    while [[ $json =~ $re ]]; do
        name=${BASH_REMATCH[1]}
        dir=${BASH_REMATCH[3]%%,*}; dir=${dir%/*}
        json=${json#*"${BASH_REMATCH[0]}"}
        [[ -n ${hidden[$name]} ]] && continue
        PROJ_STATUS[$name]=${BASH_REMATCH[2]}
        if [[ -z ${PROJ_DIR[$name]} && -d $dir ]]; then
            PROJ_DIR[$name]=$dir
            mkdir -p "${PROJ_FILE%/*}" && printf '%s\t%s\n' "$name" "$dir" >> "$PROJ_FILE"
        fi
    done
}

# A function named after each project, unless the name is already a command (git, nginx…) - then `proj <name>`
__proj_define() {
    local name
    for name in "${!PROJ_DIR[@]}"; do
        [[ $name =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || continue
        if [[ -z ${__PROJ_FUNCS[$name]} ]] && type -t "$name" >/dev/null; then continue; fi
        eval "$name() { proj $name \"\$@\"; }"
        complete -F __proj_complete "$name"
        __PROJ_FUNCS[$name]=1
    done
    for name in "${!__PROJ_FUNCS[@]}"; do
        [[ -n ${PROJ_DIR[$name]} ]] && continue
        unset -f "$name"; complete -r "$name" 2>/dev/null; unset "__PROJ_FUNCS[$name]"
    done
}

__proj_current() {
    local name best= len=0 d
    for name in "${!PROJ_DIR[@]}"; do
        d=${PROJ_DIR[$name]}
        if [[ $PWD == "$d" || $PWD == "$d"/* ]] && (( ${#d} > len )); then best=$name; len=${#d}; fi
    done
    [[ -z $best && ${#PROJ_DIR[@]} -eq 1 ]] && best=${!PROJ_DIR[*]}
    printf '%s' "$best"
}

__proj_cmd() { [[ -n ${__PROJ_FUNCS[$1]} ]] && printf '%s' "$1" || printf 'proj %s' "$1"; }

__proj_list() {
    local d=$'\e[90m' t=$'\e[1;35m' c=$'\e[34m' r=$'\e[0m' name state dot
    printf '\n  %s%s%s  %s%s%s\n' "$t" "$(__t p_title)" "$r" "$d" "$(__t p_hint)" "$r"
    if (( ${#PROJ_DIR[@]} == 0 )); then
        printf '  %s%s%s\n\n' "$d" "$(__t p_none)" "$r"; return
    fi
    for name in $(printf '%s\n' "${!PROJ_DIR[@]}" | sort); do
        state=${PROJ_STATUS[$name]:-$(__t p_stopped)}
        case $state in *running*) dot=$'\e[32m●' ;; "$(__t p_stopped)") dot=$'\e[90m○' ;; *) dot=$'\e[33m●' ;; esac
        printf '  %s%s %s%s%s %s %s%s%s\n' "$dot" "$r" "$c" "$(__pad "$(__proj_cmd "$name")" 16)" "$r" "$(__pad "$state" 24)" "$d" "${PROJ_DIR[$name]/#$HOME/\~}" "$r"
    done
    echo
}

__proj_status() {
    local name=$1 dir=${PROJ_DIR[$1]} d=$'\e[90m' t=$'\e[1;35m' r=$'\e[0m' svc state
    local cmd; cmd=$(__proj_cmd "$name")
    printf '\n  %s%s%s  %s%s%s\n' "$t" "$name" "$r" "$d" "${dir/#$HOME/\~}" "$r"
    (cd "$dir" && command docker compose ps -a --format '{{.Service}}'$'\t''{{.Status}}' 2>/dev/null) |
        while IFS=$'\t' read -r svc state; do
            printf '  %s %-24s %s%s%s\n' "$(__dot "$state")" "$svc" "$d" "$state" "$r"
        done
    printf "  %s$(__t p_cmds)%s\n\n" "$d" "$cmd" "$cmd" "$cmd" "$cmd" "$r"
}

proj() {
    local name=$1
    case $name in
        ''|ls) __proj_list; return ;;
        add)
            local dir=${3:-$PWD}
            dir=$(cd "$dir" 2>/dev/null && pwd) || { printf "$(__t p_nodir)" "${3:-$PWD}"; return 1; }
            name=${2:-${dir##*/}}
            [[ $name =~ ^[A-Za-z0-9_.-]+$ ]] || { printf "$(__t p_badname)" "$name"; return 1; }
            mkdir -p "${PROJ_FILE%/*}"
            { [[ -f $PROJ_FILE ]] && awk -F'\t' -v n="$name" '$1 != n' "$PROJ_FILE"; printf '%s\t%s\n' "$name" "$dir"; } > "$PROJ_FILE.tmp" &&
                command mv -f "$PROJ_FILE.tmp" "$PROJ_FILE"
            __proj_load; __proj_define
            printf "$(__t p_added)" "$(__proj_cmd "$name")" "$dir"; return ;;
        rm)
            name=$2
            [[ -n $name ]] || { __t p_rmname; echo; return 1; }
            mkdir -p "${PROJ_FILE%/*}"
            { [[ -f $PROJ_FILE ]] && awk -F'\t' -v n="$name" '$1 != n' "$PROJ_FILE"; printf '%s\t-\n' "$name"; } > "$PROJ_FILE.tmp" &&
                command mv -f "$PROJ_FILE.tmp" "$PROJ_FILE"
            __proj_load; __proj_define
            printf "$(__t p_hidden)" "$name" "$name"; return ;;
    esac

    local dir=${PROJ_DIR[$name]}
    [[ -n $dir ]] || { printf "$(__t p_unknown)" "$name"; return 1; }
    shift
    case $1 in
        '')   __proj_status "$name" ;;
        cd)   cd "$dir" ;;
        sh)   [[ -n $2 ]] || { printf "$(__t p_svc)" "$(__proj_cmd "$name")"; return 1; }
              (cd "$dir" && command docker compose exec "$2" sh -c 'command -v bash >/dev/null && exec bash || exec sh') ;;
        logs) shift
              [[ $1 == -* ]] || set -- -f --tail=200 "$@"
              (cd "$dir" && command docker compose logs "$@") ;;
        *)    (cd "$dir" && docker compose "$@") ;;
    esac
}

__proj_services() {
    local name=$1
    [[ -n ${__PROJ_SVC[$name]} ]] ||
        __PROJ_SVC[$name]=$(cd "${PROJ_DIR[$name]}" && timeout 5 docker compose config --services 2>/dev/null | tr '\n' ' ')
    __svc=${__PROJ_SVC[$name]}
}

__proj_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]} off=0 name
    if [[ ${COMP_WORDS[0]} == proj ]]; then
        if (( COMP_CWORD == 1 )); then COMPREPLY=($(compgen -W "add rm ${!PROJ_DIR[*]}" -- "$cur")); return; fi
        off=1
    fi
    name=${COMP_WORDS[off]}
    [[ -n ${PROJ_DIR[$name]} ]] || return
    if (( COMP_CWORD == off + 1 )); then
        COMPREPLY=($(compgen -W "$__PROJ_SUBCOMMANDS" -- "$cur"))
    else
        __proj_services "$name"
        COMPREPLY=($(compgen -W "$__svc" -- "$cur"))
    fi
}
complete -F __proj_complete proj

app() {
    local name=${1:-$(__proj_current)}
    [[ -n $name ]] || { __proj_list; return; }
    proj "$name" cd
}
dsh() {
    local name; name=$(__proj_current)
    [[ -n $name ]] || { __t p_many; echo; return 1; }
    proj "$name" sh "$1"
}
__app_complete() { COMPREPLY=($(compgen -W "${!PROJ_DIR[*]}" -- "${COMP_WORDS[COMP_CWORD]}")); }
__dsh_complete() {
    local name; name=$(__proj_current); [[ -n $name ]] || return
    __proj_services "$name"; COMPREPLY=($(compgen -W "$__svc" -- "${COMP_WORDS[COMP_CWORD]}"))
}
complete -F __app_complete app
complete -F __dsh_complete dsh

__bar() {
    local p=${1%.*} w=${2:-20} c=$'\e[32m'
    (( p >= 90 )) && c=$'\e[31m' || { (( p >= 70 )) && c=$'\e[33m'; }
    local filled=$(( p * w / 100 ))
    printf '%s' "$c"; printf '█%.0s' $(seq 1 $filled 2>/dev/null); printf '\e[90m'; printf '░%.0s' $(seq 1 $((w - filled)) 2>/dev/null)
    printf '\e[0m %3d%%' "$p"
}

__bar_line() {   # "label__BAR__pct  note" → label + bar + note
    local line pct
    while IFS= read -r line; do
        pct=${line#*__BAR__}; pct=${pct%%  *}
        printf '%s%s%s\n' "${line%%__BAR__*}" "$(__bar "$pct")" "${line#*__BAR__$pct}"
    done
}

sys() {
    local t=$'\e[1;35m' d=$'\e[90m' r=$'\e[0m' name state
    printf '\n  %s%s%s  %s%s · %s%s\n' "$t" "$(hostname)" "$r" "$d" "$(uptime -p)" "${PROMPT_ENV:-$(__t sys_nolabel)}" "$r"
    local load; load=$(cut -d' ' -f1 /proc/loadavg)
    printf '  %s%s%s  %s  %s%s · %s: %s%s\n' "$d" "$(__pad "$(__t sys_load)" 9)" "$r" "$(__bar "$(awk -v l="$load" -v n="$(nproc)" 'BEGIN{printf "%d", l/n*100}')")" "$d" "$(cut -d' ' -f1-3 /proc/loadavg)" "$(__t sys_cores)" "$(nproc)" "$r"
    # `command` - the free/df aliases above would otherwise change the output format
    command free -b | awk -v d="$d" -v r="$r" -v L="$(__pad "$(__t sys_mem)" 9)" -v of="$(__t of)" '/^Mem:/ {printf "  %s%s%s  __BAR__%d  %s%.1f %s %.1f GB%s\n", d, L, r, ($2-$7)/$2*100, d, ($2-$7)/1073741824, of, $2/1073741824, r}' | __bar_line
    command df -P / | awk -v d="$d" -v r="$r" -v L="$(__pad "$(__t sys_disk)" 9)" -v of="$(__t of)" 'NR==2 {gsub("%","",$5); printf "  %s%s%s  __BAR__%d  %s%.0f %s %.0f GB%s\n", d, L, r, $5, d, $3/1048576, of, $2/1048576, r}' | __bar_line

    printf '\n  %s%s%s\n' "$t" "$(__t sys_top)" "$r"
    ps -eo comm,%cpu,%mem --sort=-%cpu --no-headers | head -n 5 |
        awk -v c=$'\e[34m' -v d="$d" -v r="$r" '{printf "  %s%-26s%s %scpu %5.1f%%   mem %5.1f%%%s\n", c, $1, r, d, $2, $3, r}'

    if command -v docker >/dev/null; then
        printf '\n  %s%s%s\n' "$t" "$(__t sys_cont)" "$r"
        command docker ps -a --format '{{.Names}}'$'\t''{{.Status}}' | while IFS=$'\t' read -r name state; do
            printf '  %s %-30s %s%s%s\n' "$(__dot "$state")" "$name" "$d" "$state" "$r"
        done
    fi
    echo
}

__help_rows() {
    local f=$1
    __help_section() { __pending_title=$1; }
    __help_row() {
        [[ -n $f && "${1,,} ${2,,}" != *"${f,,}"* ]] && return
        if [[ -n $__pending_title ]]; then printf '\n  \e[1;35m%s\e[0m\n' "$__pending_title"; __pending_title=; fi
        printf '    \e[34m%s\e[0m %s \e[90m%s\e[0m\n' "$(__pad "$1" 27)" "$(__pad "$2" 44)" "$3"
    }
    local ex; ex=$(__proj_current); ex=${ex:-${!PROJ_DIR[*]}}; ex=${ex%% *}; ex=${ex:-myapp}
    local p; p=$(__proj_cmd "$ex")
    local P; P=$(__t k_proj)
    local S; S=$(__t k_svc)

    __help_section "$(__t s_proj)"
    __help_row 'proj' "$(__t r_proj)"
    __help_row "$P" "$(__t r_status)" "$p"
    __help_row "$P logs [$S]" "$(__t r_logs)" "$p logs web"
    __help_row "$P sh <$S>" "$(__t r_sh)" "$p sh web"
    __help_row "$P <cmd>" "$(__t r_any)" "$p restart web"
    __help_row "$P cd · app" "$(__t r_cd)" "app $ex"
    __help_row "dsh <$S>" "$(__t r_dsh)"
    __help_row "proj add [$(__t k_name)] [$(__t k_folder)]" "$(__t r_add)"
    __help_row "proj rm <$(__t k_name)>" "$(__t r_rm)"
    __help_section "$(__t s_docker)"
    __help_row 'dps' "$(__t r_dps)"
    __help_row 'dc · dlogs' "$(__t r_dc)"
    __help_section "$(__t s_server)"
    __help_row 'sys' "$(__t r_sys)"
    __help_row 'ports' "$(__t r_ports)"
    __help_row "psg <$(__t k_name)>" "$(__t r_psg)" 'psg nginx'
    __help_row 'df · free · du1' "$(__t r_df)"
    __help_section "$(__t s_files)"
    __help_row 'll · la' "$(__t r_ll)"
    __help_row "bak <$(__t k_file)>" "$(__t r_bak)" 'bak .env'
    __help_row "ex <$(__t k_archive)>" "$(__t r_ex)"
    __help_row ".. · ... · mkcd <$(__t k_folder)>" "$(__t r_up)"
    __help_section "$(__t s_hist)"
    __help_row 'h · h <text>' "$(__t r_h)"
    __help_row "$(__t k_arrows)" "$(__t r_arrows)"
    __help_row 'Ctrl+R' "$(__t r_ctrlr)"
    __help_row 'Tab' "$(__t r_tab)"
    __help_row "$(__t k_space)" "$(__t r_space)"
    __help_section "$(__t s_guard)"
    __help_row 'rm · cp · mv' "$(__t r_rm_guard)"
    __help_row 'down -v · volume rm · prune' "$(__t r_down)"
    __help_row '\rm …' "$(__t r_noguard)"
    __help_row "$(__t k_env)" "$(__t r_env)"

    __help_section "$(__t own)"
    local file line
    for file in ~/bin/*; do
        [[ -f $file && -x $file ]] || continue
        line=$(head -n 15 "$file" | sed -n 's/^[[:space:]]*\(#\|\/\/\|;;\|--\)[[:space:]]*help:[[:space:]]*//p' | head -n1)
        __help_row "${file##*/}" "${line:-$(__t own_script)}"
    done
    for file in ~/.bashrc.d/*.sh; do
        [[ -f $file ]] || continue
        while IFS= read -r line; do
            __help_row "${line%% - *}" "${line#* - }" "${file##*/}"
        done < <(sed -n 's/^[[:space:]]*#[[:space:]]*help:[[:space:]]*//p' "$file")
    done
    unset -f __help_section __help_row
}

help() {
    local d=$'\e[90m' t=$'\e[1;35m' r=$'\e[0m'
    if (( $# )) && builtin help "$1" >/dev/null 2>&1; then builtin help "$@"; return; fi
    printf '\n  %s✦ %s%s%s   %s%s%s\n' "$t" "$(hostname)" "${PROMPT_ENV:+ · $PROMPT_ENV}" "$r" "$d" "$(__t help_hint)" "$r"
    if (( ${#PROJ_DIR[@]} )); then printf '  %s%s: %s%s\n' "$d" "$(__t projects)" "$(for n in "${!PROJ_DIR[@]}"; do printf '%s  ' "$(__proj_cmd "$n")"; done)" "$r"; fi
    local __pending_title=
    __help_rows "$*"
    echo
}

for __f in ~/.bashrc.d/*.sh; do [[ -f $__f ]] && . "$__f"; done; unset __f

__proj_load
__proj_define

if shopt -q login_shell; then
    __names=$(for n in $(printf '%s\n' "${!PROJ_DIR[@]}" | sort); do printf '%s ' "$(__proj_cmd "$n")"; done)
    printf '\e[90m  %s%s\e[0m\n' "${__names:+$(__t projects): $__names· }" "$(__t banner)"
    unset __names
fi
'@
$EmbeddedFiles['srv-inputrc'] = @'
# srv: managed. Installed by srv install; the previous file is kept as ~/.inputrc.bak-*
$include /etc/inputrc

set completion-ignore-case on
set show-all-if-ambiguous on
set colored-stats on
set colored-completion-prefix on
set mark-symlinked-directories on
set bell-style none

"\e[A": history-search-backward
"\e[B": history-search-forward

"\e[1;5C": forward-word
"\e[1;5D": backward-word
'@
$EmbeddedFiles['srv-install'] = @'
# Runs on the server through `ssh host 'bash -s'`; placeholders __…__ are filled by srv (PowerShell).
set -eu
umask 022

action='__ACTION__'
env_label='__ENV__'
lang='__LANG__'
[[ $lang == en ]] || lang=ru
ts=$(date +%Y%m%d-%H%M%S)
ok=$'\e[32m✓\e[0m' warn=$'\e[33m!\e[0m' bad=$'\e[31m✗\e[0m' dim=$'\e[90m' r=$'\e[0m'
conf=~/.config/bashrc-local.conf
hook='[ -f ~/.bashrc.local ] && . ~/.bashrc.local   # prompt, history, helpers (srv)'

declare -A M_ru=(
    [removed_hook]='строка подключения убрана из ~/.bashrc' [backup]='бэкап' [kept]='~/.config/projects, ~/.config/bashrc-local.conf и ~/.bashrc.d оставлены'
    [uptodate]='уже актуален' [syntax_err]='синтаксическая ошибка - ничего не меняю' [load_err]='пробная загрузка с ошибками - ничего не меняю:'
    [checked]='проверка: синтаксис и пробная загрузка' [label]='метка' [none]='нет' [lang]='язык' [migrated]='метка перенесена из старой версии'
    [created]='создан' [hook_present]='~/.bashrc уже подключает ~/.bashrc.local' [hook_added]='~/.bashrc: добавлена строка подключения'
    [profile_warn]='~/.bash_profile не подключает ~/.bashrc - добавь: [ -f ~/.bashrc ] && . ~/.bashrc' [profile_created]='создан ~/.bash_profile (подключает ~/.bashrc при входе)'
    [projects]='проекты' [relogin]='перезайди по ssh, затем help'
)
declare -A M_en=(
    [removed_hook]='hook line removed from ~/.bashrc' [backup]='backup' [kept]='~/.config/projects, ~/.config/bashrc-local.conf and ~/.bashrc.d kept'
    [uptodate]='already up to date' [syntax_err]='syntax error - nothing changed' [load_err]='trial load failed - nothing changed:'
    [checked]='checked: syntax and trial load' [label]='label' [none]='none' [lang]='language' [migrated]='label migrated from the old version'
    [created]='created' [hook_present]='~/.bashrc already sources ~/.bashrc.local' [hook_added]='~/.bashrc: hook line added'
    [profile_warn]='~/.bash_profile does not source ~/.bashrc - add: [ -f ~/.bashrc ] && . ~/.bashrc' [profile_created]='created ~/.bash_profile (sources ~/.bashrc on login)'
    [projects]='projects' [relogin]='reconnect over ssh, then help'
)
m() { local v="M_${lang}[$1]"; printf '%s' "${!v}"; }

echo "${dim}$(whoami)@$(hostname) · $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") · bash ${BASH_VERSION%%(*}${r}"

if [ "$action" = remove ]; then
    if [ -f ~/.bashrc ] && grep -qF '.bashrc.local' ~/.bashrc; then
        cp -p ~/.bashrc ~/.bashrc.bak-$ts
        grep -vF '.bashrc.local' ~/.bashrc.bak-$ts > ~/.bashrc || true
        echo "$ok $(m removed_hook) ${dim}($(m backup) ~/.bashrc.bak-$ts)${r}"
    fi
    if [ -f ~/.bashrc.local ]; then
        mv ~/.bashrc.local ~/.bashrc.local.off-$ts
        echo "$ok ~/.bashrc.local → ~/.bashrc.local.off-$ts"
    fi
    if [ -f ~/.inputrc ] && grep -q 'srv: managed' ~/.inputrc; then
        mv ~/.inputrc ~/.inputrc.off-$ts
        echo "$ok ~/.inputrc → ~/.inputrc.off-$ts"
    fi
    echo "${dim}$(m kept)${r}"
    exit 0
fi

__put() {
    local target=~/"$1" tmp
    tmp=$(mktemp)
    printf '%s' "$2" | base64 -d > "$tmp"
    mkdir -p "${target%/*}"
    if [ -f "$target" ] && cmp -s "$tmp" "$target"; then rm -f "$tmp"; echo "$ok ~/$1 $(m uptodate)"; return; fi
    cat "$tmp" > "$target"; rm -f "$tmp"
    echo "$ok ~/$1"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '%s' '__BASHRC_B64__' | base64 -d > "$work/bashrc.local"
printf '%s' '__INPUTRC_B64__' | base64 -d > "$work/inputrc"

bash -n "$work/bashrc.local" || { echo "$bad $(m syntax_err)"; exit 1; }
errors=$(HOME=$HOME bash --norc -i -c ". '$work/bashrc.local'" </dev/null 2>&1 >/dev/null |
    grep -v -e 'job control' -e 'terminal process group' -e 'Inappropriate ioctl' || true)
if [ -n "$errors" ]; then
    echo "$bad $(m load_err)"; echo "$errors"; exit 1
fi
echo "$ok $(m checked)"

mkdir -p ~/.config
{ [ -f "$conf" ] && grep -v -e '^PROMPT_ENV=' -e '^LANG_UI=' "$conf" || true; } > "$work/conf"
if [ -n "$env_label" ]; then
    [ "$env_label" = none ] && env_label=''
elif [ -f "$conf" ]; then
    env_label=$(sed -n 's/^PROMPT_ENV=\([A-Za-z0-9_-]*\).*/\1/p' "$conf" | head -n1)
elif [ -f ~/.bashrc.local ]; then
    env_label=$(sed -n 's/^PROMPT_ENV=\([A-Za-z0-9_-]*\).*/\1/p' ~/.bashrc.local | head -n1)
    [ -n "$env_label" ] && echo "$ok $(m migrated): $env_label"
fi
printf 'PROMPT_ENV=%s\nLANG_UI=%s\n' "$env_label" "$lang" >> "$work/conf"
cat "$work/conf" > "$conf"
echo "$ok $(m label): ${env_label:-$(m none)} · $(m lang): $lang"

old_ver=$(sed -n 's/^# version: //p' ~/.bashrc.local 2>/dev/null | head -n1 || true)
new_ver=$(sed -n 's/^# version: //p' "$work/bashrc.local" | head -n1)
if [ -f ~/.bashrc.local ] && cmp -s "$work/bashrc.local" ~/.bashrc.local; then
    echo "$ok ~/.bashrc.local $(m uptodate) ${dim}($new_ver)${r}"
else
    if [ -f ~/.bashrc.local ]; then
        cp -p ~/.bashrc.local ~/.bashrc.local.bak-$ts
        echo "$ok $(m backup): ~/.bashrc.local.bak-$ts"
    fi
    cat "$work/bashrc.local" > ~/.bashrc.local
    echo "$ok ~/.bashrc.local ${dim}${old_ver:-$(m none)} → ${r}$new_ver"
fi

if [ -f ~/.inputrc ] && cmp -s "$work/inputrc" ~/.inputrc; then
    echo "$ok ~/.inputrc $(m uptodate)"
else
    if [ -f ~/.inputrc ]; then
        cp -p ~/.inputrc ~/.inputrc.bak-$ts
        echo "$ok $(m backup): ~/.inputrc.bak-$ts"
    fi
    cat "$work/inputrc" > ~/.inputrc
    echo "$ok ~/.inputrc"
fi

if [ ! -f ~/.bashrc ]; then
    if [ -f /etc/skel/.bashrc ]; then cp /etc/skel/.bashrc ~/.bashrc; else : > ~/.bashrc; fi
    echo "$ok ~/.bashrc $(m created)"
fi
if grep -qF '.bashrc.local' ~/.bashrc; then
    echo "$ok $(m hook_present)"
else
    cp -p ~/.bashrc ~/.bashrc.bak-$ts
    printf '\n%s\n' "$hook" >> ~/.bashrc
    echo "$ok $(m hook_added) ${dim}($(m backup) ~/.bashrc.bak-$ts)${r}"
fi

mkdir -p ~/.bashrc.d
__CUSTOM_FILES__

if [ -f ~/.bash_profile ]; then
    grep -q 'bashrc' ~/.bash_profile || echo "$warn $(m profile_warn)"
elif [ ! -f ~/.bash_login ] && [ ! -f ~/.profile ]; then
    printf '%s\n' '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.bash_profile
    echo "$ok $(m profile_created)"
fi

projects=$(bash --norc -i -c '. ~/.bashrc.local; printf "%s " "${!PROJ_DIR[@]}"' </dev/null 2>/dev/null || true)
echo "${dim}$(m projects): ${projects:-$(m none)} · $(m relogin)${r}"
# end
'@

if (-not $SkipApps) {
    Step $L.s_apps
    if (-not (Test-Command winget)) {
        Warn $L.skip_apps
    } else {
        Install-WingetPackage 'Microsoft.WindowsTerminal' 'wt' 'Windows Terminal'
        $apps = @(
            @('Git.Git', 'git', 'git'),
            @('JanDeDobbeleer.OhMyPosh', 'oh-my-posh', 'oh-my-posh'),
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
. ([scriptblock]::Create($EmbeddedFiles['palette']))
if ($Theme -and -not $Themes.Contains($Theme.ToLower())) { throw "-Theme: $($Themes.Keys -join ', ')" }
if ($Theme) { New-Item -ItemType Directory -Force $ConfigDir | Out-Null; [IO.File]::WriteAllText($ThemeFile, "$($Theme.ToLower())`n") }
$ThemeName = Get-ThemeName
$ThemeTitle = $Themes[$ThemeName].title
$EmbeddedFiles['omp-theme'] = Set-OmpPalettes $EmbeddedFiles['omp-theme'] $ThemeName

$targets = [ordered]@{
    'profile'      = $PROFILE
    'palette'      = Join-Path $ProfileDir 'palette.ps1'
    'lang'         = Join-Path $ProfileDir 'lang.ps1'
    'toolkit'      = Join-Path $ProfileDir 'toolkit.ps1'
    'toolkit-lazy' = Join-Path $ProfileDir 'toolkit-lazy.ps1'
    'predictor'    = Join-Path $ProfileDir 'DeepHistoryPredictor.cs'
    'omp-theme'    = Join-Path $HOME '.config\ohmyposh\soft.omp.json'
    'srv-bashrc'   = Join-Path $ProfileDir 'server\bashrc.local'
    'srv-inputrc'  = Join-Path $ProfileDir 'server\inputrc'
    'srv-install'  = Join-Path $ProfileDir 'server\install.sh'
}
foreach ($key in $targets.Keys) { Write-ManagedFile $targets[$key] $EmbeddedFiles[$key] }
Remove-Item "$HOME\.cache\terminal-setup\omp-init.txt" -ErrorAction SilentlyContinue

$customFile = Join-Path $ProfileDir 'custom.ps1'
if (Test-Path $customFile) { Ok "$(Short $customFile) - $($L.custom_yours)" }
else { [IO.File]::WriteAllText($customFile, ($EmbeddedFiles['custom'] -replace "`r`n", "`n"), $Utf8NoBom); Ok "$(Short $customFile) - $($L.custom_created)" }
foreach ($d in 'bin', 'server\custom') {
    $p = Join-Path $ProfileDir $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force $p | Out-Null; Ok "$(Short $p)\ - $($L.dir_created)" }
}

New-Item -ItemType Directory -Force $ConfigDir | Out-Null
[IO.File]::WriteAllText($LangFile, "$Lang`n")
Ok ($L.lang_set -f $Lang)
Ok ($L.theme_set -f $ThemeName)

function Set-Key($Table, [string]$Key, $Value) { $Table[$Key] = $Value }

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
    Set-Key $d 'colorScheme' $ThemeTitle
    if (-not $d.Contains('font') -or -not ($d.font -is [Collections.IDictionary])) { $d['font'] = [ordered]@{} }
    Set-Key $d.font 'face' $FontFace
    Set-Key $d.font 'size' 11
    Set-Key $d.font 'cellHeight' '1.2'
    Set-Key $d 'padding' '14, 10'
    Set-Key $d 'cursorShape' 'bar'
    Set-Key $d 'antialiasingMode' 'cleartype'
    Set-Key $d 'intenseTextStyle' 'bright'
    Set-Key $d 'scrollbarState' 'hidden'
    Set-Key $d 'historySize' 20000
    Set-Key $d 'bellStyle' 'none'

    $pwshGuid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
    $pw = $list | Where-Object { $_.guid -eq $pwshGuid } | Select-Object -First 1
    if (-not $pw) {
        $pw = [ordered]@{ guid = $pwshGuid; name = 'PowerShell 7'; source = 'Windows.Terminal.PowershellCore'; hidden = $false }
        $list.Insert(0, $pw)
    }
    Set-Key $pw 'name' 'PowerShell 7'
    Set-Key $pw 'hidden' $false
    if ($StartingDirectory) { Set-Key $pw 'startingDirectory' $StartingDirectory }
    Set-Key $s 'defaultProfile' $pwshGuid

    foreach ($p in $list) { if ($p.source -eq 'Windows.Terminal.Azure') { Set-Key $p 'hidden' $true } }

    foreach ($h in $SshTabs) {
        $tab = $list | Where-Object { $_.commandline -eq "ssh $h" } | Select-Object -First 1
        if (-not $tab) { $tab = [ordered]@{ guid = (Get-StableGuid "ssh:$h") }; $list.Add($tab) }
        Set-Key $tab 'name' "$h (ssh)"
        Set-Key $tab 'commandline' "ssh $h"
        Set-Key $tab 'icon' ([string][char]0xF233)
        Set-Key $tab 'tabColor' '#FAB387'
        Set-Key $tab 'hidden' $false
    }
    $s.profiles['list'] = $list.ToArray()

    $ours = @($Themes.Values.title)
    $s['schemes'] = @(@($s.schemes | Where-Object { $_ -and $_.name -notin $ours -and $_.name -notlike 'Catppuccin *' }) + @($Themes.Keys | ForEach-Object { Get-TerminalScheme $_ }))
    $s['themes'] = @(@($s.themes | Where-Object { $_ -and $_.name -notin $ours -and $_.name -notlike 'Catppuccin *' }) + @($Themes.Keys | ForEach-Object { Get-TerminalTheme $_ }))
    Set-Key $s 'theme' $ThemeTitle

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
    foreach ($k in 'delta.minus-style', 'delta.minus-emph-style', 'delta.plus-style', 'delta.plus-emph-style') {
        if (git config --global --get $k 2>$null) { git config --global --unset $k; $changed++ }
    }
    if ($changed) { Ok ($L.git_changed -f $changed) } else { Ok $L.git_same }
}

Step $L.s_check
$check = & (Get-Pwsh) -NoLogo -NoProfile -Command "`$Error.Clear(); . '$PROFILE' *> `$null; `$Error.Count; foreach (`$e in `$Error) { `$e.ToString() }" 2>&1
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
