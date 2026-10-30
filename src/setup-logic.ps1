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

#@@EMBEDDED_FILES@@

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
