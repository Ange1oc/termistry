# ─────────────────────────────────────────────────────────────────────────────
#  PowerShell 7 profile
#  Палитра везде одна — Catppuccin Mocha: схема Windows Terminal, промпт
#  oh-my-posh, подсветка ввода, ls/eza, fzf, bat/delta.
#  Ставится и обновляется скриптом setup-terminal.ps1 (старые версии — *.bak-<дата>).
# ─────────────────────────────────────────────────────────────────────────────

$env:XDG_CONFIG_HOME = "$HOME\.config"
$isInteractive = -not [Console]::IsOutputRedirected -and $Host.Name -eq 'ConsoleHost'

# ── Палитра ──────────────────────────────────────────────────────────────────
$c = @{
    text = 0xCDD6F4; subtext = 0xA6ADC8; overlay = 0x7F849C; dim = 0x6C7086
    surface = 0x313244; surface1 = 0x45475A
    blue = 0x89B4FA; sky = 0x89DCEB; teal = 0x94E2D5; green = 0xA6E3A1
    yellow = 0xF9E2AF; peach = 0xFAB387; red = 0xF38BA8; mauve = 0xCBA6F7
    flamingo = 0xF2CDCD; lavender = 0xB4BEFE
}
function fg($hex) { $PSStyle.Foreground.FromRgb($hex) }
function bg($hex) { $PSStyle.Background.FromRgb($hex) }

# ── Вывод PowerShell (ls, таблицы, ошибки) ───────────────────────────────────
$PSStyle.FileInfo.Directory    = fg $c.blue
$PSStyle.FileInfo.SymbolicLink = fg $c.teal
$PSStyle.FileInfo.Executable   = fg $c.green
foreach ($ext in '.zip', '.7z', '.rar', '.tar', '.gz') { $PSStyle.FileInfo.Extension[$ext] = fg $c.peach }
foreach ($ext in '.ps1', '.psm1', '.sh', '.py', '.js', '.ts') { $PSStyle.FileInfo.Extension[$ext] = fg $c.green }
$PSStyle.Formatting.TableHeader     = (fg $c.mauve) + $PSStyle.Bold
$PSStyle.Formatting.FormatAccent    = fg $c.mauve
$PSStyle.Formatting.Error           = fg $c.red
$PSStyle.Formatting.ErrorAccent     = fg $c.peach
$PSStyle.Formatting.Warning         = fg $c.yellow
$PSStyle.Formatting.Verbose         = fg $c.overlay
$PSStyle.Formatting.Debug           = fg $c.overlay
$PSStyle.Progress.Style             = fg $c.mauve

# ── PSReadLine: редактирование, история, подсказки, подсветка ────────────────
if ($isInteractive) {
    Set-PSReadLineOption -EditMode Emacs `
        -HistoryNoDuplicates `
        -HistorySearchCursorMovesToEnd `
        -MaximumHistoryCount 20000 `
        -BellStyle None `
        -PredictionSource History `
        -PredictionViewStyle ListView
    Set-PSReadLineOption -Colors @{
        Default                = fg $c.text
        Command                = fg $c.blue
        Parameter              = fg $c.teal
        Operator               = fg $c.sky
        Variable               = fg $c.flamingo
        String                 = fg $c.green
        Number                 = fg $c.peach
        Type                   = fg $c.yellow
        Member                 = fg $c.lavender
        Keyword                = fg $c.mauve
        Comment                = (fg $c.dim) + $PSStyle.Italic
        Error                  = fg $c.red
        Emphasis               = fg $c.yellow
        Selection              = bg $c.surface1
        ContinuationPrompt     = fg $c.dim
        InlinePrediction       = fg $c.dim
        ListPrediction         = fg $c.mauve
        ListPredictionSelected = bg $c.surface
    }

    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Ctrl+c    -Function CancelLine
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward   # набрал "git" + ↑ — листаешь только git-команды
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key F2        -Function SwitchPredictionView    # список подсказок ⇄ серая подсказка в строке
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord       # принять подсказку по словам

    # Подсказки из истории: до 50 вместо встроенных 10 (окно 10 строк, листается ↑/↓).
    # Плагин — DeepHistoryPredictor.cs рядом с профилем. DLL кэшируется под хэшем исходника:
    # правка .cs даёт новую DLL, а старая может оставаться занятой в открытых вкладках.
    $predictorSrc = Join-Path (Split-Path $PROFILE) 'DeepHistoryPredictor.cs'
    if (Test-Path $predictorSrc) {
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
                    $predictorKind, [DeepHistoryPredictor]::new((Get-PSReadLineOption).HistorySavePath, 50))
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

# ── fzf: Ctrl+R — история, Ctrl+T — файлы, Alt+C — перейти в папку ───────────
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
$env:FZF_DEFAULT_OPTS = @(
    '--height=45% --layout=reverse --border=rounded --info=inline-right'
    '--prompt="❯ " --pointer="▌" --marker="●"'
    '--color=bg:-1,bg+:#313244,fg:#CDD6F4,fg+:#CDD6F4,hl:#F38BA8,hl+:#F38BA8'
    '--color=border:#585B70,header:#F38BA8,info:#7F849C,prompt:#CBA6F7'
    '--color=pointer:#F5E0DC,marker:#B4BEFE,spinner:#F5E0DC,selected-bg:#45475A'
) -join ' '
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
function lg  { git log --graph --pretty='%C(#cba6f7)%h%Creset %C(#a6e3a1)%ar%Creset %C(#89b4fa)%an%Creset %s%C(#fab387)%d%Creset' -n 30 @args }
function gst { git status -sb @args }
function reload { . $PROFILE }

# help, my, h, jump — шпаргалка и помощники
. (Join-Path (Split-Path $PROFILE) 'toolkit.ps1')

Remove-Variable c -ErrorAction SilentlyContinue
Remove-Item Function:fg, Function:bg -ErrorAction SilentlyContinue
