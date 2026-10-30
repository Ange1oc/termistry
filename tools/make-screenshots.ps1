<#
.SYNOPSIS
  Делает скриншоты для README из настоящего вывода команд: docs\*.png.
  Ничего личного не попадает: демо-проект во временной папке, демо-kubeconfig,
  имя компьютера заменяется. Сервер — из WSL с поддельным docker.

.EXAMPLE
  .\tools\make-screenshots.ps1
#>
param([string]$OutDir = (Join-Path $PSScriptRoot '..\docs'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$render = Join-Path $PSScriptRoot 'render-terminal.ps1'
$OutDir = (New-Item -ItemType Directory -Force $OutDir).FullName
$work = Join-Path ([IO.Path]::GetTempPath()) 'terminal-setup-shots'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force "$work\home\profile\bin", "$work\home\profile\server", "$work\home\.config\ohmyposh", "$work\home\.cache" | Out-Null

# ── Демо-окружение ───────────────────────────────────────────────────────────
Copy-Item "$root\src\profile\*" "$work\home\profile" -Recurse -Force
Copy-Item "$root\src\server\*" "$work\home\profile\server" -Recurse -Force
Copy-Item "$root\src\ohmyposh\soft.omp.json" "$work\home\.config\ohmyposh\soft.omp.json"
@'
# help: погода в городе
import sys
print("sunny in", *sys.argv[1:])
'@ | Set-Content "$work\home\profile\bin\weather.py" -Encoding utf8
@'
function deploy { ssh prod 'cd ~/shop && git pull && docker compose up -d --build' }
abbr dcu 'docker compose up -d --build'
'@ | Add-Content "$work\home\profile\custom.ps1" -Encoding utf8

$demo = Join-Path $work 'shop'
New-Item -ItemType Directory -Force "$demo\src", "$demo\deploy" | Out-Null
'{ "name": "shop", "version": "2.4.0", "private": true, "scripts": { "dev": "node src/index.js" } }' | Set-Content "$demo\package.json"
"import http from 'node:http';`nhttp.createServer((_, res) => res.end('ok')).listen(3000);" | Set-Content "$demo\src\index.js"
"services:`n  web:`n    build: .`n    ports: ['3000:3000']`n  db:`n    image: postgres:16" | Set-Content "$demo\docker-compose.yml"
"FROM node:24-alpine`nCOPY . .`nCMD [`"node`", `"src/index.js`"]" | Set-Content "$demo\Dockerfile"
"# shop`n" | Set-Content "$demo\README.md"
"DATABASE_URL=postgres://localhost/shop" | Set-Content "$demo\.env.example"
"#!/usr/bin/env bash`nset -e`ndocker compose up -d --build" | Set-Content "$demo\deploy\release.sh"
Push-Location $demo
git init -q -b main; git config user.email ''; git config user.name 'demo'
git add -A; git commit -q -m 'init'
"# shop`n`nИнтернет-магазин. Запуск: npm run dev" | Set-Content "$demo\README.md"
"export const VERSION = '2.4.0';" | Set-Content "$demo\src\version.js"
git add src/version.js
Pop-Location

$kube = Join-Path $work 'kubeconfig'
@"
apiVersion: v1
kind: Config
current-context: prod
contexts:
- name: prod
  context: { cluster: prod, user: admin, namespace: shop }
clusters:
- name: prod
  cluster: { server: https://10.0.0.1 }
users:
- name: admin
  user: {}
"@ | Set-Content $kube

# ── Сцены на PowerShell: capture.ps1 выполняется в отдельном pwsh с демо-профилем
$capture = @"
[Console]::OutputEncoding = [Text.Encoding]::UTF8
`$PSStyle.OutputRendering = 'Ansi'
`$env:KUBECONFIG = '$kube'
`$PROFILE = '$work\home\profile\Microsoft.PowerShell_profile.ps1'
. `$PROFILE *> `$null
`$omp = '$work\home\.config\ohmyposh\soft.omp.json'
`$env:POSH_THEME = `$omp      # профиль выставил свою тему — для сцен нужна копия из src
`$W = 100
function Prompt-Line([string]`$Dir, [int]`$Status = 0, [int]`$Ms = 0) {
    `$a = @('print', 'primary', '--config', `$omp, '--shell', 'pwsh', '--pwd', `$Dir, '--terminal-width', `$W)
    if (`$Status) { `$a += @('--status', `$Status) }
    if (`$Ms) { `$a += @('--execution-time', `$Ms) }
    (((& oh-my-posh @a) -join "``n") -replace "``e\]0;[^``a]*``a", '').TrimEnd("``n")
}
function Typed([string]`$Cmd) {     # как подсветит PSReadLine: команда, параметры, строки
    `$p = `$global:Palette
    `$tokens = `$Cmd -split ' '
    `$out = for (`$i = 0; `$i -lt `$tokens.Count; `$i++) {
        `$t = `$tokens[`$i]
        `$c = if (`$i -eq 0) { `$p.blue } elseif (`$t -like '-*') { `$p.teal } elseif (`$t -match '^[''"]') { `$p.green } else { `$p.text }
        `$PSStyle.Foreground.FromRgb(`$c) + `$t + `$PSStyle.Reset
    }
    `$out -join ' '
}
function Capture([scriptblock]`$Block) { ((& `$Block *>&1) | ForEach-Object { "`$_" }) -join "``n" }
# временная папка демо-проекта показывается как ~\code
function Scene([string]`$Name, [string]`$Text) {
    `$Text = `$Text.Replace('~\..\Temp\terminal-setup-shots', '~\code').Replace('$work', '~\code')
    [IO.File]::WriteAllText('$work\' + `$Name + '.txt', `$Text, [Text.UTF8Encoding]::new(`$false))
}
function Demo([string]`$Text) { `$Text.Replace(`$env:COMPUTERNAME, 'workstation') }

Set-Location '$demo'
# 1. hero: промпт в проекте, ll, промпт после долгой упавшей команды
`$hero = @(
    (Prompt-Line '$demo') + (Typed 'll')
    (Capture { eza --icons=always --group-directories-first --color=always -la --git --time-style=relative --no-user . })
    (Prompt-Line '$demo' 0 0) + (Typed 'docker compose up -d --build')
    (`$PSStyle.Foreground.FromRgb(`$Palette.overlay0) + '… ' + `$PSStyle.Reset)
    (Prompt-Line '$demo' 1 4200)
) -join "``n"
Scene 'hero' `$hero

# 2. help: несколько разделов + «Моё» (bin, custom.ps1, сокращения)
Scene 'help' (Capture { Show-TkHelp (@(`$TkSections | Where-Object { `$_.Key -in 'input', 'git', 'ssh', 'mine' }) + @(Get-TkUserSection)) })

# 3. my sys (имя компьютера заменено, контейнеры убраны)
`$sys = Capture { my sys }
`$cut = `$sys.IndexOf('контейнеры'); if (`$cut -gt 0) { `$sys = `$sys.Substring(0, `$sys.LastIndexOf("``n", `$cut)).TrimEnd() }
Scene 'my-sys' ((Prompt-Line '$demo') + (Typed 'my sys') + "``n" + (Demo `$sys))

# 4. my cmds + new
Scene 'my-cmds' ((Prompt-Line '$demo') + (Typed 'my cmds') + "``n" + (Capture { my cmds }).Replace('$work\home\profile', '~\Documents\PowerShell'))

# 5. тема — одна и та же сцена в четырёх вариантах
foreach (`$f in 'mocha', 'macchiato', 'frappe', 'latte') {
    `$env:TERMINAL_THEME = `$f; `$global:ThemeName = `$f; `$global:Palette = `$CatppuccinFlavors[`$f]; Set-TerminalPalette
    `$t = @(
        (Prompt-Line '$demo') + (Typed 'theme')
        (Capture { theme })
        (Prompt-Line '$demo') + (Typed 'help git')
        (Capture { Show-TkHelp (`$TkSections | Where-Object Key -eq 'git') })
    ) -join "``n"
    Scene "theme-`$f" `$t
}
"@
[IO.File]::WriteAllText("$work\capture.ps1", $capture, [Text.UTF8Encoding]::new($false))
Write-Host '  захват PowerShell…'
& (Get-Command pwsh).Source -NoProfile -NoLogo -File "$work\capture.ps1"

# ── Сцена на сервере: WSL, временный HOME, поддельный docker ─────────────────
$serverScript = @'
set -e
T=$(mktemp -d); export HOME=$T/home; mkdir -p "$HOME/apps/shop" "$HOME/apps/api" "$HOME/bin" "$T/bin"
cp /etc/skel/.bashrc "$HOME/.bashrc"
printf 'PROMPT_ENV=prod\n' > /dev/null
cat > "$T/bin/docker" <<'EOF'
#!/bin/bash
case "$*" in
  "compose ls -a --format json") printf '[{"Name":"shop","Status":"running(4)","ConfigFiles":"%s/apps/shop/docker-compose.yml"},{"Name":"api","Status":"exited(1), running(2)","ConfigFiles":"%s/apps/api/docker-compose.yml"}]\n' "$HOME" "$HOME" ;;
  "compose config --services") printf 'web\ndb\nworker\n' ;;
  compose\ ps*) printf 'web\tUp 3 days\ndb\tUp 3 days (healthy)\nvalkey\tUp 3 days (healthy)\nmigrate\tExited (0) 3 days ago\nworker\tExited (137) 2 hours ago\n' ;;
  ps\ -a*) printf 'shop-web-1\tUp 3 days\nshop-db-1\tUp 3 days (healthy)\nshop-valkey-1\tUp 3 days (healthy)\nshop-migrate-1\tExited (0) 3 days ago\nshop-worker-1\tExited (137) 2 hours ago\napi-web-1\tUp 5 hours\napi-db-1\tUp 5 hours (healthy)\n' ;;
  *) echo "docker $*" ;;
esac
EOF
chmod +x "$T/bin/docker"; export PATH=$T/bin:$PATH
printf '#!/bin/bash\n# help: бэкап базы в S3\n' > "$HOME/bin/backup-db"; chmod +x "$HOME/bin/backup-db"
mkdir -p "$HOME/.config" "$HOME/.bashrc.d"; printf 'PROMPT_ENV=prod\n' > "$HOME/.config/bashrc-local.conf"
cp "$1" "$HOME/.bashrc.local"
cd "$HOME/apps/shop"; git init -q -b main 2>/dev/null; git -c user.email= -c user.name=d commit -q --allow-empty -m init 2>/dev/null; echo x > new.txt; git add new.txt
host=$(hostname); me=$(whoami)
fix() { sed -e "s/$host/prod-1/g" -e "s/\b$me\b/deploy/g" -e 's/\x01//g; s/\x02//g'; }
bash --norc -i -c '
  source ~/.bashrc.local 2>/dev/null
  printf "\e[90m  проекты: shop api · help — шпаргалка · sys — состояние сервера\e[0m\n"
  __ts=$((SECONDS-12)); __prompt; printf "%s" "${PS1@P}"; printf "sys\n"; sys
  true; __prompt; printf "%s" "${PS1@P}"; printf "shop\n"; shop
  __prompt; printf "%s" "${PS1@P}"; printf "shop logs worker\n"
  printf "\e[90mdocker compose logs -f --tail=200 worker …\e[0m\n"
  __prompt; printf "%s" "${PS1@P}"; printf "shop down -v\n"; echo no | shop down -v 2>&1 | tail -n 2
  false; __prompt; printf "%s" "${PS1@P}"
' 2>&1 | grep -v -e 'job control' -e 'process group' | fix
rm -rf "$T"
'@
[IO.File]::WriteAllText("$work\server.sh", ($serverScript -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
Write-Host '  захват сервера (WSL)…'
$wslWork = wsl wslpath -a ($work -replace '\\', '/')
$wslBashrc = wsl wslpath -a (($root -replace '\\', '/') + '/src/server/bashrc.local')
$serverOut = wsl bash "$wslWork/server.sh" "$wslBashrc"
[IO.File]::WriteAllText("$work\server.txt", (($serverOut -join "`n") -replace "`r", ''), [Text.UTF8Encoding]::new($false))

# ── Рендер ───────────────────────────────────────────────────────────────────
Write-Host '  рендер…'
& $render -InputFile "$work\hero.txt" -OutFile "$OutDir\hero.png" -Title 'PowerShell 7 · Windows Terminal'
& $render -InputFile "$work\help.txt" -OutFile "$OutDir\help.png" -Title 'help'
& $render -InputFile "$work\my-sys.txt" -OutFile "$OutDir\my-sys.png" -Title 'my sys'
& $render -InputFile "$work\my-cmds.txt" -OutFile "$OutDir\my-cmds.png" -Title 'my cmds'
& $render -InputFile "$work\server.txt" -OutFile "$OutDir\server.png" -Title 'ssh prod-1 — bash'
foreach ($f in 'mocha', 'macchiato', 'frappe', 'latte') {
    & $render -InputFile "$work\theme-$f.txt" -OutFile "$work\theme-$f.png" -Title "theme $f" -Flavor $f -MinColumns 84 -MaxColumns 84
}

# 2×2 сетка тем
$imgs = 'mocha', 'macchiato', 'frappe', 'latte' | ForEach-Object { [Drawing.Image]::FromFile("$work\theme-$_.png") }
$cw = ($imgs | Measure-Object Width -Maximum).Maximum; $ch = ($imgs | Measure-Object Height -Maximum).Maximum
$grid = [Drawing.Bitmap]::new([int](2 * $cw), [int](2 * $ch))
$g = [Drawing.Graphics]::FromImage($grid); $g.Clear([Drawing.Color]::Transparent)
for ($i = 0; $i -lt 4; $i++) { $g.DrawImage($imgs[$i], [int](($i % 2) * $cw), [int]([math]::Floor($i / 2) * $ch)) }
$grid.Save("$OutDir\themes.png", [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $grid.Dispose(); $imgs | ForEach-Object { $_.Dispose() }
"  ✓ $OutDir\themes.png"
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
