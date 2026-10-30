# Runs on the server through `ssh host 'bash -s'`; placeholders __…__ are filled by srv (PowerShell).
set -eu
umask 022

action='__ACTION__'
env_label='__ENV__'
lang='__LANG__'
[[ $lang == en ]] || lang=ru
ts=$(date +%Y%m%d-%H%M%S)
ok=$'\e[32m✓\e[0m' warn=$'\e[33m!\e[0m' bad=$'\e[31m✗\e[0m' dim=$'\e[90m' r=$'\e[0m'
conf=~/.config/bashrc-local.conf
hook='[ -f ~/.bashrc.local ] && . ~/.bashrc.local   # prompt, history, helpers (srv)'

declare -A M_ru=(
    [removed_hook]='строка подключения убрана из ~/.bashrc' [backup]='бэкап' [kept]='~/.config/projects, ~/.config/bashrc-local.conf и ~/.bashrc.d оставлены'
    [uptodate]='уже актуален' [syntax_err]='синтаксическая ошибка - ничего не меняю' [load_err]='пробная загрузка с ошибками - ничего не меняю:'
    [checked]='проверка: синтаксис и пробная загрузка' [label]='метка' [none]='нет' [lang]='язык' [migrated]='метка перенесена из старой версии'
    [created]='создан' [hook_present]='~/.bashrc уже подключает ~/.bashrc.local' [hook_added]='~/.bashrc: добавлена строка подключения'
    [profile_warn]='~/.bash_profile не подключает ~/.bashrc - добавь: [ -f ~/.bashrc ] && . ~/.bashrc' [profile_created]='создан ~/.bash_profile (подключает ~/.bashrc при входе)'
    [projects]='проекты' [relogin]='перезайди по ssh, затем help'
)
declare -A M_en=(
    [removed_hook]='hook line removed from ~/.bashrc' [backup]='backup' [kept]='~/.config/projects, ~/.config/bashrc-local.conf and ~/.bashrc.d kept'
    [uptodate]='already up to date' [syntax_err]='syntax error - nothing changed' [load_err]='trial load failed - nothing changed:'
    [checked]='checked: syntax and trial load' [label]='label' [none]='none' [lang]='language' [migrated]='label migrated from the old version'
    [created]='created' [hook_present]='~/.bashrc already sources ~/.bashrc.local' [hook_added]='~/.bashrc: hook line added'
    [profile_warn]='~/.bash_profile does not source ~/.bashrc - add: [ -f ~/.bashrc ] && . ~/.bashrc' [profile_created]='created ~/.bash_profile (sources ~/.bashrc on login)'
    [projects]='projects' [relogin]='reconnect over ssh, then help'
)
m() { local v="M_${lang}[$1]"; printf '%s' "${!v}"; }

