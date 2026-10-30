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
