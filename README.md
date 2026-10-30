# terminal-setup

Красивый и удобный терминал на Windows 11 — одной командой. Мягкая палитра [Catppuccin Mocha](https://catppuccin.com) везде: Windows Terminal, промпт, подсветка ввода, `ls`, `fzf`, диффы git. Плюс шпаргалка `help`, подсказки из истории, быстрые команды и такой же удобный bash на Linux-серверах.

## Установка

Открой **PowerShell** (обычный, не от администратора) и вставь:

```powershell
irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1 | iex
```

Потом закрой все окна Windows Terminal, открой заново и набери `help`.

- Работает на голой Windows 11 (и Windows 10 с winget): сам поставит PowerShell 7 и продолжит в нём.
- Права администратора попросит один раз (UAC) — только чтобы поставить шрифт для всех пользователей: шрифты «только для меня» Windows Terminal не видит.
- **Запускать повторно безопасно**: каждый шаг сначала проверяет, что уже сделано. Так же и обновляться.
- Любой файл, который отличается от нового, перед заменой сохраняется рядом как `*.bak-<дата-время>`.

<details>
<summary>С параметрами</summary>

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1))) -StartingDirectory D:\code -SshTabs myserver,staging
```

| Параметр | Что делает |
|---|---|
| `-StartingDirectory <папка>` | где открывается новая вкладка PowerShell 7 |
| `-SshTabs host1,host2` | вкладки в меню Windows Terminal для хостов из `~/.ssh/config` |
| `-SkipApps` | не ставить программы и шрифт — только конфиги |

Или скачай [`setup-terminal.ps1`](setup-terminal.ps1) и запусти: `powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1`

</details>

## Что ставится и настраивается

| | |
|---|---|
| **Программы** (через winget, если ещё нет) | PowerShell 7, Windows Terminal, git, oh-my-posh, fzf, zoxide, eza, bat, ripgrep, fd, delta |
| **Шрифт** | JetBrainsMono Nerd Font — с иконками, для всех пользователей |
| **Windows Terminal** | PowerShell 7 по умолчанию, схема и тема Catppuccin Mocha, шрифт, отступы, курсор |
| **Промпт** | двухстрочный: папка, ветка git и изменения, время долгой команды, код ошибки, venv |
| **Ввод** | подсветка синтаксиса, до 50 подсказок из истории (встроенный лимит PSReadLine — 10), ↑/↓ по началу команды, Tab-меню |
| **Автодополнения** | kubectl, helm, docker, gh, kind, minikube — кэшируются, старт быстрый |
| **VS Code** | шрифт с иконками во встроенном терминале |
| **git** | диффы через delta в тех же цветах |

## Команды

Набери `help` — там всё. Коротко:

| Команда | Что делает |
|---|---|
| `help` · `help git` · `help docker` | шпаргалка целиком · раздел · поиск |
| `my` | мои данные: `my ssh`, `my ports`, `my ip`, `my path`, `my tools`, `my git` |
| `h` · `h docker` | последние 50 команд, листаются по 10 · с фильтром |
| `Ctrl+R` · `Ctrl+T` · `Alt+C` | поиск по истории · вставить путь к файлу · перейти в папку (fzf) |
| `z <часть имени>` | прыжок в папку, где часто бываешь |
| `l` · `ll` · `lt` | список файлов · подробно с git-статусом · деревом |
| `jump` | выбрать SSH-сервер из списка и подключиться |
| `srv install <хост>` | поставить такой же bash на Linux-сервер |

## Серверы: `srv`

```powershell
srv install myserver -Env prod     # поставить или обновить
srv install                        # без хоста — выбор из ~/.ssh/config
srv remove myserver                # откатить
```

Одно ssh-подключение на сервер (не упирается в `ufw limit`), перед заменой — бэкап и пробная загрузка, повторный запуск ничего не ломает. Ставится только в домашнюю папку пользователя, в `~/.bashrc` добавляется одна строка.

Что получает сервер:

- **Промпт** как на Windows, с меткой окружения: `prod` — красная, `staging`/`test` — жёлтая, `dev` — зелёная.
- **Проекты находятся сами** (`docker compose ls`) и запоминаются в `~/.config/projects` — переживают даже `down`. Для каждого появляется команда с его именем:

  ```bash
  proj                  # все проекты: статус и папка
  myapp                 # статус контейнеров
  myapp logs web        # последние 200 строк и дальше поток
  myapp sh web          # shell внутри контейнера
  myapp restart web     # любая docker compose команда
  app myapp             # перейти в папку проекта
  proj add [имя] [папка]   # добавить вручную
  ```

  Tab дополняет подкоманды и имена сервисов. Если имя проекта совпадает с существующей командой (`git`, `nginx`…), работает через `proj <имя> …`.
- **Защита**: `docker compose down -v`, `docker volume rm/prune`, `docker system prune` просят набрать `yes`; `rm`, `cp`, `mv` спрашивают перед массовым удалением и перезаписью (скрипты это не затрагивает).
- `sys` — нагрузка, память, диск, контейнеры цветом. `help` — шпаргалка.
- Большая общая история с датами, ↑/↓ по началу команды, Tab без учёта регистра.

## Как устроено

```
install.ps1           однострочный установщик: скачивает setup-terminal.ps1 и запускает
setup-terminal.ps1    всё в одном файле — собирается из src/ (не править руками)
build.ps1             сборка: .\build.ps1  ·  .\build.ps1 -FromProfile — забрать настройку с машины
src/
  setup-logic.ps1     логика установки
  profile/            профиль PowerShell, команды (toolkit.ps1), плагин подсказок
  ohmyposh/           тема промпта
  server/             bashrc.local, inputrc и установщик для srv
```

Поменять что-то под себя: правь файлы в профиле (`ep` открывает его папку в VS Code), затем `.\build.ps1 -FromProfile`, коммит и пуш — следующая установка возьмёт новую версию.

**Откат**: рядом с каждым изменённым файлом лежит `*.bak-<дата-время>`; на сервере — `srv remove <хост>`.
