<#
.SYNOPSIS
  Красивый и удобный терминал на Windows 11 одной командой. Повторный запуск ничего не ломает.

.DESCRIPTION
  Ставит (если ещё нет):
    PowerShell 7, Windows Terminal, git, oh-my-posh, fzf, zoxide, eza, bat, ripgrep, fd, delta,
    шрифт JetBrainsMono Nerd Font — для всех пользователей (иначе Windows Terminal его не видит),
    модуль PSFzf.
  Настраивает:
    профиль PowerShell 7: цвета Catppuccin Mocha, промпт, подсказки до 50 из истории, Tab-дополнения,
      команды help, my, h, jump, srv, l/ll/lt, z;
    Windows Terminal: PowerShell 7 по умолчанию, схема и тема Catppuccin Mocha, шрифт, отступы;
    терминал VS Code: шрифт с иконками;
    git: красивые диффы через delta;
    шаблоны для серверов: srv install <хост> ставит такой же bash на Linux-сервер.

  Безопасно запускать повторно: каждый шаг сначала проверяет, что уже сделано.
  Файл с другим содержимым перед заменой сохраняется рядом как *.bak-<дата-время>.

  Репозиторий: https://github.com/Ange1oc/terminal-setup

.EXAMPLE
  irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1 | iex

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1

.EXAMPLE
  .\setup-terminal.ps1 -StartingDirectory D:\code -SshTabs myserver,staging

.PARAMETER StartingDirectory
  Папка, в которой открывается новая вкладка PowerShell 7. Не указана — не трогаем.

.PARAMETER SshTabs
  Хосты из ~/.ssh/config, для которых добавить вкладку в меню Windows Terminal (через запятую).

.PARAMETER Theme
  Вариант Catppuccin: mocha (по умолчанию), macchiato, frappe или latte (светлая). Потом: theme latte

.PARAMETER SkipApps
  Не ставить программы и шрифт — только конфиги.
#>
param(
    [string]$StartingDirectory,
    [string[]]$SshTabs = @(),
    [ValidateSet('', 'mocha', 'macchiato', 'frappe', 'latte')][string]$Theme = '',
    [switch]$SkipApps
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$SshTabs = @($SshTabs | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# ── Вывод ────────────────────────────────────────────────────────────────────
function Step([string]$Title) { Write-Host ''; Write-Host "▸ $Title" -ForegroundColor Magenta }
function Ok([string]$Text) { Write-Host "  ✓ $Text" -ForegroundColor Green }
function Info([string]$Text) { Write-Host "  · $Text" -ForegroundColor DarkGray }
function Warn([string]$Text) { Write-Host "  ! $Text" -ForegroundColor Yellow; $script:Warnings++ }
function Short([string]$Path) { $Path.Replace($HOME, '~') }
$Warnings = 0

function Test-Command([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

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
    if ($Command -and (Test-Command $Command)) { Ok "$Title — уже есть"; return }
    Info "$Title — устанавливаю…"
    $out = winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2>&1
    $code = $LASTEXITCODE
    Update-SessionPath
    # 0x8A15002B — «уже установлено»
    if ($code -eq 0 -or $code -eq -1978335189 -or ($Command -and (Test-Command $Command))) { Ok "$Title — установлен" }
    else { Warn "$Title — winget вернул $code"; $out | Select-Object -Last 5 | ForEach-Object { Info "$_" } }
}

# ── 0. Windows PowerShell 5.1 → ставим PowerShell 7 и продолжаем в нём ───────
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ''
    Write-Host '  ✦ Настройка терминала' -ForegroundColor Magenta
    Step 'PowerShell 7'
    $pwsh = Get-Pwsh
    if (-not $pwsh) {
        if (-not (Test-Command winget)) {
            throw 'Нет winget. Установи «Установщик приложений» (App Installer) из Microsoft Store и запусти скрипт снова.'
        }
        Install-WingetPackage 'Microsoft.PowerShell' '' 'PowerShell 7'
        $pwsh = Get-Pwsh
        if (-not $pwsh) { throw 'PowerShell 7 не установился — поставь вручную: winget install Microsoft.PowerShell' }
    } else {
        Ok 'PowerShell 7 — уже есть'
    }
    Info 'продолжаю в PowerShell 7…'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($StartingDirectory) { $argList += @('-StartingDirectory', $StartingDirectory) }
    if ($SshTabs) { $argList += @('-SshTabs', ($SshTabs -join ',')) }
    if ($Theme) { $argList += @('-Theme', $Theme) }
    if ($SkipApps) { $argList += '-SkipApps' }
    & $pwsh @argList
    exit $LASTEXITCODE
}

# ── Дальше — PowerShell 7 ────────────────────────────────────────────────────
Write-Host ''
Write-Host '  ✦ Настройка терминала' -ForegroundColor Magenta
Info "PowerShell $($PSVersionTable.PSVersion) · $([Environment]::OSVersion.VersionString)"
if (Test-Admin) { Info 'запущено от администратора — лучше от обычного пользователя, права попрошу сам, где нужно' }

$ProfileDir = Split-Path $PROFILE
$ThemeFile = Join-Path $HOME '.config\terminal-setup\theme'
$FontFace = 'JetBrainsMono NF'
$FontStyles = [ordered]@{ Regular = 'Regular'; Bold = 'Bold'; Italic = 'Italic'; BoldItalic = 'Bold Italic' }
$FontBaseUrl = 'https://github.com/ryanoasis/nerd-fonts/raw/v3.4.0/patched-fonts/JetBrainsMono/Ligatures'

# ── Встроенные файлы (собраны build.ps1 из src/) ────────────────────────────
$EmbeddedFiles = [ordered]@{}
$EmbeddedFiles['profile'] = @'
# ─────────────────────────────────────────────────────────────────────────────
#  PowerShell 7 profile · terminal-setup
#  Одна палитра на всё (Catppuccin, theme — переключить), промпт oh-my-posh,
#  подсказки из истории, сокращения, шпаргалка help, свои команды в bin\.
#  Свои настройки — в custom.ps1 рядом (никогда не перезаписывается).
#  Обновляется скриптом setup-terminal.ps1 (старые версии — *.bak-<дата>).
# ─────────────────────────────────────────────────────────────────────────────

$global:ProfileDir = Split-Path $PROFILE
$env:XDG_CONFIG_HOME = "$HOME\.config"
$global:isInteractive = -not [Console]::IsOutputRedirected -and $Host.Name -eq 'ConsoleHost'

# Переключатели — можно поменять в custom.ps1
$global:TerminalSetup = @{
    Abbreviations = $true    # g␣ → git␣ (abbr — список)
    LayoutFix     = $true    # «вщслук зы» + Enter → docker ps
    Predictions   = 50       # подсказок из истории (0 — встроенные 10 от PSReadLine)
}

. (Join-Path $ProfileDir 'palette.ps1')
$global:ThemeName = Get-ThemeName
$global:Palette = $CatppuccinFlavors[$ThemeName]
$env:TERMINAL_THEME = $ThemeName

. (Join-Path $ProfileDir 'toolkit.ps1')
Set-TerminalPalette

# ── Своё: custom.ps1 и bin\ ──────────────────────────────────────────────────
$before = @(Get-ChildItem Function: | Select-Object -ExpandProperty Name)
$customFile = Join-Path $ProfileDir 'custom.ps1'
if (Test-Path $customFile) {
    try { . $customFile } catch { Write-Warning "custom.ps1: $_" }
}
$global:CustomFunctions = @(Get-ChildItem Function: | Where-Object { $_.Name -notin $before -and $_.Name -notmatch ':' } | Select-Object -ExpandProperty Name)
Remove-Variable before, customFile
Register-BinCommands (Join-Path $ProfileDir 'bin')

# ── PSReadLine: редактирование, история, подсказки ───────────────────────────
if ($isInteractive) {
    Set-PSReadLineOption -EditMode Emacs `
        -HistoryNoDuplicates `
        -HistorySearchCursorMovesToEnd `
        -MaximumHistoryCount 20000 `
        -BellStyle None `
        -PredictionSource History `
        -PredictionViewStyle ListView
    Set-TerminalPalette    # цвета подсказок — теперь, когда PSReadLine загружен

    Set-PSReadLineKeyHandler -Key Tab            -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+c         -Function CancelLine
    Set-PSReadLineKeyHandler -Key UpArrow        -Function HistorySearchBackward   # набрал "git" + ↑ — листаешь только git-команды
    Set-PSReadLineKeyHandler -Key DownArrow      -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key F2             -Function SwitchPredictionView    # список подсказок ⇄ серая подсказка в строке
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord            # принять подсказку по словам
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+Delete    -Function KillWord
    Set-PSReadLineKeyHandler -Key Ctrl+z         -Function Undo
    Set-PSReadLineKeyHandler -Key Ctrl+y         -Function Redo
    Set-PSReadLineKeyHandler -Key Shift+Enter    -Function AddLine
    Set-PSReadLineKeyHandler -Key F1 -BriefDescription 'CheatSheet' -Description 'Шпаргалка с поиском, Enter вставляет команду' -ScriptBlock { Invoke-HelpPicker }

    if ($TerminalSetup.Abbreviations) {
        Set-PSReadLineKeyHandler -Key Spacebar -BriefDescription 'ExpandAbbreviation' -Description 'g␣ → git␣' -ScriptBlock {
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

    # Подсказки из истории: до 50 вместо встроенных 10 (окно 10 строк, листается ↑/↓).
    # Плагин — DeepHistoryPredictor.cs рядом с профилем. DLL кэшируется под хэшем исходника:
    # правка .cs даёт новую DLL, а старая может оставаться занятой в открытых вкладках.
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
            Write-Warning "Подсказки из истории (DeepHistoryPredictor): $_"
        }
    }
}

# ── Промпт ───────────────────────────────────────────────────────────────────
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$HOME\.config\ohmyposh\soft.omp.json" | Invoke-Expression
}

# Enter: исправить раскладку, раскрыть сокращение, затем как обычно (с transient-промптом oh-my-posh)
if ($isInteractive -and ($TerminalSetup.LayoutFix -or $TerminalSetup.Abbreviations)) {
    Set-PSReadLineKeyHandler -Key Enter -BriefDescription 'TerminalSetupEnter' -Description 'Раскладка и сокращения, затем выполнить' -ScriptBlock {
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
        $omp = Get-Module oh-my-posh-core
        if ($omp -and $errors.Count -eq 0) { try { & $omp { Set-TransientPrompt } } catch {} }
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        if ($global:_ompFTCSMarks -and $errors.Count -eq 0) { Write-Host "$([char]27)]133;C$([char]7)" -NoNewline }
    }
}

# ── fzf: Ctrl+R — история, Ctrl+T — файлы, Alt+C — перейти в папку ───────────
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
$env:FZF_CTRL_R_OPTS = '--height=14 --header="Enter — вставить в строку · PgUp/PgDn — листать по 10 · Esc — отмена"'
if ($isInteractive -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
    # модуль PSFzf подгрузится сам при первом нажатии — старт быстрее на ~0.3 с
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Invoke-FzfPsReadlineHandlerHistory }
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Invoke-FzfPsReadlineHandlerProvider }
    Set-PSReadLineKeyHandler -Key Alt+c  -ScriptBlock { Invoke-FzfPsReadlineHandlerSetLocation }
}

# ── zoxide: z <кусок имени> — прыжок в часто используемую папку, zi — с выбором
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ── bat / delta ──────────────────────────────────────────────────────────────
$env:BAT_THEME = 'ansi'          # берёт цвета из схемы терминала
$env:BAT_STYLE = 'numbers,changes,header-filename'

# ── Автодополнения CLI (кэшируются; обновить: Update-Completions) ────────────
$completionCache = "$HOME\.cache\pwsh-completions"
$completionGenerators = [ordered]@{
    kubectl  = { kubectl completion powershell }
    helm     = { helm completion powershell }
    kind     = { kind completion powershell }
    k3d      = { k3d completion powershell }
    minikube = { minikube completion powershell }
    docker   = { docker completion powershell }
    gh       = { gh completion -s powershell }
}
function Update-Completions {
    New-Item -ItemType Directory -Force $completionCache | Out-Null
    foreach ($name in $completionGenerators.Keys) {
        $file = Join-Path $completionCache "$name.ps1"
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            & $completionGenerators[$name] | Out-String | Set-Content $file -Encoding utf8
            Write-Host "  ✓ $name" -ForegroundColor Green
        } elseif (Test-Path $file) {
            Remove-Item $file
        }
    }
}
if (-not (Test-Path $completionCache)) { Update-Completions | Out-Null }
foreach ($file in Get-ChildItem $completionCache -Filter *.ps1) { . $file.FullName }

