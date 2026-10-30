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
