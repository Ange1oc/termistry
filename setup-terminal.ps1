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

.PARAMETER SkipApps
  Не ставить программы и шрифт — только конфиги.
#>
param(
    [string]$StartingDirectory,
    [string[]]$SshTabs = @(),
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
$FontFace = 'JetBrainsMono NF'
$FontStyles = [ordered]@{ Regular = 'Regular'; Bold = 'Bold'; Italic = 'Italic'; BoldItalic = 'Bold Italic' }
$FontBaseUrl = 'https://github.com/ryanoasis/nerd-fonts/raw/v3.4.0/patched-fonts/JetBrainsMono/Ligatures'

# ── Встроенные файлы (собраны build.ps1 из src/) ────────────────────────────
$EmbeddedFiles = [ordered]@{}
$EmbeddedFiles['profile'] = @'
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
'@
$EmbeddedFiles['toolkit'] = @'
# ─────────────────────────────────────────────────────────────────────────────
#  Мои команды-помощники. Подключается из профиля.
#    help [тема|текст]  — шпаргалка по терминалу (help <команда> — обычная справка)
#    my [тема]          — мои данные: ssh, ip, ports, path, tools, git, keys
#    h [текст]          — последние 50 команд, листаются по 10
#    jump [имя]         — выбрать SSH-сервер из списка и подключиться
#    srv install [хост] — поставить/обновить общий .bashrc.local на сервере (шаблоны в .\server)
#  Чтобы добавить строку в шпаргалку — допиши её в $TkSections ниже.
# ─────────────────────────────────────────────────────────────────────────────

function _tkRgb([int]$hex) { $PSStyle.Foreground.FromRgb($hex) }
$TK = @{
    R = $PSStyle.Reset; B = $PSStyle.Bold
    title = _tkRgb 0xCBA6F7; cmd = _tkRgb 0x89B4FA; text = _tkRgb 0xCDD6F4; dim = _tkRgb 0x6C7086
    ok = _tkRgb 0xA6E3A1; warn = _tkRgb 0xF9E2AF; err = _tkRgb 0xF38BA8; accent = _tkRgb 0xFAB387; teal = _tkRgb 0x94E2D5
}

# ── Шпаргалка: раздел → строки (команда, что делает, пример) ─────────────────
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
    ) }
    @{ Key = 'search'; Title = 'Поиск'; Rows = @(
        , ('rg <текст>', 'найти текст во всех файлах папки', 'rg TODO -t py')
        , ('fd <имя>', 'найти файл по имени', 'fd docker-compose')
        , ('Ctrl+T', 'выбрать файл через fzf и вставить путь в строку')
    ) }
    @{ Key = 'keys'; Title = 'Клавиши'; Rows = @(
        , ('Ctrl+R', 'поиск по всей истории: 10 строк, PgUp/PgDn листать')
        , ('↑ / ↓', 'история по уже набранному началу', 'набрал git → ↑')
        , ('→ / Ctrl+→', 'принять подсказку целиком / по словам')
        , ('F2', 'подсказки: список ⇄ серый текст в строке')
        , ('Tab', 'меню дополнений (команды, пути, ssh-хосты)')
        , ('Ctrl+C', 'отменить строку · копировать, если выделено')
        , ('Ctrl+Shift+F', 'поиск по выводу в окне терминала')
        , ('Alt+Shift+D', 'разделить окно на две панели')
    ) }
    @{ Key = 'history'; Title = 'История'; Rows = @(
        , ('начни печатать', 'до 50 подсказок из истории, ↑/↓ листать, Esc — скрыть')
        , ('h', 'последние 50 команд, листаются по 10')
        , ('h <текст>', 'только команды с этим текстом', 'h docker')
        , ('h -Count 200', 'показать больше')
    ) }
    @{ Key = 'git'; Title = 'Git'; Rows = @(
        , ('gst', 'короткий статус')
        , ('lg', 'красивый лог, 30 коммитов', 'lg -n 100')
        , ('git diff', 'дифф с подсветкой (delta), n/N — к след./пред. файлу')
        , ('my git', 'имя, почта, remotes текущего репо')
    ) }
    @{ Key = 'ssh'; Title = 'Серверы'; Rows = @(
        , ('my ssh [фильтр]', 'все SSH-хосты из ~/.ssh/config', 'my ssh prod')
        , ('jump [имя]', 'выбрать сервер из списка и подключиться', 'jump prod')
        , ('ssh <Tab>', 'дополнение имён хостов (и для scp)')
        , ('srv install [хост]', 'поставить/обновить bashrc на сервере', 'srv install myserver -Env prod')
        , ('srv remove [хост]', 'откатить bashrc на сервере')
        , ('srv', 'подробно: что получает сервер, метки prod/dev')
    ) }
    @{ Key = 'dev'; Title = 'Инструменты'; Rows = @(
        , ('docker / kubectl / helm', 'Tab-дополнения подкоманд и флагов')
        , ('gh / kind / minikube', 'Tab-дополнения тоже есть')
        , ('my tools', 'версии всех установленных инструментов')
        , ('my ports [порт]', 'кто слушает порты', 'my ports 5432')
        , ('my ip', 'IP-адреса и шлюз · my ip public — внешний IP')
    ) }
    @{ Key = 'setup'; Title = 'Настройка'; Rows = @(
        , ('my', 'все разделы с моими данными')
        , ('ep', 'открыть папку профиля в VS Code')
        , ('reload', 'перечитать профиль после правок')
        , ('Update-Completions', 'обновить Tab-дополнения после обновления CLI')
    ) }
)