# ── Команды ──────────────────────────────────────────────────────────────────
$ezaArgs = '--icons=auto', '--group-directories-first', '--color=always'
function l   { eza @ezaArgs @args }
function ll  { eza @ezaArgs -la --git --time-style=relative --no-user @args }
function lt  { eza @ezaArgs --tree --level=2 --git-ignore @args }
function ..  { Set-Location .. }
function ... { Set-Location ..\.. }
function mkcd($path) { New-Item -ItemType Directory -Force $path | Out-Null; Set-Location $path }
function which($name) { Get-Command $name -All | Select-Object CommandType, Name, Source }
function touch($path) { if (Test-Path $path) { (Get-Item $path).LastWriteTime = Get-Date } else { New-Item -ItemType File $path | Out-Null } }
function lg  { git log --graph --pretty='%C(magenta)%h%Creset %C(green)%ar%Creset %C(blue)%an%Creset %s%C(yellow)%d%Creset' -n 30 @args }
function gst { git status -sb @args }
function reload { . $PROFILE }
'@
$EmbeddedFiles['palette'] = @'
# ─────────────────────────────────────────────────────────────────────────────
#  Палитры Catppuccin — четыре варианта одной темы: mocha (тёмная, по умолчанию),
#  macchiato, frappe (тёмные помягче) и latte (светлая). Переключение: theme latte
#  Отсюда берут цвета профиль, подсветка ввода, fzf, шпаргалка и промпт oh-my-posh.
# ─────────────────────────────────────────────────────────────────────────────

$CatppuccinFlavors = [ordered]@{
    mocha = @{
        rosewater = 0xF5E0DC; flamingo = 0xF2CDCD; pink = 0xF5C2E7; mauve = 0xCBA6F7; red = 0xF38BA8; maroon = 0xEBA0AC
        peach = 0xFAB387; yellow = 0xF9E2AF; green = 0xA6E3A1; teal = 0x94E2D5; sky = 0x89DCEB; sapphire = 0x74C7EC
        blue = 0x89B4FA; lavender = 0xB4BEFE; text = 0xCDD6F4; subtext1 = 0xBAC2DE; subtext0 = 0xA6ADC8
        overlay2 = 0x9399B2; overlay1 = 0x7F849C; overlay0 = 0x6C7086; surface2 = 0x585B70; surface1 = 0x45475A
        surface0 = 0x313244; base = 0x1E1E2E; mantle = 0x181825; crust = 0x11111B; dark = $true
    }
    macchiato = @{
        rosewater = 0xF4DBD6; flamingo = 0xF0C6C6; pink = 0xF5BDE6; mauve = 0xC6A0F6; red = 0xED8796; maroon = 0xEE99A0
        peach = 0xF5A97F; yellow = 0xEED49F; green = 0xA6DA95; teal = 0x8BD5CA; sky = 0x91D7E3; sapphire = 0x7DC4E4
        blue = 0x8AADF4; lavender = 0xB7BDF8; text = 0xCAD3F5; subtext1 = 0xB8C0E0; subtext0 = 0xA5ADCB
        overlay2 = 0x939AB7; overlay1 = 0x8087A2; overlay0 = 0x6E738D; surface2 = 0x5B6078; surface1 = 0x494D64
        surface0 = 0x363A4F; base = 0x24273A; mantle = 0x1E2030; crust = 0x181926; dark = $true
    }
    frappe = @{
        rosewater = 0xF2D5CF; flamingo = 0xEEBEBE; pink = 0xF4B8E4; mauve = 0xCA9EE6; red = 0xE78284; maroon = 0xEA999C
        peach = 0xEF9F76; yellow = 0xE5C890; green = 0xA6D189; teal = 0x81C8BE; sky = 0x99D1DB; sapphire = 0x85C1DC
        blue = 0x8CAAEE; lavender = 0xBABBF1; text = 0xC6D0F5; subtext1 = 0xB5BFE2; subtext0 = 0xA5ADCE
        overlay2 = 0x949CBB; overlay1 = 0x838BA7; overlay0 = 0x737994; surface2 = 0x626880; surface1 = 0x51576D
        surface0 = 0x414559; base = 0x303446; mantle = 0x292C3C; crust = 0x232634; dark = $true
    }
    latte = @{
        rosewater = 0xDC8A78; flamingo = 0xDD7878; pink = 0xEA76CB; mauve = 0x8839EF; red = 0xD20F39; maroon = 0xE64553
        peach = 0xFE640B; yellow = 0xDF8E1D; green = 0x40A02B; teal = 0x179299; sky = 0x04A5E5; sapphire = 0x209FB5
        blue = 0x1E66F5; lavender = 0x7287FD; text = 0x4C4F69; subtext1 = 0x5C5F77; subtext0 = 0x6C6F85
        overlay2 = 0x7C7F93; overlay1 = 0x8C8FA1; overlay0 = 0x9CA0B0; surface2 = 0xACB0BE; surface1 = 0xBCC0CC
        surface0 = 0xCCD0DA; base = 0xEFF1F5; mantle = 0xE6E9EF; crust = 0xDCE0E8; dark = $false
    }
}

$ThemeFile = Join-Path $HOME '.config\terminal-setup\theme'

function Get-ThemeName {
    $name = if (Test-Path $ThemeFile) { (Get-Content $ThemeFile -First 1).Trim().ToLower() }
    if ($name -and $CatppuccinFlavors.Contains($name)) { $name } else { 'mocha' }
}

function ConvertTo-Hex([int]$Rgb) { '#{0:X6}' -f $Rgb }

# Схема Windows Terminal для варианта (как в официальном репозитории Catppuccin)
function Get-TerminalScheme([string]$Flavor) {
    $p = $CatppuccinFlavors[$Flavor]
    [ordered]@{
        name = "Catppuccin $((Get-Culture).TextInfo.ToTitleCase($Flavor))"
        background = ConvertTo-Hex $p.base; foreground = ConvertTo-Hex $p.text
        cursorColor = ConvertTo-Hex $p.rosewater; selectionBackground = ConvertTo-Hex $p.surface2
        black = ConvertTo-Hex $p.surface1; red = ConvertTo-Hex $p.red; green = ConvertTo-Hex $p.green; yellow = ConvertTo-Hex $p.yellow
        blue = ConvertTo-Hex $p.blue; purple = ConvertTo-Hex $p.mauve; cyan = ConvertTo-Hex $p.teal; white = ConvertTo-Hex $p.subtext1
        brightBlack = ConvertTo-Hex $p.surface2; brightRed = ConvertTo-Hex $p.red; brightGreen = ConvertTo-Hex $p.green; brightYellow = ConvertTo-Hex $p.yellow
        brightBlue = ConvertTo-Hex $p.blue; brightPurple = ConvertTo-Hex $p.mauve; brightCyan = ConvertTo-Hex $p.teal; brightWhite = ConvertTo-Hex $p.subtext0
    }
}

# Оформление окна Windows Terminal (вкладки, заголовок) под вариант
function Get-TerminalTheme([string]$Flavor) {
    $p = $CatppuccinFlavors[$Flavor]
    [ordered]@{
        name = "Catppuccin $((Get-Culture).TextInfo.ToTitleCase($Flavor))"
        tab = [ordered]@{ background = (ConvertTo-Hex $p.base) + 'FF'; unfocusedBackground = $null; showCloseButton = 'hover' }
        tabRow = [ordered]@{ background = (ConvertTo-Hex $p.mantle) + 'FF'; unfocusedBackground = (ConvertTo-Hex $p.crust) + 'FF' }
        window = [ordered]@{ applicationTheme = $(if ($p.dark) { 'dark' } else { 'light' }); useMica = $false }
    }
}
'@
$EmbeddedFiles['toolkit'] = @'
# ─────────────────────────────────────────────────────────────────────────────
#  Команды терминала. Подключается из профиля после palette.ps1.
#    help [тема|текст]   шпаргалка (help <командлет> — обычная справка PowerShell)
#    my [тема]           мои данные: sys, ssh, ports, ip, k8s, docker, tools, path, git, cmds
#    h [текст]           последние 50 команд, листаются по 10
#    jump [имя]          выбрать SSH-сервер и подключиться
#    srv install [хост]  поставить такой же bash на Linux-сервер
#    theme [вариант]     mocha · macchiato · frappe · latte
#    abbr [имя текст]    сокращения: g␣ → git␣
#    new имя.py          своя команда на любом языке (папка bin рядом с профилем)
#  Свои настройки и команды — в custom.ps1 рядом с профилем (ep открывает папку).
# ─────────────────────────────────────────────────────────────────────────────

function _tkRgb([int]$hex) { $PSStyle.Foreground.FromRgb($hex) }
function _tkBg([int]$hex) { $PSStyle.Background.FromRgb($hex) }

# ── Палитра → цвета вывода, подсветки ввода и fzf ────────────────────────────
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

