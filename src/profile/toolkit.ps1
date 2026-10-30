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