function Write-TkRow([string]$Command, [string]$Description, [string]$Example) {
    $cmdCell = if ($Command.Length -ge 24) { $Command + '  ' } else { $Command.PadRight(24) }
    $line = '    ' + $TK.cmd + $cmdCell + $TK.R + $TK.text + $Description + $TK.R
    if ($Example) { $line += '  ' + $TK.dim + $Example + $TK.R }
    Write-Host $line
}

function Show-TkHelp($Sections = $TkSections) {
    Write-Host ''
    Write-Host ("  {0}{1}✦ Что умеет мой терминал{2}" -f $TK.title, $TK.B, $TK.R)
    Write-Host ("  {0}help <тема> — один раздел · help <текст> — поиск · help <команда> — справка PowerShell · my — мои данные{1}" -f $TK.dim, $TK.R)
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
    $section = $TkSections | Where-Object { $_.Key -eq $query -or $_.Title -eq $query }
    if ($section) { Show-TkHelp $section; return }

    $hits = @(foreach ($s in $TkSections) {
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

# ── Таблица для my ───────────────────────────────────────────────────────────
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

# ── srv: общий .bashrc.local на серверах ─────────────────────────────────────
#  Шаблоны лежат в .\server рядом с профилем: bashrc.local, inputrc, install.sh.
#  Всё делается за одно ssh-подключение — ufw limit на сервере не срабатывает.
function srv {
    param(
        [Parameter(Position = 0)][ValidateSet('install', 'remove', 'help')][string]$Action = 'help',
        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [ArgumentCompleter({ param($c, $p, $word) (Get-SshHost).Name | Where-Object { $_ -like "$word*" } })]
        [string[]]$Hosts,
        [string]$Env          # метка в промпте: prod / staging / dev / none — убрать
    )
    $dir = Join-Path (Split-Path $PROFILE) 'server'
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

    $read = { param($name) [IO.File]::ReadAllText((Join-Path $dir $name)) -replace "`r`n", "`n" }
    $b64 = { param($text) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)) }
    $script = (& $read 'install.sh').Replace('__ACTION__', $Action).Replace('__ENV__', $Env)
    $script = $script.Replace('__BASHRC_B64__', (& $b64 (& $read 'bashrc.local')))
    $script = $script.Replace('__INPUTRC_B64__', (& $b64 (& $read 'inputrc')))
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
    Write-TkTitle 'srv — общий .bashrc.local на серверах' "шаблоны: $Dir"
    Write-TkRow 'srv install [хост…]' 'поставить или обновить (без хоста — выбор из списка)' 'srv install myserver'
    Write-TkRow 'srv install <хост> -Env prod' 'то же + метка в промпте: prod / staging / dev / none'
    Write-TkRow 'srv remove [хост]' 'откатить: убрать подключение, файлы → *.off'
    Write-Host ''
    Write-Host "  $($TK.title)Что получает сервер$($TK.R)"
    Write-Host "    промпт как здесь, большая история, ↑/↓ по началу команды, help, sys"
    Write-Host "    проекты находятся сами (docker compose ls): $($TK.cmd)<имя> ps · <имя> logs web · <имя> sh web · proj · app$($TK.R)"
    Write-Host "    защита: docker down -v / volume rm / prune просят yes; rm, cp, mv — подтверждение"
    Write-Host ''
    Write-Host "  $($TK.dim)Каждый запуск: бэкап, проверка до изменений, одно ssh-подключение. Повторный запуск ничего не ломает.$($TK.R)"
    Write-Host ''
}

Register-ArgumentCompleter -Native -CommandName ssh, scp, sftp -ScriptBlock {
    param($wordToComplete, $commandAst)
    $suffix = if ($commandAst.CommandElements[0].Value -eq 'ssh') { '' } else { ':' }
    Get-SshHost | Where-Object Name -like "$wordToComplete*" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_.Name + $suffix, $_.Name, 'ParameterValue', "$($_.User)@$($_.HostName)")
    }
}

