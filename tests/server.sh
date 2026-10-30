#!/usr/bin/env bash
# Exercises install.sh and bashrc.local the way `srv install` does, in a throwaway HOME with a fake docker.
#   bash tests/server.sh src/server        (tests/run.ps1 runs it through WSL)
set -u
shopt -u patsub_replacement 2>/dev/null
src=$(cd "$1" && pwd)
pass=0 fail=0
ok=$'\e[32m✓\e[0m' bad=$'\e[31m✗' dim=$'\e[90m' r=$'\e[0m'

t() {   # t "name" function: whatever the function prints is shown when it fails
    local name=$1; shift
    local out
    if out=$("$@" 2>&1); then pass=$((pass+1)); printf '  %s %s\n' "$ok" "$name"
    else fail=$((fail+1)); printf '  %s %s%s  %s%s%s\n' "$bad" "$name" "$r" "$dim" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" "$r"; fi
}
has() { [[ $1 == *"$2"* ]] || { printf 'missing "%s" in: %s\n' "$2" "$1"; return 1; }; }
lacks() { [[ $1 != *"$2"* ]] || { printf 'unexpected "%s" in: %s\n' "$2" "$1"; return 1; }; }
file() { [[ -f $1 ]] || { echo "no file $1"; return 1; }; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME=$T/home
mkdir -p "$HOME/apps/shop" "$HOME/apps/api" "$HOME/apps/extra" "$HOME/bin" "$T/bin"
cp /etc/skel/.bashrc "$HOME/.bashrc" 2>/dev/null || : > "$HOME/.bashrc"
export MARK=$T/destructive-call
cat > "$T/bin/docker" <<'EOF'
#!/bin/bash
# fake docker: answers the queries bashrc.local makes and records destructive calls
case "$*" in
    "compose ls -a --format json") printf '[{"Name":"shop","Status":"running(4)","ConfigFiles":"%s/apps/shop/docker-compose.yml"},{"Name":"api","Status":"exited(1), running(2)","ConfigFiles":"%s/apps/api/docker-compose.yml"}]\n' "$HOME" "$HOME" ;;
    "compose ps -a --format "*) printf 'web\tUp 2 hours (healthy)\ndb\tUp 2 hours\n' ;;
    "compose config --services") printf 'web\ndb\n' ;;
    "ps -a --format "*) printf 'shop-web-1\tUp 2 hours (healthy)\napi-worker-1\tExited (1) 3 hours ago\n' ;;
    "compose down -v"*|"volume rm"*|"system prune"*) touch "$MARK"; echo "destructive: $*" ;;
    *) echo "docker $*" ;;
esac
EOF
chmod +x "$T/bin/docker"
export PATH="$T/bin:$PATH"
printf '#!/bin/bash\n# help: backup the database to S3\n' > "$HOME/bin/backup-db"; chmod +x "$HOME/bin/backup-db"