# ── Шпаргалка: раздел → строки (команда, что делает, пример) ─────────────────
#  Строка, начинающаяся с клавиши (Ctrl+…, F1, ↑), в строку ввода не вставляется.
$TkSections = @(
    @{ Key = 'nav'; Title = 'Навигация'; Rows = @(
        , ('z <часть имени>', 'перейти в папку, где часто бываешь', 'z coding')
        , ('zi', 'то же, но выбрать из списка')
        , ('Alt+C', 'выбрать папку через fzf и перейти')
        , ('.. / ...', 'на уровень / два вверх')
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
    ) }
    @{ Key = 'search'; Title = 'Поиск'; Rows = @(
        , ('rg <текст>', 'найти текст во всех файлах папки', 'rg TODO -t py')
        , ('fd <имя>', 'найти файл по имени', 'fd docker-compose')
        , ('Ctrl+T', 'выбрать файл через fzf и вставить путь в строку')
    ) }
    @{ Key = 'keys'; Title = 'Клавиши'; Rows = @(
        , ('F1', 'эта шпаргалка с поиском — Enter вставляет команду')
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
        , ('начни печатать', 'до 50 подсказок из истории, ↑/↓ листать, Esc — скрыть')
        , ('g␣ k␣ d␣ dc␣', 'сокращения раскрываются сами: g → git', 'abbr — все')
        , ('abbr gcm ''git commit -m "%"''', 'своё сокращение, % — где оставить курсор')
        , ('вщслук зы ⏎', 'набрал в русской раскладке — исправится само')
        , ('h / h docker', 'последние 50 команд по 10 · с фильтром')
    ) }
    @{ Key = 'git'; Title = 'Git'; Rows = @(
        , ('gst', 'короткий статус')
        , ('lg', 'красивый лог, 30 коммитов', 'lg -n 100')
        , ('lazygit', 'git в полноэкранном интерфейсе: стейдж, коммиты, ветки')
        , ('git diff', 'дифф с подсветкой (delta), n/N — к след./пред. файлу')
        , ('gh pr create', 'пулл-реквест из терминала (gh — GitHub CLI)')
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
        , ('my ip', 'IP-адреса и шлюз · my ip public — внешний IP')
        , ('my tools', 'версии всех установленных инструментов')
    ) }
    @{ Key = 'mine'; Title = 'Своё'; Rows = @(
        , ('new имя.py', 'своя команда: py · ps1 · js · ts · sh · go · rs · clj', 'new weather.py')
        , ('my cmds', 'мои команды, функции и сокращения')
        , ('ep', 'открыть папку профиля в VS Code: custom.ps1, bin\')
        , ('theme [вариант]', 'mocha · macchiato · frappe · latte — на лету', 'theme latte')
        , ('reload', 'перечитать профиль после правок')
        , ('Update-Completions', 'обновить Tab-дополнения после обновления CLI')
    ) }
)

$TkNoInsert = '^(Ctrl|Alt|Shift|Win|Tab|F\d|↑|→|начни|набрал|вщслук|g␣)'

function Write-TkRow([string]$Command, [string]$Description, [string]$Example) {
    $cmdCell = if ($Command.Length -ge 26) { $Command + '  ' } else { $Command.PadRight(26) }
    $line = '    ' + $TK.cmd + $cmdCell + $TK.R + $TK.text + $Description + $TK.R
    if ($Example) { $line += '  ' + $TK.dim + $Example + $TK.R }
    Write-Host $line
}

# Раздел «Моё» строится на лету: команды из bin, функции из custom.ps1, сокращения
function Get-TkUserSection {
    $rows = @()
    foreach ($c in $global:UserCommands) { $rows += , ($c.Name, $c.Help, ("bin\" + $c.File)) }
    foreach ($f in $global:CustomFunctions) { $rows += , ($f, 'функция из custom.ps1') }
    if ($global:Abbreviations.Count) {
        $list = ($global:Abbreviations.GetEnumerator() | Select-Object -First 6 | ForEach-Object { "$($_.Key)→$($_.Value)" }) -join '  '
        if ($global:Abbreviations.Count -gt 6) { $list += "  … ещё $($global:Abbreviations.Count - 6)" }
        $rows += , ('abbr', $list, 'abbr — все')
    }
    if ($rows) { @{ Key = 'my'; Title = 'Моё'; Rows = $rows } }
}

function Get-TkAllSections { @($TkSections) + @(Get-TkUserSection) }

function Show-TkHelp($Sections) {
    if (-not $Sections) { $Sections = Get-TkAllSections }
    Write-Host ''
    Write-Host ("  {0}{1}✦ Что умеет мой терминал{2}  {3}тема: {4}{5}" -f $TK.title, $TK.B, $TK.R, $TK.dim, $global:ThemeName, $TK.R)
    Write-Host ("  {0}F1 — то же с поиском · help <тема> — раздел · help <текст> — поиск · my — мои данные{1}" -f $TK.dim, $TK.R)
    foreach ($s in $Sections) {
        Write-Host ''
        Write-Host ("  {0}{1}{2}{3}  {4}help {5}{6}" -f $TK.title, $TK.B, $s.Title, $TK.R, $TK.dim, $s.Key, $TK.R)
        foreach ($r in $s.Rows) { Write-TkRow @r }
    }
    Write-Host ''
}

function help {
    if (-not $args) { Show-TkHelp; return }
    $query = "$args"
    $all = Get-TkAllSections
    $section = $all | Where-Object { $_.Key -eq $query -or $_.Title -eq $query }
    if ($section) { Show-TkHelp $section; return }

    $hits = @(foreach ($s in $all) {
        foreach ($r in $s.Rows) { if (($r -join ' ').IndexOf($query, [StringComparison]::OrdinalIgnoreCase) -ge 0) { , $r } }
    })
    # командлеты PowerShell (Get-ChildItem, ls…) — в обычную справку, остальное — в шпаргалку
    $isCmdlet = Get-Command $query -CommandType Cmdlet, Alias -ErrorAction SilentlyContinue
    if ($hits -and $args.Count -eq 1 -and -not $isCmdlet) {
        Write-Host ''
        Write-Host ("  {0}{1}Нашлось в шпаргалке: {2}{3}" -f $TK.title, $TK.B, $query, $TK.R)
        foreach ($r in $hits) { Write-TkRow @r }
        Write-Host ''
        return
    }
    Get-Help @args
}

# F1: шпаргалка в fzf, Enter вставляет команду в строку ввода
function Invoke-HelpPicker {
    $lines = foreach ($s in Get-TkAllSections) {
        foreach ($r in $s.Rows) {
            $cmd = $r[0]; $desc = $r[1]
            $shown = '{0,-28} {1}' -f $cmd, $desc
            if ($r.Count -gt 2 -and $r[2]) { $shown += "   $($r[2])" }
            $insert = if ($cmd -match $TkNoInsert) { '' } else { ($cmd -split ' / | · | \[| <')[0].Trim() }
            "{0,-12}  {1}`t{2}" -f $s.Title, $shown, $insert
        }
    }
    $pick = $lines | fzf --height=60% --prompt='help ❯ ' --header='Enter — вставить команду в строку · Esc' --delimiter="`t" --with-nth=1 --tabstop=4
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    if ($pick) {
        $insert = ($pick -split "`t")[1]
        if ($insert) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($insert) }
    }
}

# ── Таблицы, заголовки, шкалы ────────────────────────────────────────────────
#  Columns: @{ N = заголовок; P = свойство; C = цвет из $TK или { param($row) 'цвет' } }
function Write-TkTable($Rows, $Columns) {
    $widths = foreach ($col in $Columns) {
        $max = $col.N.Length
        foreach ($r in $Rows) { $len = "$($r.($col.P))".Length; if ($len -gt $max) { $max = $len } }
        $max
    }
    $head = for ($i = 0; $i -lt $Columns.Count; $i++) { $Columns[$i].N.PadRight($widths[$i]) }
    Write-Host ('  ' + $TK.dim + ($head -join '   ') + $TK.R)
    foreach ($r in $Rows) {
        $cells = for ($i = 0; $i -lt $Columns.Count; $i++) {
            $col = $Columns[$i]
            $color = if ($col.C -is [scriptblock]) { $TK[(& $col.C $r)] } else { $TK[$col.C] }
            $color + "$($r.($col.P))".PadRight($widths[$i]) + $TK.R
        }
        Write-Host ('  ' + ($cells -join '   '))
    }
}

function Write-TkTitle([string]$Title, [string]$Hint) {
    Write-Host ''
    Write-Host ("  {0}{1}{2}{3}  {4}{5}{6}" -f $TK.title, $TK.B, $Title, $TK.R, $TK.dim, $Hint, $TK.R)
}

# Шкала: ████████░░░░ 67%  (зелёная до 70, жёлтая до 90, дальше красная)
function Get-TkBar([double]$Percent, [int]$Width = 20) {
    $filled = [math]::Round([math]::Min(100, [math]::Max(0, $Percent)) / 100 * $Width)
    $color = if ($Percent -ge 90) { $TK.err } elseif ($Percent -ge 70) { $TK.warn } else { $TK.ok }
    $color + ('█' * $filled) + $TK.dim + ('░' * ($Width - $filled)) + $TK.R + (' {0,3:N0}%' -f $Percent)
}

function Format-TkSize([double]$Bytes) {
    foreach ($u in 'Б', 'КБ', 'МБ', 'ГБ', 'ТБ') { if ($Bytes -lt 1024) { return ('{0:N1} {1}' -f $Bytes, $u) -replace '[.,]0 ', ' ' }; $Bytes /= 1024 }
    '{0:N1} ПБ' -f $Bytes
}

# Запуск внешней программы с лимитом времени (docker без Desktop может висеть десятки секунд)
function Invoke-WithTimeout([string]$Command, [string[]]$Arguments, [int]$Milliseconds = 3000) {
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

# ── SSH ──────────────────────────────────────────────────────────────────────
function Get-SshHost {
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
            # как в самом ssh: действует первое встретившееся значение
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

function Select-SshHost([string]$Query, [string]$Header) {
    $hosts = @(Get-SshHost)
    if (-not $hosts) { Write-Host '  ~/.ssh/config пуст'; return }
    $width = ($hosts.Name | Measure-Object Length -Maximum).Maximum
    $pick = $hosts | ForEach-Object { '{0}  {1}@{2}' -f $_.Name.PadRight($width), $_.User, $_.HostName } |
        fzf --query=$Query --select-1 --height=14 --header=$Header
    if ($pick) { ($pick -split '\s+')[0] }
}

function jump([string]$Query) {
    $name = Select-SshHost $Query 'Enter — подключиться · Esc — отмена'
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

# ── srv: такой же bash на серверах ───────────────────────────────────────────
#  Шаблоны: server\bashrc.local, inputrc, install.sh рядом с профилем.
#  server\custom\*.sh — свои файлы, уезжают на каждый сервер в ~/.bashrc.d/.
#  Всё за одно ssh-подключение — ufw limit на сервере не срабатывает.
function srv {
    param(
        [Parameter(Position = 0)][ValidateSet('install', 'remove', 'help')][string]$Action = 'help',
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [ArgumentCompleter({ param($c, $p, $word) (Get-SshHost).Name | Where-Object { $_ -like "$word*" } })]
        [string[]]$Hosts,
        [string]$Env          # метка в промпте: prod / staging / dev / none — убрать
    )
    $dir = Join-Path $global:ProfileDir 'server'
    if ($Action -eq 'help') { Show-SrvHelp $dir; return }
    foreach ($f in 'bashrc.local', 'inputrc', 'install.sh') {
        if (-not (Test-Path (Join-Path $dir $f))) { Write-Host "  $($TK.err)нет $dir\$f — запусти setup-terminal.ps1$($TK.R)"; return }
    }
    if ($Env -and $Env -notmatch '^[A-Za-z0-9_-]{1,20}$') {
        Write-Host "  $($TK.err)-Env: только буквы, цифры, - и _ (none — убрать метку)$($TK.R)"; return
    }
    if (-not $Hosts) {
        $picked = Select-SshHost '' "srv $Action — выбери сервер · Esc — отмена"
        if (-not $picked) { return }
        $Hosts = @($picked)
    }

    $read = { param($path) [IO.File]::ReadAllText($path) -replace "`r`n", "`n" }
    $b64 = { param($text) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)) }
    $custom = foreach ($f in Get-ChildItem (Join-Path $dir 'custom') -File -Filter *.sh -ErrorAction SilentlyContinue) {
        "__put '.bashrc.d/$($f.Name)' '$(& $b64 (& $read $f.FullName))'"
    }
    $script = (& $read (Join-Path $dir 'install.sh')).Replace('__ACTION__', $Action).Replace('__ENV__', $Env)
    $script = $script.Replace('__BASHRC_B64__', (& $b64 (& $read (Join-Path $dir 'bashrc.local'))))
    $script = $script.Replace('__INPUTRC_B64__', (& $b64 (& $read (Join-Path $dir 'inputrc'))))
    $script = $script.Replace('__CUSTOM_FILES__', ($custom -join "`n"))
    $script = $script.TrimEnd()      # PowerShell допишет перевод строки сам — пусть он попадёт в комментарий «# end»

    foreach ($h in $Hosts) {
        Write-TkTitle "srv $Action → $h" ''
        $script | ssh $h 'bash -s'
        if ($LASTEXITCODE -eq 0 -and $Action -eq 'remove') { Write-Host "  $($TK.ok)откачено$($TK.R) $($TK.dim)— вернуть: srv install $h$($TK.R)" }
        elseif ($LASTEXITCODE -eq 0) { Write-Host "  $($TK.ok)готово$($TK.R) $($TK.dim)— перезайди: ssh $h, затем help$($TK.R)" }
        else { Write-Host "  $($TK.err)ошибка (код $LASTEXITCODE) — на сервере ничего не менялось после этой точки$($TK.R)" }
        Write-Host ''
    }
}

function Show-SrvHelp([string]$Dir) {
    Write-TkTitle 'srv — такой же bash на серверах' "шаблоны: $Dir"
    Write-TkRow 'srv install [хост…]' 'поставить или обновить (без хоста — выбор из списка)' 'srv install myserver'
    Write-TkRow 'srv install <хост> -Env prod' 'то же + метка в промпте: prod / staging / dev / none'
    Write-TkRow 'srv remove [хост]' 'откатить: убрать подключение, файлы → *.off'
    Write-Host ''
    Write-Host "  $($TK.title)Что получает сервер$($TK.R)"
    Write-Host "    промпт как здесь (метка окружения, ветка, время долгой команды), большая история, ↑/↓ по началу, help, sys"
    Write-Host "    проекты находятся сами (docker compose ls): $($TK.cmd)<имя> · <имя> logs web · <имя> sh web · proj · app$($TK.R)"
    Write-Host "    защита: docker down -v / volume rm / prune просят yes; rm, cp, mv — подтверждение"
    Write-Host "    ничего в фоне и ничего не ставится — только файлы в домашней папке"
    Write-Host ''
    Write-Host "  $($TK.title)Свои команды для серверов$($TK.R)"
    Write-Host "    $($TK.cmd)$Dir\custom\*.sh$($TK.R) — уезжают на каждый сервер в ~/.bashrc.d/ при srv install"
    Write-Host "    строка $($TK.cmd)# help: имя — описание$($TK.R) в файле попадает в help на сервере"
    Write-Host "    на самом сервере: ~/.bashrc.d/*.sh и ~/bin/* — остаются при обновлении"
    Write-Host ''
    Write-Host "  $($TK.dim)Каждый запуск: бэкап, проверка до изменений, одно ssh-подключение. Повторный запуск ничего не ломает.$($TK.R)"
    Write-Host ''
}

# ── my ───────────────────────────────────────────────────────────────────────
$TkMyTopics = [ordered]@{
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
    keys   = 'горячие клавиши'
}

function my {
    param(
        [Parameter(Position = 0)][ArgumentCompleter({
            param($c, $p, $word) $TkMyTopics.get_Keys() | Where-Object { $_ -like "$word*" }
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
        'keys'   { Show-TkHelp ($TkSections | Where-Object { $_.Key -in 'keys', 'input' }) }
        default {
            Write-TkTitle 'my <тема>' 'Tab дополняет тему'
            # .get_Keys(): у словаря есть ключ 'keys', и .Keys вернул бы его значение
            foreach ($k in $TkMyTopics.get_Keys()) { Write-TkRow "my $k" $TkMyTopics[$k] }
            Write-Host ''
        }
    }
}

function Show-MySys {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $up = (Get-Date) - $os.LastBootUpTime
    Write-TkTitle $env:COMPUTERNAME ("работает {0} д {1} ч {2} мин · {3}" -f [int]$up.TotalDays, $up.Hours, $up.Minutes, $os.Caption.Replace('Microsoft ', ''))
    $cpuName = ($cpu.Name -replace '\s+', ' ' -replace '\(R\)|\(TM\)|CPU|Processor', '').Trim()
    $row = { param($label, $percent, $note) Write-Host ("  {0}{1}{2}  {3}  {4}{5}{6}" -f $TK.dim, $label.PadRight(10), $TK.R, (Get-TkBar $percent), $TK.dim, $note, $TK.R) }
    & $row 'процессор' $cpu.LoadPercentage "$cpuName · ядер: $([Environment]::ProcessorCount)"
    $memUsed = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB
    $memTotal = $os.TotalVisibleMemorySize * 1KB
    & $row 'память' ($memUsed / $memTotal * 100) "$(Format-TkSize $memUsed) из $(Format-TkSize $memTotal)"
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Sort-Object DeviceID) {
        if (-not $d.Size) { continue }
        $used = $d.Size - $d.FreeSpace
        & $row "диск $($d.DeviceID)" ($used / $d.Size * 100) "$(Format-TkSize $used) из $(Format-TkSize $d.Size)$(if ($d.VolumeName) { " · $($d.VolumeName)" })"
    }

    Write-Host ''
    Write-Host ("  {0}по памяти{1}" -f $TK.title, $TK.R)
    $top = Get-Process | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Memory = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum; Count = $_.Count }
    } | Sort-Object Memory -Descending | Select-Object -First 6
    foreach ($t in $top) {
        Write-Host ("  {0}{1,-26}{2} {3,9}{4}{5}" -f $TK.cmd, $t.Name, $TK.R, (Format-TkSize $t.Memory), $TK.dim, $(if ($t.Count -gt 1) { "  ×$($t.Count)" }), $TK.R)
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host ''
        Write-Host ("  {0}контейнеры{1}" -f $TK.title, $TK.R)
        $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}')
        if ($null -eq $rows) { Write-Host "  $($TK.dim)docker не отвечает — Docker Desktop выключен?$($TK.R)" }
        elseif (-not $rows) { Write-Host "  $($TK.dim)контейнеров нет$($TK.R)" }
        foreach ($r in $rows) {
            $name, $state = $r -split "`t"
            $dot = if ($state -match 'unhealthy|Restarting') { $TK.err } elseif ($state -like 'Up*') { $TK.ok } elseif ($state -like 'Exited (0)*') { $TK.dim } else { $TK.err }
            Write-Host ("  {0}●{1} {2,-30} {3}{4}{5}" -f $dot, $TK.R, $name, $TK.dim, $state, $TK.R)
        }
    }
    Write-Host ''
}

function Show-MyK8s {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { Write-Host "  $($TK.dim)kubectl не установлен$($TK.R)"; return }
    $rows = Invoke-WithTimeout kubectl @('config', 'get-contexts', '--no-headers') 5000
    Write-TkTitle 'Kubernetes' 'сменить: kubectl config use-context <имя> · namespace: kubectl config set-context --current --namespace <ns>'
    if (-not $rows) { Write-Host "  $($TK.dim)контекстов нет (kubeconfig пуст)$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $f = $r -split '\s+'
        $cur = $f[0] -eq '*'
        if ($cur) { $f = $f[1..($f.Count - 1)] }
        [pscustomobject]@{ Mark = $(if ($cur) { '●' } else { ' ' }); Name = $f[0]; Cluster = $f[1]; Namespace = $(if ($f.Count -gt 3) { $f[3] } else { 'default' }) }
    }
    Write-TkTable $list @(
        @{ N = ' '; P = 'Mark'; C = 'ok' }
        @{ N = 'Контекст'; P = 'Name'; C = { param($r) if ($r.Mark -eq '●') { 'cmd' } else { 'text' } } }
        @{ N = 'Кластер'; P = 'Cluster'; C = 'dim' }
        @{ N = 'Namespace'; P = 'Namespace'; C = 'accent' }
    )
    Write-Host ''
}

function Show-MyDocker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Write-Host "  $($TK.dim)docker не установлен$($TK.R)"; return }
    $rows = Invoke-WithTimeout docker @('ps', '-a', '--format', '{{.Names}}\t{{.Status}}\t{{.Ports}}')
    Write-TkTitle 'Docker' 'логи: docker logs -f <имя> · внутрь: docker exec -it <имя> sh'
    if ($null -eq $rows) { Write-Host "  $($TK.dim)docker не отвечает — Docker Desktop выключен?$($TK.R)"; Write-Host ''; return }
    $list = foreach ($r in $rows) {
        $name, $state, $ports = $r -split "`t"
        $ports = ($ports -replace '0\.0\.0\.0:|\[::\]:|/tcp', '' -split ', ' | Sort-Object -Unique) -join ' '
        [pscustomobject]@{ Dot = '●'; Name = $name; State = $state; Ports = $ports }
    }
    if (-not $list) { Write-Host "  $($TK.dim)контейнеров нет$($TK.R)" }
    else {
        Write-TkTable $list @(
            @{ N = ' '; P = 'Dot'; C = { param($r) if ($r.State -match 'unhealthy|Restarting') { 'err' } elseif ($r.State -like 'Up*') { 'ok' } elseif ($r.State -like 'Exited (0)*') { 'dim' } else { 'err' } } }
            @{ N = 'Контейнер'; P = 'Name'; C = 'cmd' }
            @{ N = 'Статус'; P = 'State'; C = 'dim' }
            @{ N = 'Порты'; P = 'Ports'; C = 'accent' }
        )
    }
    $projects = Invoke-WithTimeout docker @('compose', 'ls', '-a', '--format', '{{.Name}}\t{{.Status}}\t{{.ConfigFiles}}') 5000
    if ($projects) {
        Write-Host ''
        Write-Host ("  {0}compose-проекты{1}" -f $TK.title, $TK.R)
        foreach ($p in $projects) {
            $name, $state, $files = $p -split "`t"
            Write-Host ("  {0}{1,-20}{2} {3,-24} {4}{5}{6}" -f $TK.cmd, $name, $TK.R, $state, $TK.dim, (Split-Path ($files -split ',')[0]), $TK.R)
        }
    }
    Write-Host ''
}

function Show-MySsh([string]$Filter) {
    $hosts = @(Get-SshHost | Where-Object { -not $Filter -or "$($_.Name) $($_.HostName) $($_.User)" -like "*$Filter*" })
    Write-TkTitle 'SSH-хосты' 'подключиться: ssh <имя> · jump — выбрать из списка · ssh <Tab>'
    if (-not $hosts) { Write-Host "  $($TK.dim)ничего не найдено$($TK.R)"; Write-Host ''; return }
    Write-TkTable $hosts @(
        @{ N = 'Имя'; P = 'Name'; C = 'cmd' }
        @{ N = 'Адрес'; P = 'HostName'; C = 'text' }
        @{ N = 'Пользователь'; P = 'User'; C = { param($r) if ($r.User -eq 'root') { 'err' } else { 'ok' } } }
        @{ N = 'Порт'; P = 'Port'; C = 'dim' }
        @{ N = 'Ключ'; P = 'IdentityFile'; C = 'dim' }
    )
    foreach ($d in $hosts | Where-Object Duplicate) {
        Write-Host ("  {0}⚠ {1} описан в config несколько раз — ssh берёт значения из первого блока (User {2}){3}" -f $TK.warn, $d.Name, $d.User, $TK.R)
    }
    Write-Host ''
}

function Show-MyIp([string]$Mode) {
    $rows = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Sort-Object InterfaceMetric |
        ForEach-Object { [pscustomobject]@{ Interface = $_.InterfaceAlias; Address = "$($_.IPAddress)/$($_.PrefixLength)" } }
    Write-TkTitle 'IP-адреса' 'my ip public — внешний IP'
    Write-TkTable $rows @(@{ N = 'Интерфейс'; P = 'Interface'; C = 'text' }, @{ N = 'Адрес'; P = 'Address'; C = 'cmd' })
    $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
    if ($gw) { Write-Host ("  {0}шлюз{1}  {2} {3}({4}){5}" -f $TK.dim, $TK.R, $gw.NextHop, $TK.dim, $gw.InterfaceAlias, $TK.R) }
    if ($Mode -eq 'public') {
        try { $ip = Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5; Write-Host ("  {0}внешний{1}  {2}{3}{4}" -f $TK.dim, $TK.R, $TK.accent, $ip, $TK.R) }
        catch { Write-Host "  $($TK.err)не удалось узнать внешний IP$($TK.R)" }
    }
    Write-Host ''
}

function Show-MyPorts([string]$Filter) {
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
    Write-TkTitle 'Слушающие порты' 'my ports <порт|процесс> · my ports all — вместе с системными 49152+'
    Write-TkTable $rows @(
        @{ N = 'Порт'; P = 'Port'; C = 'accent' }
        @{ N = 'Процесс'; P = 'Process'; C = 'cmd' }
        @{ N = 'PID'; P = 'PID'; C = 'dim' }
        @{ N = 'Адрес'; P = 'Address'; C = 'dim' }
    )
    Write-Host ''
}

function Show-MyPath {
    $seen = @{}
    $rows = foreach ($p in $env:PATH -split ';' | Where-Object { $_ }) {
        $state = if ($seen.ContainsKey($p.TrimEnd('\'))) { 'дубль' } elseif (-not (Test-Path $p)) { 'нет папки' } else { '' }
        $seen[$p.TrimEnd('\')] = $true
        [pscustomobject]@{ Path = $p; State = $state }
    }
    Write-TkTitle 'PATH' 'порядок важен: побеждает папка выше'
    Write-TkTable $rows @(
        @{ N = 'Папка'; P = 'Path'; C = { param($r) if ($r.State) { 'dim' } else { 'text' } } }
        @{ N = ''; P = 'State'; C = { param($r) if ($r.State -eq 'дубль') { 'warn' } else { 'err' } } }
    )
    Write-Host ''
}

function Show-MyTools {
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
    Write-TkTitle 'Инструменты' 'обновить всё: winget upgrade --all'
    Write-TkTable $rows @(
        @{ N = 'Программа'; P = 'Name'; C = 'cmd' }
        @{ N = 'Версия'; P = 'Version'; C = 'ok' }
        @{ N = 'Где'; P = 'Path'; C = 'dim' }
    )
    Write-Host ''
}

function Show-MyGit {
    Write-TkTitle 'Git' ''
    Write-TkRow 'имя' (git config --global user.name)
    Write-TkRow 'почта' (git config --global user.email)
    $root = git rev-parse --show-toplevel 2>$null
    if ($root) {
        Write-TkRow 'репозиторий' $root
        Write-TkRow 'ветка' (git branch --show-current)
        foreach ($r in git remote -v | Where-Object { $_ -like '*(fetch)' }) {
            $name, $url = $r -split '\s+'
            Write-TkRow "remote $name" $url
        }
    } else {
        Write-Host "    $($TK.dim)сейчас не в git-репозитории$($TK.R)"
    }
    $aliases = git config --global --get-regexp '^alias\.' 2>$null
    foreach ($a in $aliases) { $k, $v = $a -split ' ', 2; Write-TkRow ('git ' + $k.Substring(6)) $v }
    Write-Host ''
}

function Show-MyCommands {
    Write-TkTitle 'Мои команды' "new имя.py — создать · ep — открыть папку · $($global:ProfileDir)"
    if ($global:UserCommands) {
        Write-Host ("  {0}bin\{1}" -f $TK.title, $TK.R)
        foreach ($c in $global:UserCommands) { Write-TkRow $c.Name $c.Help "$($c.File) · $($c.Runner)" }
    } else {
        Write-Host ("  {0}bin\ пуста — new weather.py 'погода' создаст первую команду{1}" -f $TK.dim, $TK.R)
    }
    if ($global:CustomFunctions) {
        Write-Host ''
        Write-Host ("  {0}custom.ps1{1}" -f $TK.title, $TK.R)
        foreach ($f in $global:CustomFunctions) { Write-TkRow $f ((Get-Command $f).Definition.Trim() -split "`n")[0].Trim() }
    }
    if ($global:Abbreviations.Count) {
        Write-Host ''
        Write-Host ("  {0}сокращения{1}  {2}abbr имя 'текст' — добавить · abbr -Remove имя{3}" -f $TK.title, $TK.R, $TK.dim, $TK.R)
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
    }
    Write-Host ''
}

# ── История ──────────────────────────────────────────────────────────────────
if (Test-Path Alias:h) { Remove-Item Alias:h -Force }   # встроенный h = Get-History
function h {
    param([string]$Filter, [int]$Count = 50, [int]$PageSize = 10)
    $path = (Get-PSReadLineOption).HistorySavePath
    if (-not (Test-Path $path)) { return }

    # многострочные команды хранятся построчно с ` в конце — склеиваем
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

    $title = if ($Filter) { "История: «$Filter»" } else { 'История' }
    Write-TkTitle $title "новые сверху · Ctrl+R — поиск с вставкой в строку"
    $paging = -not [Console]::IsInputRedirected
    for ($i = 0; $i -lt $list.Count; $i++) {
        $lines = $list[$i] -split "`n"
        $text = $lines[0]
        if ($Filter) { $text = $text -ireplace [regex]::Escape($Filter), ($TK.accent + '$0' + $TK.R) }
        if ($lines.Count -gt 1) { $text += "  $($TK.dim)… +$($lines.Count - 1) стр.$($TK.R)" }
        Write-Host ("  {0}{1,3}{2}  {3}" -f $TK.dim, ($i + 1), $TK.R, $text)

        if ($paging -and ($i + 1) % $PageSize -eq 0 -and $i + 1 -lt $list.Count) {
            Write-Host -NoNewline ("  {0}── {1}/{2} · Enter или Пробел — ещё · Q/Esc — хватит ──{3}" -f $TK.dim, ($i + 1), $list.Count, $TK.R)
            $key = [Console]::ReadKey($true).Key
            Write-Host -NoNewline "`r$([char]27)[2K"
            if ($key -in 'Q', 'Escape') { break }
        }
    }
    if (-not $list.Count) { Write-Host "  $($TK.dim)ничего не найдено$($TK.R)" }
    Write-Host ''
}

# ── Сокращения: g␣ → git␣ (как abbr в fish) ──────────────────────────────────
#  Раскрываются по пробелу и Enter только в позиции команды, поэтому в истории
#  остаются полные команды. % в тексте — куда поставить курсор.
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
        Write-TkTitle 'Сокращения' 'раскрываются по пробелу · abbr имя ''текст'' — добавить · abbr -Remove имя'
        foreach ($a in $global:Abbreviations.GetEnumerator()) { Write-TkRow "$($a.Key)␣" $a.Value }
        Write-Host ''
        return
    }
    if (-not $Expansion) { Write-Host "  $($TK.err)abbr имя 'во что раскрыть'$($TK.R)"; return }
    $global:Abbreviations[$Name] = $Expansion
    # интерактивно — запоминаем в custom.ps1 (при загрузке профиля строка уже там)
    if ($MyInvocation.ScriptName -eq '' -and $global:isInteractive) {
        $line = "abbr $Name '$($Expansion.Replace("'", "''"))'"
        if (-not (Test-Path $custom) -or -not (Select-String -Path $custom -SimpleMatch $line -Quiet)) {
            Add-Content $custom "`n$line" -Encoding utf8
            Write-Host ("  {0}записано в custom.ps1: {1}{2}" -f $TK.dim, $line, $TK.R)
        }
    }
}

# Что раскрыть в строке $Line при курсоре $Cursor: @{Start; Length; Text; Cursor} или $null
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

abbr g   'git'
abbr k   'kubectl'
abbr d   'docker'
abbr dc  'docker compose'
abbr gco 'git checkout'
abbr gp  'git push'
abbr gl  'git pull'
abbr gcm 'git commit -m "%"'
abbr kgp 'kubectl get pods'
abbr kga 'kubectl get all'

# ── Русская раскладка: «вщслук зы» → «docker ps» ─────────────────────────────
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

# Исправленная строка, если первое слово набрано кириллицей и после перевода — известная команда
function Repair-CommandLayout([string]$Line) {
    if ($Line -notmatch '^\s*[А-Яа-яЁё]') { return }
    $first = ($Line.Trim() -split '\s+', 2)[0]
    if (Get-Command $first -ErrorAction SilentlyContinue) { return }       # настоящая команда с кириллицей
    $fixed = Convert-Layout $first
    if ($fixed -eq $first) { return }
    if (-not (Get-Command $fixed -ErrorAction SilentlyContinue) -and -not $global:Abbreviations.ContainsKey($fixed)) { return }
    Convert-Layout $Line
}

# ── Свои команды на любом языке: bin\ рядом с профилем ───────────────────────
#  weather.py → команда weather. Первая строка «# help: …» попадает в help.
#  Для каждого расширения — чем запускать (первый найденный):
$global:ScriptRunners = [ordered]@{
    '.ps1' = @('pwsh -NoProfile -File')
    '.py'  = @('uv run', 'python')          # uv: зависимости прямо в файле (# /// script … ///)
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
    if (($env:PATH -split ';') -notcontains $Dir) { $env:PATH = "$Dir;$env:PATH" }   # .exe и .cmd — как есть
    foreach ($f in Get-ChildItem $Dir -File | Sort-Object Name) {
        $name = $f.BaseName
        $ext = $f.Extension.ToLower()
        if (-not $global:ScriptRunners.Contains($ext) -or $name -notmatch '^[A-Za-z_][\w-]*$') { continue }
        # имя занято настоящей командой (не нашей функцией и не файлом из bin) — не перекрываем
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
            "# UserCommand`nWrite-Host '  нечем запустить $($f.Name): нужен $($global:ScriptRunners[$ext] -join ' или ')'"
        }
        Set-Item "Function:global:$name" -Value ([scriptblock]::Create($body))
        $global:UserCommands += [pscustomobject]@{ Name = $name; File = $f.Name; Help = $help; Runner = $(if ($runner) { $runner } else { 'нет: ' + ($global:ScriptRunners[$ext] -join '/') }); Path = $f.FullName }
    }
}

$TkTemplates = @{
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
    '.php' = "<?php\n// help: {desc}`necho 'hello from {name}: ', implode(' ', array_slice(`$argv, 1)), PHP_EOL;`n"
}

function new {
    param([Parameter(Position = 0)][string]$FileName, [Parameter(Position = 1)][string]$Description = 'моя команда')
    $bin = Join-Path $global:ProfileDir 'bin'
    if (-not $FileName) {
        Write-TkTitle 'new имя.расширение [описание]' "создаёт команду в $bin"
        foreach ($ext in $global:ScriptRunners.Keys) {
            $runner = Get-ScriptRunner $ext
            Write-TkRow "new имя$ext" $(if ($runner) { "запуск: $runner" } else { "нужен $($global:ScriptRunners[$ext] -join ' или ')" }) $(if ($runner) { '' } else { 'не установлен' })
        }
        Write-Host ''
        return
    }
    $ext = [IO.Path]::GetExtension($FileName).ToLower()
    $name = [IO.Path]::GetFileNameWithoutExtension($FileName)
    if (-not $TkTemplates.ContainsKey($ext)) { Write-Host "  $($TK.err)не знаю расширение $ext — new без аргументов покажет список$($TK.R)"; return }
    if ($name -notmatch '^[A-Za-z_][\w-]*$') { Write-Host "  $($TK.err)имя: латиница, цифры, - и _$($TK.R)"; return }
    $taken = Get-Command $name -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notlike "$bin\*" -and $_.ScriptBlock -notlike '*UserCommand*' } | Select-Object -First 1
    if ($taken) { Write-Host "  $($TK.err)имя $name уже занято ($($taken.CommandType) $($taken.Source))$($TK.R)"; return }
    New-Item -ItemType Directory -Force $bin | Out-Null
    $path = Join-Path $bin "$name$ext"
    if (-not (Test-Path $path)) {
        $text = $TkTemplates[$ext].Replace('{desc}', $Description).Replace('{name}', $name)
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
        Write-Host ("  {0}✓ {1}{2}" -f $TK.ok, $path, $TK.R)
    }
    Register-BinCommands $bin
    $runner = Get-ScriptRunner $ext
    if ($runner) { Write-Host ("  {0}команда готова: {1}{2} [аргументы]{3}  {4}запуск через {5}{6}" -f $TK.dim, $TK.cmd, $name, $TK.R, $TK.dim, $runner, $TK.R) }
    else { Write-Host ("  {0}чтобы запускать, нужен {1}{2}" -f $TK.warn, ($global:ScriptRunners[$ext] -join ' или '), $TK.R) }
    if (Get-Command code -ErrorAction SilentlyContinue) { code $path }
}

# ── Тема ─────────────────────────────────────────────────────────────────────
function Get-TerminalSettingsPaths {
    $paths = foreach ($pkg in 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') {
        Join-Path $env:LOCALAPPDATA "Packages\$pkg\LocalState\settings.json"
    }
    $paths += Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    $paths | Where-Object { Test-Path $_ }
}

function theme {
    param([Parameter(Position = 0)][ArgumentCompleter({ param($c, $p, $word) $CatppuccinFlavors.Keys | Where-Object { $_ -like "$word*" } })][string]$Name)
    if (-not $Name) {
        Write-TkTitle 'Тема' 'theme <вариант> — переключить всё сразу: терминал, промпт, подсветку'
        foreach ($f in $CatppuccinFlavors.Keys) {
            $p = $CatppuccinFlavors[$f]
            $swatch = ($p.red, $p.peach, $p.yellow, $p.green, $p.teal, $p.blue, $p.mauve | ForEach-Object { (_tkRgb $_) + '●' }) -join ' '
            $mark = if ($f -eq $global:ThemeName) { $TK.ok + '● ' } else { '  ' }
            Write-Host ("  {0}{1}{2,-10}{3} {4}{5}  {6}{7}{8}" -f $mark, $TK.cmd, $f, $TK.R, $swatch, $TK.R, $TK.dim, $(if ($p.dark) { 'тёмная' } else { 'светлая' }), $TK.R)
        }
        Write-Host ''
        return
    }
    $Name = $Name.ToLower()
    if (-not $CatppuccinFlavors.Contains($Name)) { Write-Host "  $($TK.err)есть только: $($CatppuccinFlavors.Keys -join ', ')$($TK.R)"; return }
    New-Item -ItemType Directory -Force (Split-Path $ThemeFile) | Out-Null
    [IO.File]::WriteAllText($ThemeFile, "$Name`n")
    $global:ThemeName = $Name
    $global:Palette = $CatppuccinFlavors[$Name]
    $env:TERMINAL_THEME = $Name
    Set-TerminalPalette
    $title = "Catppuccin $((Get-Culture).TextInfo.ToTitleCase($Name))"
    foreach ($path in Get-TerminalSettingsPaths) {
        $raw = [IO.File]::ReadAllText($path)
        $new = $raw -replace '("colorScheme"\s*:\s*)"Catppuccin [A-Za-z]+"', "`$1`"$title`"" -replace '("theme"\s*:\s*)"Catppuccin [A-Za-z]+"', "`$1`"$title`""
        if ($new -ne $raw) { [IO.File]::WriteAllText($path, $new, [Text.UTF8Encoding]::new($false)) }
    }
    Write-Host ("  {0}✓ {1}{2}  {3}Windows Terminal переключится сам, новые вкладки — тоже{4}" -f $TK.ok, $title, $TK.R, $TK.dim, $TK.R)
}

function ep { code $global:ProfileDir }
'@
$EmbeddedFiles['custom'] = @'
# ─────────────────────────────────────────────────────────────────────────────
#  custom.ps1 — моё. Этот файл setup-terminal.ps1 никогда не перезаписывает.
#  Загружается после toolkit.ps1, до клавиш и промпта. Проверить: reload
#
#  Переключатели:
#    $TerminalSetup.Abbreviations = $false   # отключить g␣ → git␣
#    $TerminalSetup.LayoutFix     = $false   # отключить исправление раскладки
#    $TerminalSetup.Predictions   = 20       # подсказок из истории (0 — стандартные 10)
#
#  Сокращения (раскрываются по пробелу, % — где оставить курсор):
#    abbr gcm 'git commit -m "%"'
#    abbr -Remove d
#
#  Свои функции — попадут в help и my cmds автоматически:
#    function deploy { ssh prod 'cd app && git pull && docker compose up -d' }
#
#  Команды на других языках — файлы в bin\ рядом с этим файлом (new имя.py).
#  Строка «# help: описание» в начале файла — подпись в help.
#
#  Чем запускать расширения (первый найденный): $ScriptRunners['.ts'] = @('bun', 'node')
# ─────────────────────────────────────────────────────────────────────────────
'@
$EmbeddedFiles['predictor'] = @'
// Подсказки из истории PSReadLine без встроенного лимита в 10 строк.
// Встроенный источник History жёстко ограничен 10 записями, а плагины получают
// до 50 — список показывает 10 строк и листается стрелками.
// Компилируется профилем в ~/.cache/pwsh-predictor при изменении этого файла.

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
        // сначала команды, которые начинаются с набранного, потом — где оно встречается внутри
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

    // PSReadLine ждёт плагин ~20 мс, поэтому файл перечитывается в фоне
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
            // многострочные команды хранятся строками с ` на конце — их пропускаем целиком
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
# ~/.bashrc.local — один и тот же для всех серверов. Ставится из PowerShell: srv install <хост>
# version: 2.0.0
#
#  Настройки сервера:  ~/.config/bashrc-local.conf   (PROMPT_ENV=prod …)
#  Своё:               ~/.bashrc.d/*.sh — подключаются в конце, остаются при обновлении
#                      ~/bin/*          — свои скрипты, строка «# help: …» попадает в help
#  Проекты находятся сами (docker compose ls) и запоминаются в ~/.config/projects,
#  для каждого появляется команда с его именем:  myapp · myapp logs web · myapp sh web
#  Ничего не ставится и ничего не работает в фоне — только функции в этой оболочке.
#  Откат: srv remove <хост>  (или удалить строку с .bashrc.local в конце ~/.bashrc)

[[ $- == *i* ]] || return     # для scp/rsync/скриптов — ничего не делаем и ничего не печатаем

PROMPT_ENV=''                 # метка в промпте: prod — красная, staging/test — жёлтая, dev — зелёная
[[ -f ~/.config/bashrc-local.conf ]] && . ~/.config/bashrc-local.conf

# ── История: большая, без дублей, с датой, общая между вкладками ─────────────
# Команда, начатая с пробела, в историю не попадает — удобно для паролей/токенов.
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '
HISTIGNORE='ls:ll:la:pwd:exit:clear:history:h'
shopt -s histappend cmdhist checkwinsize globstar

# ── Промпт ───────────────────────────────────────────────────────────────────
#  ┌─ ● prod deploy@vm1 ~/app ⎇ main*  ⏱ 12s  ✘ 1
#  └─❯
__git_branch() {
    local b dirty=
    # GIT_OPTIONAL_LOCKS=0 — промпт не берёт index.lock и не мешает деплою
    b=$(GIT_OPTIONAL_LOCKS=0 git symbolic-ref --short HEAD 2>/dev/null || GIT_OPTIONAL_LOCKS=0 git rev-parse --short HEAD 2>/dev/null) || return
    [[ -n $(GIT_OPTIONAL_LOCKS=0 git status --porcelain --untracked-files=no 2>/dev/null | head -n1) ]] && dirty='*'
    printf ' ⎇ %s%s' "$b" "$dirty"
}

# Время долгой команды: ловушка DEBUG запоминает старт первой команды после промпта.
# Срабатывает только на верхнем уровне (внутри функций — нет), стоит микросекунды.
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

    local user=$cyan;  (( EUID == 0 )) && user=$red     # root — красным
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

# ── Цвета в выводе ───────────────────────────────────────────────────────────
export LESS='-R -F -X -i'
export LESS_TERMCAP_md=$'\e[1;34m' LESS_TERMCAP_me=$'\e[0m'      # man: заголовки
export LESS_TERMCAP_us=$'\e[4;32m' LESS_TERMCAP_ue=$'\e[0m'      # man: подчёркнутое
export LESS_TERMCAP_so=$'\e[30;43m' LESS_TERMCAP_se=$'\e[0m'     # поиск/статус
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah --color=auto --group-directories-first --time-style=long-iso'
alias la='ls -A'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'

# ── Подстраховка (только для ручного ввода, скрипты не затрагивает) ──────────
alias rm='rm -I'              # спросит, если удаляется больше 3 файлов или рекурсивно
alias cp='cp -i'              # спросит перед перезаписью
alias mv='mv -i'

# ── Удобства ─────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias df='df -h'
alias free='free -h'
alias du1='du -h --max-depth=1 2>/dev/null | sort -h'
alias ports='ss -tulpn'
mkcd() { mkdir -p "$1" && cd "$1"; }
psg() { ps aux | grep -i --color=auto -- "[${1:0:1}]${1:1}"; }                 # psg nginx — процессы по имени
bak() { local f; for f in "$@"; do command cp -a "$f" "$f.bak-$(date +%Y%m%d-%H%M%S)" && echo "→ $f.bak-$(date +%Y%m%d-%H%M%S)"; done; }
ex() {                                                                       # ex архив — распаковать что угодно
    [[ -f $1 ]] || { echo "нет файла: $1"; return 1; }
    case $1 in
        *.tar.gz|*.tgz)  tar xzf "$1" ;;   *.tar.xz|*.txz) tar xJf "$1" ;;   *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar|*.tar.zst) tar xf "$1" ;;    *.gz)  gunzip -k "$1" ;;          *.bz2) bunzip2 -k "$1" ;;
        *.xz)  unxz -k "$1" ;;             *.zip) unzip -q "$1" ;;           *.7z)  7z x "$1" ;;
        *) echo "не знаю, чем распаковать: $1"; return 1 ;;
    esac
}
h() {                                                                        # h [текст] — последние команды
    if (( $# )); then history | grep -i -- "$*" | tail -n 30
    else history | tail -n 50; fi
}

# Дополнить строку пробелами до ширины n в символах (printf %-Ns считает байты и ломает кириллицу)
__pad() { local s=$1 n=$(( $2 - ${#1} )); (( n < 1 )) && n=1; printf '%s%*s' "$s" "$n" ''; }

# Цветная точка по статусу контейнера
__dot() {
    case $1 in
        *unhealthy*|Restarting*) printf '\e[31m●\e[0m' ;;
        Up*starting*)            printf '\e[33m●\e[0m' ;;
        Up*)                     printf '\e[32m●\e[0m' ;;
        'Exited (0)'*|Created*)  printf '\e[90m●\e[0m' ;;   # завершился штатно (migrate и т.п.)
        *)                       printf '\e[31m●\e[0m' ;;
    esac
}

# ── Docker ───────────────────────────────────────────────────────────────────
if command -v docker >/dev/null; then
    # Команды, которые удаляют тома (а значит базы), требуют набрать yes
    docker() {
        local args=" $* "
        local wipe_volumes=' down .*(-v|--volumes) ' remove_volumes=' volume (rm|prune) ' prune=' system prune '
        if [[ $args =~ $wipe_volumes || $args =~ $remove_volumes || $args =~ $prune ]]; then
            printf '\e[1;31m⚠ %s: «docker %s» удалит данные (тома, базы).\e[0m\n' "${PROMPT_ENV:-$(hostname)}" "$*"
            local answer
            read -r -p 'Напиши yes, чтобы продолжить: ' answer
            [[ $answer == yes ]] || { echo 'Отменено.'; return 1; }
        fi
        command docker "$@"
    }
    alias dc='docker compose'
    alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    alias dlogs='docker compose logs -f --tail=200'
fi

# ── Проекты ──────────────────────────────────────────────────────────────────
#  proj                     список: статус и папка
#  <имя> | proj <имя>       статус контейнеров проекта
#  <имя> logs [сервис]      логи: последние 200 строк и дальше поток
#  <имя> sh <сервис>        shell внутри контейнера
#  <имя> cd  ·  app [имя]   перейти в папку проекта
#  <имя> <что угодно>       docker compose <что угодно> в папке проекта
#  proj add [имя] [папка]   добавить вручную (по умолчанию — текущая папка)
#  proj rm <имя>            скрыть из списка
PROJ_FILE=~/.config/projects                     # строки «имя<TAB>папка», папка «-» — скрыт
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
            # запоминаем — команда останется и после «down»
            mkdir -p "${PROJ_FILE%/*}" && printf '%s\t%s\n' "$name" "$dir" >> "$PROJ_FILE"
        fi
    done
}