# ── my ───────────────────────────────────────────────────────────────────────
$TkMyTopics = [ordered]@{
    ssh   = 'SSH-хосты из ~/.ssh/config          my ssh prod'
    ip    = 'IP-адреса, шлюз · внешний IP         my ip public'
    ports = 'кто слушает порты                    my ports 8080'
    path  = 'PATH: что есть, чего нет, дубли'
    tools = 'версии установленных инструментов'
    git   = 'имя, почта, remotes, алиасы git'
    keys  = 'горячие клавиши'
    cmds  = 'вся шпаргалка (= help)'
}

function my {
    param(
        [Parameter(Position = 0)][ArgumentCompleter({
            param($c, $p, $word) $TkMyTopics.get_Keys() | Where-Object { $_ -like "$word*" }
        })][string]$Topic,
        [Parameter(Position = 1)][string]$Filter
    )
    switch ($Topic) {
        'ssh'   { Show-MySsh $Filter }
        'ip'    { Show-MyIp $Filter }
        'ports' { Show-MyPorts $Filter }
        'path'  { Show-MyPath }
        'tools' { Show-MyTools }
        'git'   { Show-MyGit }
        'keys'  { Show-TkHelp ($TkSections | Where-Object Key -eq 'keys') }
        'cmds'  { Show-TkHelp }
        default {
            Write-TkTitle 'my <тема>' 'Tab дополняет тему'
            # .get_Keys(): у словаря есть ключ 'keys', и .Keys вернул бы его значение
            foreach ($k in $TkMyTopics.get_Keys()) { Write-TkRow "my $k" $TkMyTopics[$k] }
            Write-Host ''
        }
    }
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
        pwsh = '--version'; git = '--version'; node = '--version'; python = '--version'; uv = '--version'
        docker = '--version'; kubectl = 'version --client'; helm = 'version --short'; kind = 'version'
        minikube = 'version --short'; gh = '--version'; code = '--version'; 'oh-my-posh' = 'version'
        fzf = '--version'; zoxide = '--version'; eza = '--version'; bat = '--version'; rg = '--version'
        fd = '--version'; delta = '--version'
    }
    $rows = $specs.GetEnumerator() | ForEach-Object -ThrottleLimit 10 -Parallel {
        $name, $argLine = $_.Key, $_.Value
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { return }
        $out = (& $name ($argLine -split ' ') 2>&1 | Select-Object -First 3) -join ' '
        [pscustomobject]@{ Name = $name; Version = ([regex]::Match($out, '\d+\.\d+(\.\d+)?')).Value; Path = $cmd.Source }
    } | Sort-Object Name
    Write-TkTitle 'Инструменты' 'обновить всё из scoop: scoop update *'
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

