<h1 align="center">terminal-setup</h1>

<p align="center">
A good-looking, convenient terminal on Windows 11 — in one command.<br>
The same bash on your servers — in one more.
</p>

<p align="center"><a href="README.md">Русский</a> · English</p>

<p align="center"><img src="docs/hero.png" width="860" alt="PowerShell 7 in Windows Terminal: prompt with git branch, node version, kubernetes context, duration of a long command"></p>

## Install

Open PowerShell (a regular one, not as administrator) and paste:

```powershell
irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1 | iex
```

It asks for the language (`ru`/`en`). Then close all Windows Terminal windows, open it again and press **F1**.

- Works on a bare Windows 11 or 10: installs PowerShell 7 itself and continues in it.
- Asks for administrator rights once — only for the icon font (Windows Terminal cannot see per-user fonts).
- **Safe to run again** — every step checks what is already done. That is also how you update.
- Any file that differs is saved next to the new one as `*.bak-<date>`. Your `custom.ps1` and `bin\` are never touched.

<details>
<summary>Parameters</summary>

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Ange1oc/terminal-setup/main/install.ps1))) -Lang en -Theme latte -SshTabs prod,staging
```

| | |
|---|---|
| `-Lang ru\|en` | UI language (later: `lang en`) |
| `-Theme mocha\|macchiato\|frappe\|latte` | palette flavor (later: `theme latte`) |
| `-StartingDirectory D:\code` | where a new tab opens |
| `-SshTabs host1,host2` | tabs in the terminal menu for hosts from `~/.ssh/config` |
| `-SkipApps` | configs only, no programs or font |

Offline machine: download [`setup-terminal.ps1`](setup-terminal.ps1) and run `powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1`.

</details>

## What is inside