# The script srv pipes into `ssh host bash -s`: install.sh with the placeholders filled in
installer() {   # action env lang
    local custom; custom=$(printf '# help: hello - says hello\nhello() { echo hi; }\n' | base64 -w0)
    local s; s=$(<"$src/install.sh")
    s=${s//__ACTION__/$1}; s=${s//__ENV__/$2}; s=${s//__LANG__/$3}
    s=${s//__BASHRC_B64__/$(base64 -w0 "$src/bashrc.local")}
    s=${s//__INPUTRC_B64__/$(base64 -w0 "$src/inputrc")}
    local line="__put '.bashrc.d/mine.sh' '$custom'"
    s=${s//__CUSTOM_FILES__/$line}
    printf '%s' "$s" | bash -s
}
# An interactive bash with bashrc.local loaded, like a session on the server
run() { bash --norc -i -c ". ~/.bashrc.local; $1" </dev/null 2>&1 | grep -v -e 'job control' -e 'terminal process group' -e 'Inappropriate ioctl'; }

printf '\n  %s── static%s\n' "$dim" "$r"
t 'bashrc.local: bash -n'                 bash -n "$src/bashrc.local"
t 'install.sh: bash -n'                   bash -n "$src/install.sh"
t 'version header present'                grep -q '^# version: [0-9]' "$src/bashrc.local"
t 'inputrc carries the managed marker'    grep -q 'srv: managed' "$src/inputrc"
no_background() { ! grep -nE '(^|[^&])&[[:space:]]*$' "$src/bashrc.local"; }
t 'nothing is started in the background'  no_background

printf '\n  %s── install.sh%s\n' "$dim" "$r"
test_install() {
    local out; out=$(installer install prod ru)
    has "$out" '~/.bashrc.local' && has "$out" 'метка: prod' && has "$out" 'язык: ru' &&
    file "$HOME/.bashrc.local" && file "$HOME/.inputrc" && file "$HOME/.bashrc.d/mine.sh" &&
    grep -q 'bashrc.local' "$HOME/.bashrc" && grep -q '^PROMPT_ENV=prod$' "$HOME/.config/bashrc-local.conf" && grep -q '^LANG_UI=ru$' "$HOME/.config/bashrc-local.conf"
}
test_reinstall() {
    local out; out=$(installer install '' ru)
    has "$out" 'актуален' && has "$out" 'метка: prod' || return 1
    local n; n=$(ls "$HOME"/.bashrc.local.bak-* 2>/dev/null | wc -l)
    (( n == 0 )) || { echo "backups made: $n"; return 1; }
}
test_relabel() {
    local out; out=$(installer install staging en)
    has "$out" 'label: staging' && grep -q '^PROMPT_ENV=staging$' "$HOME/.config/bashrc-local.conf" && grep -q '^LANG_UI=en$' "$HOME/.config/bashrc-local.conf"
}
test_nolabel() {
    local out; out=$(installer install none ru)
    has "$out" 'метка: нет' && grep -q '^PROMPT_ENV=$' "$HOME/.config/bashrc-local.conf"
}
test_remove() {
    local out; out=$(installer remove '' ru)
    has "$out" 'убрана' && ! grep -q 'bashrc.local' "$HOME/.bashrc" && ls "$HOME"/.bashrc.local.off-* >/dev/null 2>&1 && file "$HOME/.config/bashrc-local.conf"
}
t 'install: files, hook, label, language'  test_install
t 'reinstall: up to date, no backup'       test_reinstall
t 'relabel and switch language'            test_relabel
t 'label none clears it'                   test_nolabel
t 'remove: hook gone, files set aside'     test_remove
installer install prod ru >/dev/null

printf '\n  %s── bashrc.local%s\n' "$dim" "$r"
test_load_clean() { local out; out=$(run 'echo LOADED'); [[ $out == LOADED ]] || { echo "$out"; return 1; }; }
test_no_jobs() { local out; out=$(run 'jobs'); [[ -z $out ]] || { echo "$out"; return 1; }; }
test_help_ru() {
    local out; out=$(run help)
    has "$out" 'Проекты' && has "$out" 'Подстраховка' && has "$out" 'shop' && has "$out" 'hello' && has "$out" 'says hello' && has "$out" 'backup-db' && has "$out" 'backup the database'
}
test_help_search() { local out; out=$(run 'help bak'); has "$out" 'bak <файл>' && lacks "$out" 'dps'; }
test_help_en() {
    sed -i 's/^LANG_UI=.*/LANG_UI=en/' "$HOME/.config/bashrc-local.conf"
    local out; out=$(run help)
    sed -i 's/^LANG_UI=.*/LANG_UI=ru/' "$HOME/.config/bashrc-local.conf"
    has "$out" 'Projects' && has "$out" 'Guards' && lacks "$out" 'Проекты'
}
test_t() { local out; out=$(run 'LANG_UI=en __t s_guard; echo; LANG_UI=ru __t s_guard'); has "$out" 'Guards' && has "$out" 'Подстраховка'; }
test_duration() {
    local out; out=$(run '__fmt_duration 3700; echo; __fmt_duration 65; echo; __fmt_duration 5')
    [[ $out == $'1h 1m\n1m 5s\n5s' ]] || { echo "$out"; return 1; }
}
test_prompt() {
    local out; out=$(run '(exit 3); __prompt; printf "%s" "$PS1"')
    has "$out" '● prod' && has "$out" '✘ 3' && has "$out" '└─' && has "$out" '\[\e[31m\]❯' || return 1
    out=$(run 'true; __prompt; printf "%s" "$PS1"')
    lacks "$out" '✘' && has "$out" '\[\e[32m\]❯'
}
test_git_branch() {
    local repo=$T/repo; mkdir -p "$repo"
    git -C "$repo" init -q -b main 2>/dev/null || git -C "$repo" init -q
    git -C "$repo" -c user.email= -c user.name=t commit -q --allow-empty -m init
    local out; out=$(run "cd '$repo'; __git_branch")
    [[ $out == *'⎇ ma'* && $out != *'*'* ]] || { echo "clean: $out"; return 1; }
    echo x > "$repo/f"; git -C "$repo" add f
    out=$(run "cd '$repo'; __git_branch")
    [[ $out == *'⎇ ma'*'*' ]] || { echo "dirty: $out"; return 1; }
}
test_proj_list() { local out; out=$(run proj); has "$out" 'shop' && has "$out" 'api' && has "$out" 'running' && grep -q $'^shop\t' "$HOME/.config/projects"; }
test_proj_function() { local out; out=$(run 'type -t shop; shop'); has "$out" 'function' && has "$out" 'web' && has "$out" 'healthy'; }
test_app_cd() { local out; out=$(run 'app shop; pwd'); [[ $out == "$HOME/apps/shop" ]] || { echo "$out"; return 1; }; }
test_proj_add_rm() {
    local out; out=$(run "proj add extra '$HOME/apps/extra'; proj")
    has "$out" 'добавлен' && has "$out" 'extra' || return 1
    out=$(run 'proj rm extra >/dev/null; proj'); lacks "$out" 'extra' || return 1
    out=$(run 'proj add "bad name"'); has "$out" 'плохое имя' || return 1
    out=$(run 'proj nope'); has "$out" 'нет проекта'
}
test_guard_cancel() {
    rm -f "$MARK"
    local out; out=$(run 'docker compose down -v; docker volume rm x; docker system prune')
    has "$out" 'Отменено' && [[ ! -f $MARK ]] || { echo "marker: $(ls "$MARK" 2>&1)"; return 1; }
}
test_guard_yes() {
    rm -f "$MARK"
    local out; out=$(bash --norc -i -c '. ~/.bashrc.local; docker compose down -v' <<< 'yes' 2>&1)
    [[ -f $MARK ]] || { echo "$out"; return 1; }
}
test_guard_passthrough() { rm -f "$MARK"; local out; out=$(run 'docker ps'); has "$out" 'docker ps' && [[ ! -f $MARK ]]; }
test_ex() {
    local d=$T/ex; mkdir -p "$d/src"; echo hi > "$d/src/a.txt"; tar -czf "$d/p.tgz" -C "$d/src" a.txt
    local out; out=$(run "cd '$d'; ex p.tgz; cat a.txt; ex nope.zip; ex src/a.txt")
    has "$out" 'hi' && has "$out" 'нет файла: nope.zip' && has "$out" 'не знаю, чем распаковать'
}
test_bak() { echo x > "$T/b.txt"; local out; out=$(run "cd '$T'; bak b.txt"); has "$out" '→ b.txt.bak-' && ls "$T"/b.txt.bak-* >/dev/null; }
test_psg() { local out; out=$(run 'psg bash'); has "$out" 'bash'; }
test_mkcd() { local out; out=$(run "cd '$T'; mkcd deep/er; pwd"); [[ $out == "$T/deep/er" ]] || { echo "$out"; return 1; }; }
test_h() { local out; out=$(run 'history -c; history -s "docker ps"; history -s "ls -la"; h docker'); has "$out" 'docker ps' && lacks "$out" 'ls -la'; }
test_sys() {
    local out; out=$(run sys)
    has "$out" 'нагрузка' && has "$out" 'контейнеры' && has "$out" 'shop-web-1' || return 1
    [[ $out == *'█'* || $out == *'░'* ]] || { echo "no bars: $out"; return 1; }
}
test_aliases() { local out; out=$(run 'alias rm; alias ll; type -t dc'); has "$out" 'rm -I' && has "$out" 'ls -lah' && has "$out" 'alias'; }
t 'loads clean in an interactive shell'    test_load_clean
t 'no background jobs after loading'       test_no_jobs
t 'help: sections, projects, own scripts'  test_help_ru
t 'help <word> filters rows'               test_help_search
t 'help in english via LANG_UI'            test_help_en
t '__t picks the language'                 test_t
t '__fmt_duration'                         test_duration
t 'prompt: label, exit code, arrow color'  test_prompt
t 'git branch and dirty mark'              test_git_branch
t 'proj discovers compose projects'        test_proj_list
t '<project> is a function with status'    test_proj_function
t 'app <project> changes folder'           test_app_cd
t 'proj add / rm / errors'                 test_proj_add_rm
t 'docker guard cancels without yes'       test_guard_cancel
t 'docker guard passes with yes'           test_guard_yes
t 'docker guard leaves other commands'     test_guard_passthrough
t 'ex extracts and complains'              test_ex
t 'bak makes a dated copy'                 test_bak
t 'psg'                                    test_psg
t 'mkcd'                                   test_mkcd
t 'h filters history'                      test_h
t 'sys draws load, memory, containers'     test_sys
t 'aliases and guards are in place'        test_aliases

color=$'\e[32m'; (( fail )) && color=$'\e[31m'
printf '\n  %s%d passed, %d failed%s\n' "$color" "$pass" "$fail" "$r"
printf '##result passed=%d failed=%d\n' "$pass" "$fail"
exit "$fail"