function ep { code (Split-Path $PROFILE) }
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
  "palette": {
    "text": "#CDD6F4",
    "subtext": "#A6ADC8",
    "overlay": "#7F849C",
    "dim": "#585B70",
    "blue": "#89B4FA",
    "mauve": "#CBA6F7",
    "green": "#A6E3A1",
    "red": "#F38BA8",
    "peach": "#FAB387",
    "yellow": "#F9E2AF",
    "teal": "#94E2D5"
  },
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "text",
          "style": "plain",
          "foreground": "p:dim",
          "template": "╭─"
        },
        {
          "type": "root",
          "style": "plain",
          "foreground": "p:red",
          "template": "  admin"
        },
        {
          "type": "session",
          "style": "plain",
          "foreground": "p:peach",
          "template": "{{ if .SSHSession }}  {{ .UserName }}@{{ .HostName }}{{ end }}"
        },
        {
          "type": "path",
          "style": "plain",
          "foreground": "p:blue",
          "template": "  {{ .Path }}",
          "options": {
            "style": "agnoster_short",
            "max_depth": 3,
            "home_icon": "~"
          }
        },
        {
          "type": "git",
          "style": "plain",
          "foreground": "p:mauve",
          "template": "   {{ .HEAD }}{{ if .Staging.Changed }} <p:green>+{{ .Staging.String }}</>{{ end }}{{ if .Working.Changed }} <p:peach>~{{ .Working.String }}</>{{ end }}{{ if gt .Ahead 0 }} <p:teal>⇡{{ .Ahead }}</>{{ end }}{{ if gt .Behind 0 }} <p:teal>⇣{{ .Behind }}</>{{ end }}",
          "options": {
            "fetch_status": true,
            "branch_icon": ""
          }
        },
        {
          "type": "python",
          "style": "plain",
          "foreground": "p:yellow",
          "template": "   {{ if .Venv }}{{ .Venv }}{{ end }}",
          "options": {
            "display_mode": "environment",
            "fetch_virtual_env": true,
            "fetch_version": false
          }
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "right",
      "segments": [
        {
          "type": "executiontime",
          "style": "plain",
          "foreground": "p:overlay",
          "template": " {{ .FormattedMs }} ",
          "options": {
            "threshold": 2000,
            "style": "austin"
          }
        },
        {
          "type": "status",
          "style": "plain",
          "foreground": "p:red",
          "template": " {{ .Code }}"
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "text",
          "style": "plain",
          "foreground": "p:dim",
          "template": "╰─"
        },
        {
          "type": "status",
          "style": "plain",
          "foreground": "p:green",
          "foreground_templates": ["{{ if gt .Code 0 }}p:red{{ end }}"],
          "template": "❯",
          "options": {
            "always_enabled": true
          }
        }
      ]
    }
  ],
  "transient_prompt": {
    "foreground": "p:overlay",
    "template": "{{ .Folder }} <p:green>❯</> "
  },
  "secondary_prompt": {
    "foreground": "p:dim",
    "template": "❯❯ "
  }
}
'@
$EmbeddedFiles['srv-bashrc'] = @'
# ~/.bashrc.local — один и тот же для всех серверов. Ставится из PowerShell: srv install <хост>
# version: 2026-10-30.3
#
#  Настройки конкретного сервера:  ~/.config/bashrc-local.conf   (PROMPT_ENV=prod …)
#  Проекты находятся сами (docker compose ls) и запоминаются в ~/.config/projects,
#  для каждого появляется команда с его именем:  myapp ps · myapp logs web · myapp sh web
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
HISTIGNORE='ls:ll:la:pwd:exit:clear:history'
shopt -s histappend cmdhist checkwinsize globstar

