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