# Команда с именем проекта: myapp ps. Не создаётся, если имя уже занято (git, nginx…) — тогда proj <имя>.
__proj_define() {
    local name
    for name in "${!PROJ_DIR[@]}"; do
        [[ $name =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] || continue
        if [[ -z ${__PROJ_FUNCS[$name]} ]] && type -t "$name" >/dev/null; then continue; fi
        eval "$name() { proj $name \"\$@\"; }"
        complete -F __proj_complete "$name"
        __PROJ_FUNCS[$name]=1
    done
    for name in "${!__PROJ_FUNCS[@]}"; do       # проект скрыт или удалён — убираем его команду
        [[ -n ${PROJ_DIR[$name]} ]] && continue
        unset -f "$name"; complete -r "$name" 2>/dev/null; unset "__PROJ_FUNCS[$name]"
    done
}

# Проект, в папке которого мы сейчас; если проект один — он
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
    printf '\n  %sПроекты%s  %sproj add — добавить текущую папку · proj rm <имя> — скрыть%s\n' "$t" "$r" "$d" "$r"
    if (( ${#PROJ_DIR[@]} == 0 )); then
        printf '  %sпока нет: запусти docker compose up в папке проекта или proj add%s\n\n' "$d" "$r"; return
    fi
    for name in $(printf '%s\n' "${!PROJ_DIR[@]}" | sort); do
        state=${PROJ_STATUS[$name]:-не запущен}
        case $state in *running*) dot=$'\e[32m●' ;; не*) dot=$'\e[90m○' ;; *) dot=$'\e[33m●' ;; esac
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
    printf '  %s%s logs <сервис> · %s sh <сервис> · %s restart <сервис> · %s cd%s\n\n' "$d" "$cmd" "$cmd" "$cmd" "$cmd" "$r"
}

