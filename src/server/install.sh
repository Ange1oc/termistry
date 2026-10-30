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
    echo "${dim}~/.config/projects, ~/.config/bashrc-local.conf и ~/.bashrc.d оставлены${r}"
    exit 0
fi

# __put <путь от ~> <base64> — записать файл, если он отличается (свои файлы из server\custom)
__put() {
    local target=~/"$1" tmp
    tmp=$(mktemp)
    printf '%s' "$2" | base64 -d > "$tmp"
    mkdir -p "${target%/*}"
    if [ -f "$target" ] && cmp -s "$tmp" "$target"; then rm -f "$tmp"; echo "$ok ~/$1 уже актуален"; return; fi
    cat "$tmp" > "$target"; rm -f "$tmp"
    echo "$ok ~/$1"
}

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

# 6. свои файлы для серверов: server\custom\*.sh → ~/.bashrc.d/
mkdir -p ~/.bashrc.d
__CUSTOM_FILES__

# 7. при входе по ssh bash читает .bash_profile/.profile — они должны подтягивать .bashrc
if [ -f ~/.bash_profile ]; then
    grep -q 'bashrc' ~/.bash_profile || echo "$warn ~/.bash_profile не подключает ~/.bashrc — добавь: [ -f ~/.bashrc ] && . ~/.bashrc"
elif [ ! -f ~/.bash_login ] && [ ! -f ~/.profile ]; then
    printf '%s\n' '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.bash_profile
    echo "$ok создан ~/.bash_profile (подключает ~/.bashrc при входе)"
fi

# 8. итог
projects=$(bash --norc -i -c '. ~/.bashrc.local; printf "%s " "${!PROJ_DIR[@]}"' </dev/null 2>/dev/null || true)
echo "${dim}проекты: ${projects:-нет} · перезайди по ssh, затем help${r}"
# end