# ── Промпт ───────────────────────────────────────────────────────────────────
#  ┌─ ● prod deploy@vm1 ~/myapp ⎇ main*  ✘ 1
#  └─❯
__git_branch() {
    local b dirty=
    # GIT_OPTIONAL_LOCKS=0 — промпт не берёт index.lock и не мешает деплою
    b=$(GIT_OPTIONAL_LOCKS=0 git symbolic-ref --short HEAD 2>/dev/null || GIT_OPTIONAL_LOCKS=0 git rev-parse --short HEAD 2>/dev/null) || return
    [[ -n $(GIT_OPTIONAL_LOCKS=0 git status --porcelain --untracked-files=no 2>/dev/null | head -n1) ]] && dirty='*'
    printf ' ⎇ %s%s' "$b" "$dirty"
}

__prompt() {
    local code=$?
    history -a

    local r='\[\e[0m\]' dim='\[\e[90m\]' red='\[\e[31m\]' green='\[\e[32m\]'
    local yellow='\[\e[33m\]' blue='\[\e[34m\]' mauve='\[\e[35m\]' cyan='\[\e[36m\]'

    local user=$cyan;  (( EUID == 0 )) && user=$red     # root — красным
    local arrow=$green status= env= venv=
    (( code != 0 )) && { arrow=$red; status="  ${red}✘ ${code}${r}"; }
    if [[ -n $PROMPT_ENV ]]; then
        local envc=$blue
        case $PROMPT_ENV in prod*) envc=$red ;; stag*|test*|qa*) envc=$yellow ;; dev*) envc=$green ;; esac
        env="${envc}● ${PROMPT_ENV}${r} "
    fi
    [[ -n $VIRTUAL_ENV ]] && venv="  ${yellow}($(basename "$VIRTUAL_ENV"))${r}"

    PS1="\[\e]0;${PROMPT_ENV:+[$PROMPT_ENV] }\u@\h: \w\a\]"
    PS1+="\n${dim}┌─${r} ${env}${user}\u${dim}@${r}${yellow}\h${r} ${blue}\w${r}${mauve}$(__git_branch)${r}${venv}${status}"
    PS1+="\n${dim}└─${arrow}❯${r} "
}
[[ $PROMPT_COMMAND == *__prompt* ]] || PROMPT_COMMAND="__prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

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
sys() {
    local t=$'\e[1;35m' d=$'\e[90m' r=$'\e[0m' name state
    printf '\n  %s%s%s  %s%s%s\n' "$t" "$(hostname)" "$r" "$d" "$(uptime -p)" "$r"
    printf '  нагрузка   %s  %s(ядер: %s)%s\n' "$(cut -d' ' -f1-3 /proc/loadavg)" "$d" "$(nproc)" "$r"
    free -h | awk '/^Mem:/ {printf "  память     %s из %s, доступно %s\n", $3, $2, $7}'
    df -h / | awk 'NR==2 {printf "  диск /     %s из %s (%s)\n", $3, $2, $5}'
    if command -v docker >/dev/null; then
        printf '\n  %sконтейнеры%s\n' "$t" "$r"
        command docker ps -a --format '{{.Names}}'$'\t''{{.Status}}' | while IFS=$'\t' read -r name state; do
            printf '  %s %-30s %s%s%s\n' "$(__dot "$state")" "$name" "$d" "$state" "$r"
        done
    fi
    echo
}

