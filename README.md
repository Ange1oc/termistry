<h1 align="center">terminal-setup</h1>

<p align="center">
Красивый и удобный терминал на Windows 11 — одной командой.<br>
Такой же bash на серверах — ещё одной.
</p>

<p align="center">Русский · <a href="README.en.md">English</a></p>

<p align="center"><img src="docs/hero.png" width="860" alt="PowerShell 7 в Windows Terminal: промпт с веткой git, версией node, контекстом kubernetes, временем долгой команды"></p>

## Установка

Открой PowerShell (обычный, не от администратора) и вставь:

```powershell
irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1 | iex
```

Спросит язык (`ru`/`en`). Потом закрой все окна Windows Terminal, открой заново, нажми **F1**.

- Работает на голой Windows 11 и 10: сам поставит PowerShell 7 и продолжит в нём.
- Права администратора попросит один раз — только для шрифта с иконками (иначе Windows Terminal его не видит).
- **Запускать повторно безопасно** — каждый шаг проверяет, что уже сделано. Так же и обновляться.
- Любой файл, который отличается от нового, перед заменой сохраняется рядом как `*.bak-<дата>`. Твои `custom.ps1` и `bin\` не трогаются никогда.

<details>
<summary>Параметры</summary>

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1))) -Lang ru -Theme latte -SshTabs prod,staging
```

| | |
|---|---|
| `-Lang ru\|en` | язык интерфейса (потом: `lang en`) |
| `-Theme mocha\|macchiato\|frappe\|latte` | вариант палитры (потом: `theme latte`) |
| `-StartingDirectory D:\code` | где открывается новая вкладка |
| `-SshTabs host1,host2` | вкладки в меню терминала для хостов из `~/.ssh/config` |
| `-SkipApps` | только конфиги, без программ и шрифта |

Без интернета на целевой машине: скачай [`setup-terminal.ps1`](setup-terminal.ps1) и запусти `powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1`.

</details>

## Что внутри