proj() {
    local name=$1
    case $name in
        ''|ls) __proj_list; return ;;
        add)
            local dir=${3:-$PWD}
            dir=$(cd "$dir" 2>/dev/null && pwd) || { echo "нет папки: ${3:-$PWD}"; return 1; }
            name=${2:-${dir##*/}}
            [[ $name =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "плохое имя: $name"; return 1; }
            mkdir -p "${PROJ_FILE%/*}"
            { [[ -f $PROJ_FILE ]] && awk -F'\t' -v n="$name" '$1 != n' "$PROJ_FILE"; printf '%s\t%s\n' "$name" "$dir"; } > "$PROJ_FILE.tmp" &&
                command mv -f "$PROJ_FILE.tmp" "$PROJ_FILE"
            __proj_load; __proj_define
            echo "добавлен: $(__proj_cmd "$name") → $dir"; return ;;
        rm)
            name=$2
            [[ -n $name ]] || { echo 'укажи имя: proj rm <имя>'; return 1; }
            mkdir -p "${PROJ_FILE%/*}"
            { [[ -f $PROJ_FILE ]] && awk -F'\t' -v n="$name" '$1 != n' "$PROJ_FILE"; printf '%s\t-\n' "$name"; } > "$PROJ_FILE.tmp" &&
                command mv -f "$PROJ_FILE.tmp" "$PROJ_FILE"
            __proj_load; __proj_define
            echo "скрыт: $name (вернуть: proj add $name <папка>)"; return ;;
    esac

    local dir=${PROJ_DIR[$name]}
    [[ -n $dir ]] || { echo "нет проекта «$name» — список: proj"; return 1; }
    shift
    case $1 in
        '')   __proj_status "$name" ;;
        cd)   cd "$dir" ;;
        sh)   [[ -n $2 ]] || { echo "укажи сервис: $(__proj_cmd "$name") sh <Tab>"; return 1; }
              (cd "$dir" && command docker compose exec "$2" sh -c 'command -v bash >/dev/null && exec bash || exec sh') ;;
        logs) shift
              [[ $1 == -* ]] || set -- -f --tail=200 "$@"     # свои флаги — как есть
              (cd "$dir" && command docker compose logs "$@") ;;
        *)    (cd "$dir" && docker compose "$@") ;;          # через docker() — с защитой от down -v
    esac
}