| | |
|---|---|
| **Programs** | PowerShell 7, Windows Terminal, git, oh-my-posh, fzf, zoxide, eza, bat, ripgrep, fd, delta, lazygit, tldr, gh — via winget, only what is missing |
| **Look** | the [Catppuccin](https://catppuccin.com) palette everywhere: terminal, prompt, input highlighting, `ls`, fzf, diffs; JetBrainsMono Nerd Font |
| **Prompt** | folder, git branch and changes, node / python / go / rust version inside a project, kubernetes context, duration of long commands, exit code |
| **Input** | syntax highlighting, up to 50 history suggestions, abbreviations, keyboard-layout fix, ↑/↓ by prefix |
| **Completions** | kubectl, helm, docker, gh, kind, minikube, ssh hosts — cached, fast startup |
| **Windows Terminal** | PowerShell 7 by default, `Win+\`` drop-down terminal, four theme flavors |
| **Servers** | `srv install <host>` — the same prompt, cheat sheet and guards on Linux, nothing installed |

## The cheat sheet is always at hand

<p align="center"><img src="docs/help.png" width="860" alt="help: Input, Git, Servers, Mine sections"></p>

`help` — everything by section. `help git` — one section, `help docker` — search. **F1** — the same cheat sheet in fzf: find a command, press Enter — it is in the input line.

## Input

| | |
|---|---|
| `g␣` `k␣` `d␣` `dc␣` | abbreviations expand on space into `git`, `kubectl`, `docker`, `docker compose` — history keeps full commands. `abbr gcm 'git commit -m "%"'` — your own, `%` is where the cursor goes |
| `вщслук зы` ⏎ | typed in the Russian layout — fixed and executed: `docker ps` |
| start typing | up to 50 suggestions from history (PSReadLine's built-in limit is 10), ↑/↓ to scroll, → to accept |
| `h` · `h docker` | last 50 commands, 10 per page · filtered |
| `Ctrl+R` · `Ctrl+T` · `Alt+C` | fzf: history · insert a file path · go to a folder |
| `Ctrl+Backspace` · `Ctrl+Z` · `Shift+Enter` | delete word · undo · new line |

## `my` — everything about this machine

<p align="center"><img src="docs/my-sys.png" width="860" alt="my sys: cpu, memory, disks, top processes"></p>

`my sys` · `my ssh` · `my ports 5432` · `my ip public` · `my k8s` · `my docker` · `my tools` · `my path` · `my git` · `my cmds`

## Yours: commands in any language

<p align="center"><img src="docs/my-cmds.png" width="860" alt="my cmds: commands from bin, functions from custom.ps1, abbreviations"></p>

```powershell
new weather.py 'weather in a city'   # creates bin\weather.py from a template and opens it in VS Code
weather Minsk                        # already a command — no restart
```

A file in `bin\` next to the profile = a command. A `# help: …` line at the top is the caption in `help` and `my cmds`.
The extension picks the runner: `.py` via **uv** (dependencies right in the file — `# /// script`), `.ps1`, `.js`, `.ts` (bun / deno / node), `.sh`, `.go`, `.rs` (rust-script), `.clj` (babashka), `.rb`, `.lua`, `.php`. A compiled `.exe` — just drop it into `bin\`.

`custom.ps1` — your functions, abbreviations and switches: loaded last, never overwritten. Its functions show up in `help` too. `ep` opens the profile folder in VS Code; the profile lives in Documents, so OneDrive carries it to your other machines.

## Theme and language

<p align="center"><img src="docs/themes.png" width="860" alt="theme: mocha, macchiato, frappe, latte"></p>

`theme latte` — the terminal, prompt, input highlighting, fzf and diffs switch live, in every open tab. Four Catppuccin flavors: `mocha`, `macchiato`, `frappe`, `latte`.

`lang en` / `lang ru` — the language of `help`, `my` and every message; servers pick it up on the next `srv install`.

## Servers: `srv`

```powershell
srv install prod -Env prod        # install or update, label in the prompt
srv install                       # no host — pick from ~/.ssh/config
srv remove prod                   # roll back
```

<p align="center"><img src="docs/server.png" width="620" alt="ssh prod-1: sys, project shop, guard against docker compose down -v"></p>

One ssh connection, backup and a trial load before replacing anything, one line added to `~/.bashrc`. Running again breaks nothing. **Nothing is installed and nothing runs in the background** — only functions in your shell, so it is fine on production.

- **Projects are discovered** (`docker compose ls`) and remembered. Each gets a command of its own name: `shop`, `shop logs web`, `shop sh web`, `shop restart web`, `app shop`. Tab completes services. `proj` — all projects, `proj add` — add a folder by hand.
- **Prompt** with an environment label (`prod` — red, `staging` — yellow, `dev` — green), git branch, duration of long commands and exit code.
- **Guards**: `docker compose down -v`, `volume rm`, `system prune` ask you to type `yes`; `rm`, `cp`, `mv` ask before mass changes. Scripts are unaffected.
- `sys` — load, memory, disk, processes, containers. `help` — cheat sheet with search. `bak file` — a copy before editing, `ex archive` — extract, `h` — history.
- **Yours for servers**: files from `server\custom\*.sh` next to the profile go to every server into `~/.bashrc.d/`. Scripts in `~/bin` and `# help: name — description` lines show up in `help` on the server.

## How it is built

```
install.ps1           one-line installer: downloads setup-terminal.ps1 and runs it
setup-terminal.ps1    everything in one file — built from src/, do not edit by hand
build.ps1             .\build.ps1  ·  .\build.ps1 -FromProfile — pull the setup from this machine
src/
  setup-logic.ps1     installer logic
  profile/            profile, palette.ps1, lang.ps1, toolkit.ps1 (commands), custom.ps1 (template), suggestions plugin
  ohmyposh/           prompt theme
  server/             bashrc.local, inputrc and the installer behind srv
tools/                make-screenshots.ps1 — the images in docs/ come from real command output
```

Make it yours: edit the files in the profile folder (`ep`), then `.\build.ps1 -FromProfile`, commit, push — the next install picks up the new version.

**Rollback**: every changed file has a `*.bak-<date>` next to it; on a server — `srv remove <host>`.