# ── Шпаргалка: help (help <команда> — обычная справка bash) ──────────────────
help() {
    if (( $# )); then builtin help "$@"; return; fi
    local t=$'\e[1;35m' c=$'\e[34m' d=$'\e[90m' r=$'\e[0m'
    local ex; ex=$(__proj_current); ex=${ex:-${!PROJ_DIR[*]}}; ex=${ex%% *}; ex=${ex:-myapp}
    local p; p=$(__proj_cmd "$ex")
    __help_section() { printf '\n  %s%s%s\n' "$t" "$1" "$r"; }
    __help_row() { printf '    %s%s%s %s %s%s%s\n' "$c" "$(__pad "$1" 27)" "$r" "$(__pad "$2" 44)" "$d" "$3" "$r"; }

    printf '\n  %s✦ %s%s%s   %shelp <команда> — справка bash%s\n' "$t" "$(hostname)" "${PROMPT_ENV:+ · $PROMPT_ENV}" "$r" "$d" "$r"
    __help_section "Проекты  ${d}(находятся сами: docker compose ls)${r}"
    __help_row 'proj' 'все проекты: статус и папка'
    __help_row '<проект>' 'статус контейнеров' "$p"
    __help_row '<проект> logs [сервис]' 'логи: 200 строк и дальше поток' "$p logs web"
    __help_row '<проект> sh <сервис>' 'shell внутри контейнера' "$p sh web"
    __help_row '<проект> <команда>' 'любая docker compose команда' "$p restart web"
    __help_row '<проект> cd · app' 'перейти в папку проекта' "app $ex"
    __help_row 'dsh <сервис>' 'shell в контейнере проекта, где ты сейчас'
    __help_row 'proj add [имя] [папка]' 'добавить вручную (по умолчанию — текущую)'
    __help_row 'proj rm <имя>' 'скрыть из списка'
    (( ${#PROJ_DIR[@]} )) && printf '    %sздесь: %s%s\n' "$d" "$(for n in "${!PROJ_DIR[@]}"; do printf '%s  ' "$(__proj_cmd "$n")"; done)" "$r"
    __help_section 'Docker'
    __help_row 'dps' 'все контейнеры: статус и порты'
    __help_row 'dc · dlogs' 'docker compose / логи в текущей папке'
    __help_section 'Сервер'
    __help_row 'sys' 'нагрузка, память, диск, контейнеры'
    __help_row 'ports' 'кто слушает порты'
    __help_row 'df · free · du1' 'диск · память · размер папок здесь'
    __help_section 'Файлы и навигация'
    __help_row 'll · la' 'подробный список · со скрытыми'
    __help_row '.. · ... · mkcd <папка>' 'вверх · два вверх · создать и зайти'
    __help_section 'История и ввод'
    __help_row 'начало команды + ↑/↓' 'листать только подходящие из истории'
    __help_row 'Ctrl+R' 'поиск по всей истории'
    __help_row 'Tab' 'дополнение без учёта регистра (и сервисов)'
    __help_row ' команда (с пробелом)' 'не сохранится в историю — для паролей'
    __help_section 'Подстраховка'
    __help_row 'rm · cp · mv' 'спрашивают перед массовым удалением'
    __help_row 'down -v · volume rm · prune' 'docker требует набрать yes'
    __help_row '\rm …' 'без подтверждения (обход алиаса)'
    echo
}

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
    echo "${dim}~/.config/projects и ~/.config/bashrc-local.conf оставлены${r}"
    exit 0
fi

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

# 6. при входе по ssh bash читает .bash_profile/.profile — они должны подтягивать .bashrc
if [ -f ~/.bash_profile ]; then
    grep -q 'bashrc' ~/.bash_profile || echo "$warn ~/.bash_profile не подключает ~/.bashrc — добавь: [ -f ~/.bashrc ] && . ~/.bashrc"
elif [ ! -f ~/.bash_login ] && [ ! -f ~/.profile ]; then
    printf '%s\n' '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.bash_profile
    echo "$ok создан ~/.bash_profile (подключает ~/.bashrc при входе)"
fi

# 7. итог
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
            @('dandavison.delta', 'delta', 'delta — диффы git')
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
    'toolkit'     = Join-Path $ProfileDir 'toolkit.ps1'
    'predictor'   = Join-Path $ProfileDir 'DeepHistoryPredictor.cs'
    'omp-theme'   = Join-Path $HOME '.config\ohmyposh\soft.omp.json'
    'srv-bashrc'  = Join-Path $ProfileDir 'server\bashrc.local'
    'srv-inputrc' = Join-Path $ProfileDir 'server\inputrc'
    'srv-install' = Join-Path $ProfileDir 'server\install.sh'
}
foreach ($key in $targets.Keys) { Write-ManagedFile $targets[$key] $EmbeddedFiles[$key] }

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
    Set-Key $d 'colorScheme' 'Catppuccin Mocha'
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

    $scheme = [ordered]@{
        name = 'Catppuccin Mocha'
        background = '#1E1E2E'; foreground = '#CDD6F4'; cursorColor = '#F5E0DC'; selectionBackground = '#45475A'
        black = '#45475A'; red = '#F38BA8'; green = '#A6E3A1'; yellow = '#F9E2AF'
        blue = '#89B4FA'; purple = '#CBA6F7'; cyan = '#94E2D5'; white = '#BAC2DE'
        brightBlack = '#585B70'; brightRed = '#F38BA8'; brightGreen = '#A6E3A1'; brightYellow = '#F9E2AF'
        brightBlue = '#89B4FA'; brightPurple = '#CBA6F7'; brightCyan = '#94E2D5'; brightWhite = '#A6ADC8'
    }
    $s['schemes'] = @(@($s.schemes | Where-Object { $_ -and $_.name -ne 'Catppuccin Mocha' }) + $scheme)

    $theme = [ordered]@{
        name = 'Catppuccin Mocha'
        tab = [ordered]@{ background = '#1E1E2EFF'; unfocusedBackground = $null; showCloseButton = 'hover' }
        tabRow = [ordered]@{ background = '#181825FF'; unfocusedBackground = '#11111BFF' }
        window = [ordered]@{ applicationTheme = 'dark'; useMica = $false }
    }
    $s['themes'] = @(@($s.themes | Where-Object { $_ -and $_.name -ne 'Catppuccin Mocha' }) + $theme)
    Set-Key $s 'theme' 'Catppuccin Mocha'

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
    $gitSettings = [ordered]@{
        'core.pager'                         = 'delta'
        'interactive.diffFilter'             = 'delta --color-only'
        'merge.conflictstyle'                = 'zdiff3'
        'delta.navigate'                     = 'true'
        'delta.line-numbers'                 = 'true'
        'delta.syntax-theme'                 = 'ansi'
        'delta.file-style'                   = '#CBA6F7 bold'
        'delta.file-decoration-style'        = '#585B70 ul'
        'delta.hunk-header-style'            = 'file line-number syntax'
        'delta.hunk-header-decoration-style' = '#585B70 box'
        'delta.minus-style'                  = 'syntax "#3E2E40"'
        'delta.minus-emph-style'             = 'syntax "#5E3F53"'
        'delta.plus-style'                   = 'syntax "#323C3F"'
        'delta.plus-emph-style'              = 'syntax "#475950"'
        'delta.line-numbers-minus-style'     = '#F38BA8'
        'delta.line-numbers-plus-style'      = '#A6E3A1'
        'delta.line-numbers-zero-style'      = '#585B70'
    }
    $changed = 0
    foreach ($k in $gitSettings.Keys) {
        $current = git config --global --get $k 2>$null
        if ($current -ne $gitSettings[$k]) { git config --global $k $gitSettings[$k]; $changed++ }
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
Write-Host '  Закрой все окна Windows Terminal и открой заново, затем набери: help' -ForegroundColor Gray
Write-Host '  Серверы: srv install <хост> -Env prod  — такой же удобный bash на Linux.' -ForegroundColor DarkGray
Write-Host '  Скрипт можно запускать повторно — он доустановит недостающее и обновит конфиги.' -ForegroundColor DarkGray
Write-Host ''