__proj_services() {     # кладёт список сервисов в __svc (кэш на сессию)
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

app() {                 # app — в папку текущего/единственного проекта, app <имя> — в папку проекта
    local name=${1:-$(__proj_current)}
    [[ -n $name ]] || { __proj_list; return; }
    proj "$name" cd
}
dsh() {                 # dsh <сервис> — shell в контейнере текущего/единственного проекта
    local name; name=$(__proj_current)
    [[ -n $name ]] || { echo 'проектов несколько — зайди в папку проекта или: <проект> sh <сервис>'; return 1; }
    proj "$name" sh "$1"
}
__app_complete() { COMPREPLY=($(compgen -W "${!PROJ_DIR[*]}" -- "${COMP_WORDS[COMP_CWORD]}")); }
__dsh_complete() {
    local name; name=$(__proj_current); [[ -n $name ]] || return
    __proj_services "$name"; COMPREPLY=($(compgen -W "$__svc" -- "${COMP_WORDS[COMP_CWORD]}"))
}
complete -F __app_complete app
complete -F __dsh_complete dsh

# ── Состояние сервера ────────────────────────────────────────────────────────
__bar() {       # __bar 67 → ████████████░░░░░░░░  67%
    local p=${1%.*} w=${2:-20} c=$'\e[32m'
    (( p >= 90 )) && c=$'\e[31m' || { (( p >= 70 )) && c=$'\e[33m'; }
    local filled=$(( p * w / 100 ))
    printf '%s' "$c"; printf '█%.0s' $(seq 1 $filled 2>/dev/null); printf '\e[90m'; printf '░%.0s' $(seq 1 $((w - filled)) 2>/dev/null)
    printf '\e[0m %3d%%' "$p"
}

sys() {
    local t=$'\e[1;35m' d=$'\e[90m' r=$'\e[0m' name state
    printf '\n  %s%s%s  %s%s · %s%s\n' "$t" "$(hostname)" "$r" "$d" "$(uptime -p)" "${PROMPT_ENV:-без метки}" "$r"
    local load; load=$(cut -d' ' -f1 /proc/loadavg)
    printf '  %sнагрузка%s   %s  %s%s · ядер: %s%s\n' "$d" "$r" "$(__bar "$(awk -v l="$load" -v n="$(nproc)" 'BEGIN{printf "%d", l/n*100}')")" "$d" "$(cut -d' ' -f1-3 /proc/loadavg)" "$(nproc)" "$r"
    # command — иначе подставятся алиасы free -h / df -h, объявленные выше
    command free -b | awk -v d="$d" -v r="$r" '/^Mem:/ {printf "  %sпамять%s     __BAR__%d  %s%.1f из %.1f ГБ%s\n", d, r, ($2-$7)/$2*100, d, ($2-$7)/1073741824, $2/1073741824, r}' |
        while IFS= read -r line; do local pct=${line#*__BAR__}; pct=${pct%%  *}; printf '%s%s%s\n' "${line%%__BAR__*}" "$(__bar "$pct")" "${line#*__BAR__$pct}"; done
    command df -P / | awk -v d="$d" -v r="$r" 'NR==2 {gsub("%","",$5); printf "  %sдиск /%s     __BAR__%d  %s%.0f из %.0f ГБ%s\n", d, r, $5, d, $3/1048576, $2/1048576, r}' |
        while IFS= read -r line; do local pct=${line#*__BAR__}; pct=${pct%%  *}; printf '%s%s%s\n' "${line%%__BAR__*}" "$(__bar "$pct")" "${line#*__BAR__$pct}"; done

    printf '\n  %sтоп процессов%s\n' "$t" "$r"
    ps -eo comm,%cpu,%mem --sort=-%cpu --no-headers | head -n 5 |
        awk -v c=$'\e[34m' -v d="$d" -v r="$r" '{printf "  %s%-26s%s %scpu %5.1f%%   mem %5.1f%%%s\n", c, $1, r, d, $2, $3, r}'

    if command -v docker >/dev/null; then
        printf '\n  %sконтейнеры%s\n' "$t" "$r"
        command docker ps -a --format '{{.Names}}'$'\t''{{.Status}}' | while IFS=$'\t' read -r name state; do
            printf '  %s %-30s %s%s%s\n' "$(__dot "$state")" "$name" "$d" "$state" "$r"
        done
    fi
    echo
}

# ── Шпаргалка: help · help <слово> — поиск · help <встроенная команда> — справка bash
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

    __help_section 'Проекты  (находятся сами: docker compose ls)'
    __help_row 'proj' 'все проекты: статус и папка'
    __help_row '<проект>' 'статус контейнеров' "$p"
    __help_row '<проект> logs [сервис]' 'логи: 200 строк и дальше поток' "$p logs web"
    __help_row '<проект> sh <сервис>' 'shell внутри контейнера' "$p sh web"
    __help_row '<проект> <команда>' 'любая docker compose команда' "$p restart web"
    __help_row '<проект> cd · app' 'перейти в папку проекта' "app $ex"
    __help_row 'dsh <сервис>' 'shell в контейнере проекта, где ты сейчас'
    __help_row 'proj add [имя] [папка]' 'добавить вручную (по умолчанию — текущую)'
    __help_row 'proj rm <имя>' 'скрыть из списка'
    __help_section 'Docker'
    __help_row 'dps' 'все контейнеры: статус и порты'
    __help_row 'dc · dlogs' 'docker compose / логи в текущей папке'
    __help_section 'Сервер'
    __help_row 'sys' 'нагрузка, память, диск, процессы, контейнеры'
    __help_row 'ports' 'кто слушает порты'
    __help_row 'psg <имя>' 'процессы по имени' 'psg nginx'
    __help_row 'df · free · du1' 'диск · память · размер папок здесь'
    __help_section 'Файлы'
    __help_row 'll · la' 'подробный список · со скрытыми'
    __help_row 'bak <файл>' 'копия рядом: файл.bak-дата — перед правкой на проде' 'bak .env'
    __help_row 'ex <архив>' 'распаковать: tar.gz, zip, xz, 7z…'
    __help_row '.. · ... · mkcd <папка>' 'вверх · два вверх · создать и зайти'
    __help_section 'История и ввод'
    __help_row 'h · h <текст>' 'последние 50 команд · поиск'
    __help_row 'начало команды + ↑/↓' 'листать только подходящие из истории'
    __help_row 'Ctrl+R' 'поиск по всей истории'
    __help_row 'Tab' 'дополнение без учёта регистра (и сервисов)'
    __help_row ' команда (с пробелом)' 'не сохранится в историю — для паролей'
    __help_section 'Подстраховка'
    __help_row 'rm · cp · mv' 'спрашивают перед массовым удалением'
    __help_row 'down -v · volume rm · prune' 'docker требует набрать yes'
    __help_row '\rm …' 'без подтверждения (обход алиаса)'
    __help_row '● prod в промпте' 'метка сервера: ~/.config/bashrc-local.conf'

    # Своё: ~/bin/* и ~/.bashrc.d/*.sh со строками «# help: имя — описание»
    __help_section 'Своё  (~/bin, ~/.bashrc.d)'
    local file line
    for file in ~/bin/*; do
        [[ -f $file && -x $file ]] || continue
        line=$(head -n 15 "$file" | sed -n 's/^[[:space:]]*\(#\|\/\/\|;;\|--\)[[:space:]]*help:[[:space:]]*//p' | head -n1)
        __help_row "${file##*/}" "${line:-скрипт в ~/bin}"
    done
    for file in ~/.bashrc.d/*.sh; do
        [[ -f $file ]] || continue
        while IFS= read -r line; do
            __help_row "${line%% — *}" "${line#* — }" "${file##*/}"
        done < <(sed -n 's/^[[:space:]]*#[[:space:]]*help:[[:space:]]*//p' "$file")
    done
    unset -f __help_section __help_row
}

help() {
    local d=$'\e[90m' t=$'\e[1;35m' r=$'\e[0m'
    if (( $# )) && builtin help "$1" >/dev/null 2>&1; then builtin help "$@"; return; fi
    printf '\n  %s✦ %s%s%s   %shelp <слово> — поиск · help <встроенная> — справка bash%s\n' "$t" "$(hostname)" "${PROMPT_ENV:+ · $PROMPT_ENV}" "$r" "$d" "$r"
    if (( ${#PROJ_DIR[@]} )); then printf '  %sпроекты: %s%s\n' "$d" "$(for n in "${!PROJ_DIR[@]}"; do printf '%s  ' "$(__proj_cmd "$n")"; done)" "$r"; fi
    local __pending_title=
    __help_rows "$*"
    echo
}

# ── Своё: ~/.bashrc.d/*.sh (уезжают с srv install, остаются при обновлении) ──
for __f in ~/.bashrc.d/*.sh; do [[ -f $__f ]] && . "$__f"; done; unset __f

# ── Старт ────────────────────────────────────────────────────────────────────
__proj_load
__proj_define

if shopt -q login_shell; then
    __names=$(for n in $(printf '%s\n' "${!PROJ_DIR[@]}" | sort); do printf '%s ' "$(__proj_cmd "$n")"; done)
    printf '\e[90m  %shelp — шпаргалка · sys — состояние сервера\e[0m\n' "${__names:+проекты: $__names· }"
    unset __names
fi
'@
$EmbeddedFiles['srv-inputrc'] = @'
# srv: managed — ставится командой srv install, старая версия сохраняется в ~/.inputrc.bak-*
$include /etc/inputrc

# Tab: без учёта регистра, сразу список вариантов, цветом
set completion-ignore-case on
set show-all-if-ambiguous on
set colored-stats on
set colored-completion-prefix on
set mark-symlinked-directories on
set bell-style none

# Набрал начало команды + ↑/↓ — листаешь только подходящие из истории
"\e[A": history-search-backward
"\e[B": history-search-forward

# Ctrl+← / Ctrl+→ — по словам
"\e[1;5C": forward-word
"\e[1;5D": backward-word
'@
$EmbeddedFiles['srv-install'] = @'
# Выполняется на сервере командой srv (PowerShell) через одно ssh-подключение.
# Плейсхолдеры __…__ подставляет srv. Сам ничего не печатает в .bashrc, кроме одной строки подключения.
set -eu
umask 022

action='__ACTION__'
env_label='__ENV__'
ts=$(date +%Y%m%d-%H%M%S)
ok=$'\e[32m✓\e[0m' warn=$'\e[33m!\e[0m' bad=$'\e[31m✗\e[0m' dim=$'\e[90m' r=$'\e[0m'
conf=~/.config/bashrc-local.conf
hook='[ -f ~/.bashrc.local ] && . ~/.bashrc.local   # prompt, history, helpers (srv)'

echo "${dim}$(whoami)@$(hostname) · $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") · bash ${BASH_VERSION%%(*}${r}"

if [ "$action" = remove ]; then
    if [ -f ~/.bashrc ] && grep -qF '.bashrc.local' ~/.bashrc; then
        cp -p ~/.bashrc ~/.bashrc.bak-$ts
        grep -vF '.bashrc.local' ~/.bashrc.bak-$ts > ~/.bashrc || true
        echo "$ok строка подключения убрана из ~/.bashrc ${dim}(бэкап ~/.bashrc.bak-$ts)${r}"
    fi
    if [ -f ~/.bashrc.local ]; then
        mv ~/.bashrc.local ~/.bashrc.local.off-$ts
        echo "$ok ~/.bashrc.local → ~/.bashrc.local.off-$ts"
    fi
    if [ -f ~/.inputrc ] && grep -q 'srv: managed' ~/.inputrc; then
        mv ~/.inputrc ~/.inputrc.off-$ts
        echo "$ok ~/.inputrc → ~/.inputrc.off-$ts"
    fi
    echo "${dim}~/.config/projects, ~/.config/bashrc-local.conf и ~/.bashrc.d оставлены${r}"
    exit 0
fi

# __put <путь от ~> <base64> — записать файл, если он отличается (свои файлы из server\custom)
__put() {
    local target=~/"$1" tmp
    tmp=$(mktemp)
    printf '%s' "$2" | base64 -d > "$tmp"
    mkdir -p "${target%/*}"
    if [ -f "$target" ] && cmp -s "$tmp" "$target"; then rm -f "$tmp"; echo "$ok ~/$1 уже актуален"; return; fi
    cat "$tmp" > "$target"; rm -f "$tmp"
    echo "$ok ~/$1"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '%s' '__BASHRC_B64__' | base64 -d > "$work/bashrc.local"
printf '%s' '__INPUTRC_B64__' | base64 -d > "$work/inputrc"

# 1. проверка до любых изменений
bash -n "$work/bashrc.local" || { echo "$bad синтаксическая ошибка — ничего не меняю"; exit 1; }
errors=$(HOME=$HOME bash --norc -i -c ". '$work/bashrc.local'" </dev/null 2>&1 >/dev/null |
    grep -v -e 'job control' -e 'terminal process group' -e 'Inappropriate ioctl' || true)
if [ -n "$errors" ]; then
    echo "$bad пробная загрузка с ошибками — ничего не меняю:"; echo "$errors"; exit 1
fi
echo "$ok проверка: синтаксис и пробная загрузка"

# 2. настройки сервера (метка prod/staging) — отдельно от общего файла
mkdir -p ~/.config
if [ -n "$env_label" ]; then
    { [ -f "$conf" ] && grep -v '^PROMPT_ENV=' "$conf" || true; } > "$work/conf"
    [ "$env_label" = none ] && env_label=''
    printf 'PROMPT_ENV=%s\n' "$env_label" >> "$work/conf"
    cat "$work/conf" > "$conf"
    echo "$ok метка: ${env_label:-нет}"
elif [ ! -f "$conf" ] && [ -f ~/.bashrc.local ]; then
    # переезд со старой версии, где метка была прямо в файле
    old_env=$(sed -n 's/^PROMPT_ENV=\([A-Za-z0-9_-]*\).*/\1/p' ~/.bashrc.local | head -n1)
    if [ -n "$old_env" ]; then
        printf 'PROMPT_ENV=%s\n' "$old_env" > "$conf"
        echo "$ok метка перенесена из старой версии: $old_env"
    fi
fi

# 3. ~/.bashrc.local
old_ver=$(sed -n 's/^# version: //p' ~/.bashrc.local 2>/dev/null | head -n1 || true)
new_ver=$(sed -n 's/^# version: //p' "$work/bashrc.local" | head -n1)
if [ -f ~/.bashrc.local ] && cmp -s "$work/bashrc.local" ~/.bashrc.local; then
    echo "$ok ~/.bashrc.local уже актуален ${dim}($new_ver)${r}"
else
    if [ -f ~/.bashrc.local ]; then
        cp -p ~/.bashrc.local ~/.bashrc.local.bak-$ts
        echo "$ok бэкап: ~/.bashrc.local.bak-$ts"
    fi
    cat "$work/bashrc.local" > ~/.bashrc.local
    echo "$ok ~/.bashrc.local ${dim}${old_ver:-нет} → ${r}$new_ver"
fi

# 4. ~/.inputrc (стрелки по истории, Tab без регистра)
if [ -f ~/.inputrc ] && cmp -s "$work/inputrc" ~/.inputrc; then
    echo "$ok ~/.inputrc уже актуален"
else
    if [ -f ~/.inputrc ]; then
        cp -p ~/.inputrc ~/.inputrc.bak-$ts
        echo "$ok бэкап: ~/.inputrc.bak-$ts"
    fi
    cat "$work/inputrc" > ~/.inputrc
    echo "$ok ~/.inputrc"
fi

# 5. подключение из ~/.bashrc (одна строка, повторно не добавляется)
if [ ! -f ~/.bashrc ]; then
    if [ -f /etc/skel/.bashrc ]; then cp /etc/skel/.bashrc ~/.bashrc; else : > ~/.bashrc; fi
    echo "$ok создан ~/.bashrc"
fi
if grep -qF '.bashrc.local' ~/.bashrc; then
    echo "$ok ~/.bashrc уже подключает ~/.bashrc.local"
else
    cp -p ~/.bashrc ~/.bashrc.bak-$ts
    printf '\n%s\n' "$hook" >> ~/.bashrc
    echo "$ok ~/.bashrc: добавлена строка подключения ${dim}(бэкап ~/.bashrc.bak-$ts)${r}"
fi

# 6. свои файлы для серверов: server\custom\*.sh → ~/.bashrc.d/
mkdir -p ~/.bashrc.d
__CUSTOM_FILES__

# 7. при входе по ssh bash читает .bash_profile/.profile — они должны подтягивать .bashrc
if [ -f ~/.bash_profile ]; then
    grep -q 'bashrc' ~/.bash_profile || echo "$warn ~/.bash_profile не подключает ~/.bashrc — добавь: [ -f ~/.bashrc ] && . ~/.bashrc"
elif [ ! -f ~/.bash_login ] && [ ! -f ~/.profile ]; then
    printf '%s\n' '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.bash_profile
    echo "$ok создан ~/.bash_profile (подключает ~/.bashrc при входе)"
fi

# 8. итог
projects=$(bash --norc -i -c '. ~/.bashrc.local; printf "%s " "${!PROJ_DIR[@]}"' </dev/null 2>/dev/null || true)
echo "${dim}проекты: ${projects:-нет} · перезайди по ssh, затем help${r}"
# end
'@

# ── 1. Программы ─────────────────────────────────────────────────────────────
if (-not $SkipApps) {
    Step 'Программы'
    if (-not (Test-Command winget)) {
        Warn 'нет winget — программы пропускаю (App Installer из Microsoft Store)'
    } else {
        Install-WingetPackage 'Microsoft.WindowsTerminal' 'wt' 'Windows Terminal'
        $apps = @(
            @('Git.Git', 'git', 'git'),
            @('JanDeDobbeleer.OhMyPosh', 'oh-my-posh', 'oh-my-posh — промпт'),
            @('junegunn.fzf', 'fzf', 'fzf — поиск по истории и файлам'),
            @('ajeetdsouza.zoxide', 'zoxide', 'zoxide — z <папка>'),
            @('eza-community.eza', 'eza', 'eza — l / ll / lt'),
            @('sharkdp.bat', 'bat', 'bat — просмотр файлов'),
            @('BurntSushi.ripgrep.MSVC', 'rg', 'ripgrep — rg'),
            @('sharkdp.fd', 'fd', 'fd — поиск файлов'),
            @('dandavison.delta', 'delta', 'delta — диффы git'),
            @('JesseDuffield.lazygit', 'lazygit', 'lazygit — git в полноэкранном интерфейсе'),
            @('tldr-pages.tlrc', 'tldr', 'tldr — короткие шпаргалки по командам'),
            @('GitHub.cli', 'gh', 'gh — GitHub из терминала')
        )
        foreach ($a in $apps) { Install-WingetPackage $a[0] $a[1] $a[2] }
    }

    # ── 2. Шрифт ─────────────────────────────────────────────────────────────
    Step 'Шрифт JetBrainsMono Nerd Font'
    $missing = @($FontStyles.Keys | Where-Object { -not (Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-$_.ttf") })
    if (-not $missing) {
        Ok 'уже установлен для всех пользователей'
    } else {
        $fontTmp = Join-Path ([IO.Path]::GetTempPath()) "nerd-font-$Stamp"
        New-Item -ItemType Directory -Force $fontTmp | Out-Null
        try {
            foreach ($style in $missing) {
                $file = Join-Path $fontTmp "JetBrainsMonoNerdFont-$style.ttf"
                Invoke-WebRequest "$FontBaseUrl/$style/JetBrainsMonoNerdFont-$style.ttf" -OutFile $file -UseBasicParsing
                $head = [IO.File]::ReadAllBytes($file)[0..3] -join ','
                if ((Get-Item $file).Length -lt 500KB -or $head -ne '0,1,0,0') { throw "скачался не шрифт: $style" }
            }
            Info "скачано: $($missing -join ', ')"
            # Ставим в C:\Windows\Fonts — шрифты «только для меня» Windows Terminal не видит
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
                Info 'нужны права администратора — подтверди запрос Windows (UAC)'
                Start-Process (Get-Pwsh) -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installer`""
            }
            $still = @($FontStyles.Keys | Where-Object { -not (Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-$_.ttf") })
            if ($still) { Warn "не установились: $($still -join ', ')" } else { Ok 'установлен для всех пользователей' }
        } catch {
            Warn "шрифт не установлен: $($_.Exception.Message)"
        } finally {
            Remove-Item $fontTmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ── 3. Модуль PSFzf (Ctrl+R / Ctrl+T / Alt+C через fzf) ───────────────────
    Step 'Модуль PSFzf'
    if (Get-Module -ListAvailable PSFzf) { Ok 'уже есть' }
    else {
        try { Install-Module PSFzf -Scope CurrentUser -Force -AllowClobber; Ok 'установлен' }
        catch { Warn "не установился: $($_.Exception.Message)" }
    }
}
$FontInstalled = Test-Path "$env:windir\Fonts\JetBrainsMonoNerdFont-Regular.ttf"
if (-not $FontInstalled) { $FontFace = 'Cascadia Mono'; Warn 'Nerd Font нет — в терминале будет Cascadia Mono (иконки не покажутся)' }

# ── 4. Файлы профиля ─────────────────────────────────────────────────────────
function Write-ManagedFile([string]$Path, [string]$Content) {
    $Content = ($Content -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    if (Test-Path $Path) {
        $old = [IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
        if ($old -eq $Content) { Ok "$(Short $Path) — без изменений"; return }
        Copy-Item $Path "$Path.bak-$Stamp" -Force
        [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
        Ok "$(Short $Path) — обновлён $([char]0x00B7) старый: $(Split-Path $Path -Leaf).bak-$Stamp"
    } else {
        [IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
        Ok "$(Short $Path) — создан"
    }
}

Step 'Профиль PowerShell и шаблоны'
$targets = [ordered]@{
    'profile'     = $PROFILE
    'palette'     = Join-Path $ProfileDir 'palette.ps1'
    'toolkit'     = Join-Path $ProfileDir 'toolkit.ps1'
    'predictor'   = Join-Path $ProfileDir 'DeepHistoryPredictor.cs'
    'omp-theme'   = Join-Path $HOME '.config\ohmyposh\soft.omp.json'
    'srv-bashrc'  = Join-Path $ProfileDir 'server\bashrc.local'
    'srv-inputrc' = Join-Path $ProfileDir 'server\inputrc'
    'srv-install' = Join-Path $ProfileDir 'server\install.sh'
}
foreach ($key in $targets.Keys) { Write-ManagedFile $targets[$key] $EmbeddedFiles[$key] }

# custom.ps1 — только если его ещё нет: это файл пользователя, его никогда не перезаписываем
$customFile = Join-Path $ProfileDir 'custom.ps1'
if (Test-Path $customFile) { Ok "$(Short $customFile) — твой, не трогаю" }
else { [IO.File]::WriteAllText($customFile, ($EmbeddedFiles['custom'] -replace "`r`n", "`n"), $Utf8NoBom); Ok "$(Short $customFile) — создан (для своих настроек и команд)" }
foreach ($d in 'bin', 'server\custom') {
    $p = Join-Path $ProfileDir $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force $p | Out-Null; Ok "$(Short $p)\ — создана" }
}

# Тема: файл ~/.config/terminal-setup/theme (одно слово), по умолчанию mocha
. ([scriptblock]::Create($EmbeddedFiles['palette']))
if ($Theme) {
    New-Item -ItemType Directory -Force (Split-Path $ThemeFile) | Out-Null
    [IO.File]::WriteAllText($ThemeFile, "$Theme`n")
}
$ThemeName = Get-ThemeName
$ThemeTitle = "Catppuccin $((Get-Culture).TextInfo.ToTitleCase($ThemeName))"
Ok "тема: $ThemeName $([char]0x00B7) сменить: theme latte"

# ── 5. Windows Terminal ──────────────────────────────────────────────────────
function Set-Key($Table, [string]$Key, $Value) { $Table[$Key] = $Value }

function Get-StableGuid([string]$Text) {
    $md5 = [Security.Cryptography.MD5]::Create()
    '{' + [guid]::new($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).ToString() + '}'
}

function Update-TerminalSettings([string]$Path) {
    $raw = if (Test-Path $Path) { [IO.File]::ReadAllText($Path) } else { '' }
    try { $s = if ($raw.Trim()) { $raw | ConvertFrom-Json -AsHashtable } else { [ordered]@{} } }
    catch { Warn "$(Short $Path) — не разобрал JSON, пропускаю: $($_.Exception.Message)"; return }
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

    # PowerShell 7 — по умолчанию
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

    # Azure Cloud Shell почти никому не нужен — прячем
    foreach ($p in $list) { if ($p.source -eq 'Windows.Terminal.Azure') { Set-Key $p 'hidden' $true } }

    # Вкладки для SSH-серверов
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

    # Все четыре варианта Catppuccin — чтобы theme переключал на лету
    $s['schemes'] = @(@($s.schemes | Where-Object { $_ -and $_.name -notlike 'Catppuccin *' }) + @($CatppuccinFlavors.Keys | ForEach-Object { Get-TerminalScheme $_ }))
    $s['themes'] = @(@($s.themes | Where-Object { $_ -and $_.name -notlike 'Catppuccin *' }) + @($CatppuccinFlavors.Keys | ForEach-Object { Get-TerminalTheme $_ }))
    Set-Key $s 'theme' $ThemeTitle

    # Win+` — терминал выпадает сверху поверх всего (quake mode)
    if (-not $s.Contains('actions')) { $s['actions'] = @() }
    if (-not $s.Contains('keybindings')) { $s['keybindings'] = @() }
    if (-not ($s.actions | Where-Object { $_.id -eq 'User.quakeMode' })) {
        $s['actions'] = @($s.actions) + [ordered]@{ command = 'quakeMode'; id = 'User.quakeMode' }
    }
    if (-not ($s.keybindings | Where-Object { $_.id -eq 'User.quakeMode' -or $_.keys -eq 'win+`' })) {
        $s['keybindings'] = @($s.keybindings) + [ordered]@{ id = 'User.quakeMode'; keys = 'win+`' }
    }

    $after = $s | ConvertTo-Json -Depth 32
    if ($after -eq $before) { Ok "$(Short $Path) — без изменений"; return }
    if (Test-Path $Path) { Copy-Item $Path "$Path.bak-$Stamp" -Force }
    else { New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null }
    [IO.File]::WriteAllText($Path, $after, $Utf8NoBom)
    Ok "$(Short $Path) — обновлён$(if ($raw.Trim()) { " $([char]0x00B7) старый: settings.json.bak-$Stamp" })"
}

Step 'Windows Terminal'
$wtFound = $false
foreach ($pkg in 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe') {
    $pkgDir = Join-Path $env:LOCALAPPDATA "Packages\$pkg"
    if (Test-Path $pkgDir) { $wtFound = $true; Update-TerminalSettings (Join-Path $pkgDir 'LocalState\settings.json') }
}
$portable = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
if (Test-Path $portable) { $wtFound = $true; Update-TerminalSettings $portable }
if (-not $wtFound) { Warn 'Windows Terminal ещё ни разу не запускался — открой его один раз и запусти скрипт снова' }

# ── 6. VS Code ───────────────────────────────────────────────────────────────
Step 'Терминал VS Code'
$vsSettings = Join-Path $env:APPDATA 'Code\User\settings.json'
if (-not (Test-Path (Split-Path $vsSettings)) -and -not (Test-Command code)) {
    Info 'VS Code не найден — пропускаю'
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
    if ($new -eq $raw) { Ok "$(Short $vsSettings) — без изменений" }
    else {
        if (Test-Path $vsSettings) { Copy-Item $vsSettings "$vsSettings.bak-$Stamp" -Force }
        else { New-Item -ItemType Directory -Force (Split-Path $vsSettings) | Out-Null }
        [IO.File]::WriteAllText($vsSettings, $new, $Utf8NoBom)
        Ok "$(Short $vsSettings) — шрифт терминала: $FontFace"
    }
}

# ── 7. git + delta ───────────────────────────────────────────────────────────
Step 'git: диффы через delta'
if (-not (Test-Command git)) { Warn 'git не найден — пропускаю' }
elseif (-not (Test-Command delta)) { Warn 'delta не найден — пропускаю' }
else {
    # Только ANSI-цвета — тогда диффы следуют за темой терминала (theme latte — и дифф светлый)
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
    # фиксированные hex-цвета фона из прошлой версии ломают светлую тему — убираем
    foreach ($k in 'delta.minus-style', 'delta.minus-emph-style', 'delta.plus-style', 'delta.plus-emph-style') {
        if (git config --global --get $k 2>$null) { git config --global --unset $k; $changed++ }
    }
    if ($changed) { Ok "~/.gitconfig — изменено настроек: $changed" } else { Ok '~/.gitconfig — без изменений' }
}

# ── 8. Проверка ──────────────────────────────────────────────────────────────
Step 'Проверка профиля'
$check = & (Get-Pwsh) -NoLogo -NoProfile -Command "`$Error.Clear(); . '$PROFILE' *> `$null; `$Error.Count; foreach (`$e in `$Error) { `$e.ToString() }" 2>&1
$errCount = [int]($check | Select-Object -First 1)
if ($errCount -eq 0) { Ok 'профиль загружается без ошибок' }
else { Warn "ошибок при загрузке профиля: $errCount"; $check | Select-Object -Skip 1 -First 5 | ForEach-Object { Info "$_" } }

# ── Итог ─────────────────────────────────────────────────────────────────────
Write-Host ''
if ($Warnings) { Write-Host "  Готово, предупреждений: $Warnings (см. выше, жёлтым)." -ForegroundColor Yellow }
else { Write-Host '  Готово.' -ForegroundColor Green }
Write-Host '  Закрой все окна Windows Terminal и открой заново, затем набери: help  (или F1)' -ForegroundColor Gray
Write-Host '  Своё: custom.ps1 и bin\ рядом с профилем (ep) · new имя.py — команда на любом языке · theme latte' -ForegroundColor DarkGray
Write-Host '  Серверы: srv install <хост> -Env prod  — такой же удобный bash на Linux.' -ForegroundColor DarkGray
Write-Host '  Скрипт можно запускать повторно — он доустановит недостающее и обновит конфиги.' -ForegroundColor DarkGray
Write-Host ''