echo "${dim}$(whoami)@$(hostname) · $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") · bash ${BASH_VERSION%%(*}${r}"

if [ "$action" = remove ]; then
    if [ -f ~/.bashrc ] && grep -qF '.bashrc.local' ~/.bashrc; then
        cp -p ~/.bashrc ~/.bashrc.bak-$ts
        grep -vF '.bashrc.local' ~/.bashrc.bak-$ts > ~/.bashrc || true
        echo "$ok $(m removed_hook) ${dim}($(m backup) ~/.bashrc.bak-$ts)${r}"
    fi
    if [ -f ~/.bashrc.local ]; then
        mv ~/.bashrc.local ~/.bashrc.local.off-$ts
        echo "$ok ~/.bashrc.local → ~/.bashrc.local.off-$ts"
    fi
    if [ -f ~/.inputrc ] && grep -q 'srv: managed' ~/.inputrc; then
        mv ~/.inputrc ~/.inputrc.off-$ts
        echo "$ok ~/.inputrc → ~/.inputrc.off-$ts"
    fi
    echo "${dim}$(m kept)${r}"
    exit 0
fi

__put() {
    local target=~/"$1" tmp
    tmp=$(mktemp)
    printf '%s' "$2" | base64 -d > "$tmp"
    mkdir -p "${target%/*}"
    if [ -f "$target" ] && cmp -s "$tmp" "$target"; then rm -f "$tmp"; echo "$ok ~/$1 $(m uptodate)"; return; fi
    cat "$tmp" > "$target"; rm -f "$tmp"
    echo "$ok ~/$1"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf '%s' '__BASHRC_B64__' | base64 -d > "$work/bashrc.local"
printf '%s' '__INPUTRC_B64__' | base64 -d > "$work/inputrc"

mkdir -p ~/.bashrc.d
__CUSTOM_FILES__

bash -n "$work/bashrc.local" || { echo "$bad $(m syntax_err)"; exit 1; }
errors=$(HOME=$HOME bash --norc -i -c ". '$work/bashrc.local'" </dev/null 2>&1 >/dev/null |
    grep -v -e 'job control' -e 'terminal process group' -e 'Inappropriate ioctl' || true)
if [ -n "$errors" ]; then
    echo "$bad $(m load_err)"; echo "$errors"; exit 1
fi
echo "$ok $(m checked)"

mkdir -p ~/.config
{ [ -f "$conf" ] && grep -v -e '^PROMPT_ENV=' -e '^LANG_UI=' "$conf" || true; } > "$work/conf"
if [ -n "$env_label" ]; then
    [ "$env_label" = none ] && env_label=''
elif [ -f "$conf" ]; then
    env_label=$(sed -n 's/^PROMPT_ENV=\([A-Za-z0-9_-]*\).*/\1/p' "$conf" | head -n1)
elif [ -f ~/.bashrc.local ]; then
    env_label=$(sed -n 's/^PROMPT_ENV=\([A-Za-z0-9_-]*\).*/\1/p' ~/.bashrc.local | head -n1)
    [ -n "$env_label" ] && echo "$ok $(m migrated): $env_label"
fi
printf 'PROMPT_ENV=%s\nLANG_UI=%s\n' "$env_label" "$lang" >> "$work/conf"
cat "$work/conf" > "$conf"
echo "$ok $(m label): ${env_label:-$(m none)} · $(m lang): $lang"

old_ver=$(sed -n 's/^# version: //p' ~/.bashrc.local 2>/dev/null | head -n1 || true)
new_ver=$(sed -n 's/^# version: //p' "$work/bashrc.local" | head -n1)
if [ -f ~/.bashrc.local ] && cmp -s "$work/bashrc.local" ~/.bashrc.local; then
    echo "$ok ~/.bashrc.local $(m uptodate) ${dim}($new_ver)${r}"
else
    if [ -f ~/.bashrc.local ]; then
        cp -p ~/.bashrc.local ~/.bashrc.local.bak-$ts
        echo "$ok $(m backup): ~/.bashrc.local.bak-$ts"
    fi
    cat "$work/bashrc.local" > ~/.bashrc.local
    echo "$ok ~/.bashrc.local ${dim}${old_ver:-$(m none)} → ${r}$new_ver"
fi

if [ -f ~/.inputrc ] && cmp -s "$work/inputrc" ~/.inputrc; then
    echo "$ok ~/.inputrc $(m uptodate)"
else
    if [ -f ~/.inputrc ]; then
        cp -p ~/.inputrc ~/.inputrc.bak-$ts
        echo "$ok $(m backup): ~/.inputrc.bak-$ts"
    fi
    cat "$work/inputrc" > ~/.inputrc
    echo "$ok ~/.inputrc"
fi

if [ ! -f ~/.bashrc ]; then
    if [ -f /etc/skel/.bashrc ]; then cp /etc/skel/.bashrc ~/.bashrc; else : > ~/.bashrc; fi
    echo "$ok ~/.bashrc $(m created)"
fi
if grep -qF '.bashrc.local' ~/.bashrc; then
    echo "$ok $(m hook_present)"
else
    cp -p ~/.bashrc ~/.bashrc.bak-$ts
    printf '\n%s\n' "$hook" >> ~/.bashrc
    echo "$ok $(m hook_added) ${dim}($(m backup) ~/.bashrc.bak-$ts)${r}"
fi

if [ -f ~/.bash_profile ]; then
    grep -q 'bashrc' ~/.bash_profile || echo "$warn $(m profile_warn)"
elif [ ! -f ~/.bash_login ] && [ ! -f ~/.profile ]; then
    printf '%s\n' '[ -f ~/.bashrc ] && . ~/.bashrc' > ~/.bash_profile
    echo "$ok $(m profile_created)"
fi

projects=$(bash --norc -i -c '. ~/.bashrc.local; printf "%s " "${!PROJ_DIR[@]}"' </dev/null 2>/dev/null || true)
echo "${dim}$(m projects): ${projects:-$(m none)} · $(m relogin)${r}"
# end