| | |
|---|---|
| **Программы** | PowerShell 7, Windows Terminal, git, oh-my-posh, fzf, zoxide, eza, bat, ripgrep, fd, delta, lazygit, tldr, gh — через winget, только чего нет |
| **Вид** | палитра [Catppuccin](https://catppuccin.com) во всём: терминал, промпт, подсветка ввода, `ls`, fzf, диффы; шрифт JetBrainsMono Nerd Font |
| **Промпт** | папка, ветка и изменения git, версия node / python / go / rust в проекте, контекст kubernetes, время долгой команды, код ошибки |
| **Ввод** | подсветка синтаксиса, до 50 подсказок из истории, сокращения, исправление раскладки, ↑/↓ по началу команды |
| **Дополнения** | kubectl, helm, docker, gh, kind, minikube, ssh-хосты — кэшируются, старт быстрый |
| **Windows Terminal** | PowerShell 7 по умолчанию, `Win+\`` — терминал выпадает поверх всего, четыре варианта темы |
| **Серверы** | `srv install <хост>` — тот же промпт, шпаргалка и защита на Linux, без установки чего-либо |

## Шпаргалка всегда под рукой

<p align="center"><img src="docs/help.png" width="860" alt="help: разделы Ввод, Git, Серверы, Своё, Моё"></p>

`help` — всё по разделам. `help git` — один раздел, `help docker` — поиск. **F1** — та же шпаргалка в fzf: нашёл команду, нажал Enter — она в строке ввода.

## Ввод

| | |
|---|---|
| `g␣` `k␣` `d␣` `dc␣` | сокращения раскрываются по пробелу в `git`, `kubectl`, `docker`, `docker compose` — в истории остаются полные команды. `abbr gcm 'git commit -m "%"'` — своё, `%` — где оставить курсор |
| `вщслук зы` ⏎ | набрал в русской раскладке — исправится и выполнится: `docker ps` |
| начни печатать | до 50 подсказок из истории (у PSReadLine встроенный лимит 10), ↑/↓ листать, → принять |
| `h` · `h docker` | последние 50 команд по 10 на экран · с фильтром |
| `Ctrl+R` · `Ctrl+T` · `Alt+C` | fzf: история · вставить путь к файлу · перейти в папку |
| `Ctrl+Backspace` · `Ctrl+Z` · `Shift+Enter` | удалить слово · отменить правку · новая строка |

## `my` — всё про эту машину

<p align="center"><img src="docs/my-sys.png" width="860" alt="my sys: процессор, память, диски, топ процессов"></p>

`my sys` · `my ssh` · `my ports 5432` · `my ip public` · `my k8s` · `my docker` · `my tools` · `my path` · `my git` · `my cmds`

## Своё: команды на любом языке

<p align="center"><img src="docs/my-cmds.png" width="860" alt="my cmds: команды из bin, функции из custom.ps1, сокращения"></p>

```powershell
new weather.py 'погода в городе'     # создаёт bin\weather.py из шаблона и открывает в VS Code
weather Минск                         # уже команда — без перезапуска
```

Файл в `bin\` рядом с профилем = команда. Строка `# help: …` в начале файла — подпись в `help` и `my cmds`.
Чем запускать, решает расширение: `.py` через **uv** (зависимости пишутся прямо в файле — `# /// script`), `.ps1`, `.js`, `.ts` (bun / deno / node), `.sh`, `.go`, `.rs` (rust-script), `.clj` (babashka), `.rb`, `.lua`, `.php`. Скомпилированный `.exe` — просто положи в `bin\`.

`custom.ps1` — свои функции, сокращения и переключатели: он загружается последним и никогда не перезаписывается. Функции из него тоже попадают в `help`. `ep` открывает папку профиля в VS Code; профиль лежит в Документах, так что через OneDrive он уезжает и на другие машины.

## Тема и язык

<p align="center"><img src="docs/themes.png" width="860" alt="theme: mocha, macchiato, frappe, latte"></p>

`theme latte` — и терминал, промпт, подсветка ввода, fzf и диффы переключаются на лету, во всех открытых вкладках. Четыре варианта Catppuccin: `mocha`, `macchiato`, `frappe`, `latte`.

`lang en` / `lang ru` — язык `help`, `my` и всех сообщений; серверы подхватят его при следующем `srv install`.

## Серверы: `srv`

```powershell
srv install prod -Env prod        # поставить или обновить, метка в промпте
srv install                       # без хоста — выбор из ~/.ssh/config
srv remove prod                   # откатить
```

<p align="center"><img src="docs/server.png" width="620" alt="ssh prod-1: sys, проект shop, защита от docker compose down -v"></p>

Одно ssh-подключение, бэкап и пробная загрузка перед заменой, в `~/.bashrc` добавляется одна строка. Повторный запуск ничего не ломает. **Ничего не устанавливается и ничего не работает в фоне** — только функции в твоей оболочке, поэтому можно ставить на prod.

- **Проекты находятся сами** (`docker compose ls`) и запоминаются. Для каждого — команда с его именем: `shop`, `shop logs web`, `shop sh web`, `shop restart web`, `app shop`. Tab дополняет сервисы. `proj` — все проекты, `proj add` — добавить папку вручную.
- **Промпт** с меткой окружения (`prod` — красная, `staging` — жёлтая, `dev` — зелёная), веткой git, временем долгой команды и кодом ошибки.
- **Защита**: `docker compose down -v`, `volume rm`, `system prune` просят набрать `yes`; `rm`, `cp`, `mv` спрашивают перед массовым удалением. Скрипты это не затрагивает.
- `sys` — нагрузка, память, диск, процессы, контейнеры. `help` — шпаргалка с поиском. `bak file` — копия перед правкой, `ex archive` — распаковать, `h` — история.
- **Своё для серверов**: файлы из `server\custom\*.sh` рядом с профилем уезжают на каждый сервер в `~/.bashrc.d/`. Скрипты в `~/bin` и строки `# help: имя — описание` попадают в `help` на сервере.

## Как устроено

```
install.ps1           однострочный установщик: скачивает setup-terminal.ps1 и запускает
setup-terminal.ps1    всё в одном файле — собирается из src/, не править руками
build.ps1             .\build.ps1  ·  .\build.ps1 -FromProfile — забрать настройку с этой машины
src/
  setup-logic.ps1     логика установки
  profile/            профиль, palette.ps1, lang.ps1, toolkit.ps1 (команды), custom.ps1 (шаблон), плагин подсказок
  ohmyposh/           тема промпта
  server/             bashrc.local, inputrc и установщик для srv
tools/                make-screenshots.ps1 — картинки в docs/ из настоящего вывода команд
```

Поменять под себя: правь файлы в папке профиля (`ep`), затем `.\build.ps1 -FromProfile`, коммит, пуш — следующая установка возьмёт новую версию.

**Откат**: рядом с каждым изменённым файлом лежит `*.bak-<дата>`; на сервере — `srv remove <хост>`.
