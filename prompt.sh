#!/bin/sh

_sps_hostname=$(hostname | sed 's/\..*//')

if [ -f /proc/$$/exe ] && ls -l /proc/$$/exe 2>/dev/null | sed 's/.*-> //' | grep -Eq '(^|/)(busybox|bb|ginit|.?ash|ksh.*)$'; then
    _is_ash_or_ksh=1
fi

if [ -z "$SPS_ESCAPE" ] && [ -n "${BASH_VERSION}${_is_ash_or_ksh}" ]; then
    SPS_ESCAPE=1
fi

unset _is_ash_or_ksh

_sps_tmp="${TMP:-${TEMP:-/tmp}}/sh-prompt-simple/$$"

mkdir -p "$_sps_tmp"

_SPS_quit() {
    rm -rf "$_sps_tmp"

    tmp_root=${_sps_tmp%/*}

    if [ -z "$(find "$tmp_root" -mindepth 1 -type d)" ]; then
        rm -rf "$tmp_root"
    fi

    return 0
}

trap "_SPS_quit" EXIT

_SPS_detect_non_linux_env() {
    if [ -n "$TERMUX_VERSION" ]; then
        echo TERMUX
        return
    elif [ "$(uname -o)" = Msys ] && [ -n "$MSYSTEM" ]; then
        echo "$MSYSTEM"
        return
    fi

    uname -o | sed -E 's/[[:space:][:punct:]]+/_/g' | \
        tr '[:lower:]' '[:upper:]'
}

_SPS_detect_distro() {
    [ -f /etc/os-release ] || return

    distro=$(sed -nE '/^ID="/s/^ID="([^"]+)".*/\1/p; s/^ID=([^[:space:]]+)/\1/p; t match; d; :match; q' /etc/os-release)

    normalized=$(echo "$distro" | sed -E '
        # Remove all buzzwords and extraneous words.

        s/(GNU|Secure|open)//ig

        :buzzwords
        s/(^|[[:space:][:punct:]]+)(LTS|toolkit|operating|solutions|Security|Firewall|Cluster|Distribution|system|project|interim|enterprise|corporate|server|desktop|studio|edition|live|libre|industrial|incognito|remix|and|on|a|for|the|[0-9]+)($|[[:space:][:punct:]]+)/\1\3/i
        t buzzwords

        # Remove GNU or Linux not at the beginning of phrase, or X
        # as a word by itself not at the beginning of phrase.

        :gnulinux
        s,([[:space:][:punct:]]+)(GNU|Linux|X([[:space:][:punct:]]|$)),\1,i
        t gnulinux

        # Trim space/punctuation from start/end.

        s/[[:space:][:punct:]]+$//
        s/^[[:space:][:punct:]]+//

        # Normalize all SUSE products to SUSE.

        s/.*(^|[[:space:][:punct:]])[Ss]USE($|[[:space:][:punct:]]).*/SUSE/i
        t

        # Remove everyting before the first /, if what is after is
        # longer than 3 characters.

        s;.+/(.{3,});\1;

        # Replace all space sequences with underscore.

        s/[[:space:]]+/_/g

        # Keep names with one hyphen, replace all other punctuation
        # sequnces with underscore.

        /^[^-]+-[^-]+$/!{
            s/[[:punct:]]+/_/g
        }
    ' | tr '[:lower:]' '[:upper:]');

    # If normalized name is longer than 15 characters, abbreviate
    # instead.
    if [ "$(printf %s "$normalized" | wc -c)" -gt 15 ]; then
        normalized=$(echo "$distro" | sed -E '
            :abbrev
            s/(^|[[:space:][:punct:]]+)([[:alpha:]])[[:alpha:]]+/\1\2/
            t abbrev
            s/[[:space:][:punct:]]+//g
        ' | tr '[:lower:]' '[:upper:]')
    fi

    echo "$normalized"

    unset distro normalized
}

_SPS_detect_env() {
    case "$(uname -o)" in
        *Linux)
            _sps_env=$(_SPS_detect_distro)
            : ${_sps_env:=LINUX}
            ;;
        *)
            _sps_env=$(_SPS_detect_non_linux_env)
            ;;
    esac
}

_SPS_status_color() {
    if [ "$?" -eq 0 ]; then
        echo 0 > "$_sps_tmp/cmd_status"
        printf "\033[0;32m"
    else
        echo 1 > "$_sps_tmp/cmd_status"
        printf "\033[0;31m"
    fi
}

_SPS_status() {
    if [ "$(cat "$_sps_tmp/cmd_status")" -eq 0 ]; then
        printf 'v'
    else
        printf 'x'
    fi
}

_SPS_in_git_tree() {
    if [ -f "$_sps_tmp/in_git_tree" ]; then
        return "$(cat "$_sps_tmp/in_git_tree")"
    fi

    OLDPWD=$PWD

    _matched=

    while [ "$PWD" != / ]; do
        if [ -d .git ]; then
            _matched=1
            break
        fi
        cd ..
    done

    cd "$OLDPWD"

    if [ -n "$_matched" ]; then
        unset OLDPWD _matched
        echo 0 > "$_sps_tmp/in_git_tree"
        return 0
    fi

    unset OLDPWD _matched
    echo 1 > "$_sps_tmp/in_git_tree"
    return 1
}

_SPS_git_status_color() {
    if [ -z "$SPS_STATUS" ] || ! _SPS_in_git_tree; then
        return
    fi

    _status=$(LANG=C git status 2>/dev/null)
    _clean=

    if echo "$_status" | grep -Eq 'working tree clean'; then
        # For remote tracking branches, check that the branch is up-to-date with the remote branch.
        if [ "$(echo "$_status" | wc -l)" -le 2 ] || echo "$_status" | grep -Eq '^Your branch is up to date with'; then
            _clean=1
        fi
    fi

    if [ -n "$_clean" ]; then
        echo 0 > "$_sps_tmp/git_status"
        printf "\033[0;32m"
    else
        echo 1 > "$_sps_tmp/git_status"
        printf "\033[0;31m"
    fi

    unset _status _clean
}

_SPS_git_status() {
    if [ -z "$SPS_STATUS" ] || ! _SPS_in_git_tree; then
        return
    fi

    if [ "$(cat "$_sps_tmp/git_status")" = 0 ]; then
        printf 'v'
    else
        printf '~~~'
    fi
}

_SPS_git_sep() {
    if [ -z "$SPS_STATUS" ] || ! _SPS_in_git_tree; then
        return
    fi

    printf '|'
}

_SPS_git_open_bracket() {
    _SPS_in_git_tree && printf '['
}

_SPS_git_close_bracket() {
    _SPS_in_git_tree && printf ']'

    rm "$_sps_tmp/"*git* 2>/dev/null
}

_SPS_git_branch() {
    ! _SPS_in_git_tree && return

    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

_SPS_cwd() {
    case "$PWD" in
        "$HOME")
            printf '~'
            ;;
        "$HOME"/*)
            _pwd=${PWD#$HOME}

            while :; do
                case "$_pwd" in
                    /*)
                        _pwd=${_pwd#/}
                        ;;
                    *)
                        break
                        ;;
                esac
            done

            printf "~/${_pwd}"
            ;;
        *)
            printf "${PWD}"
            ;;
    esac
}

_SPS_detect_env

: ${USER:=$(whoami)}

_e=$(printf "\033")

if [ -z "$ZSH_VERSION" ]; then


    if [ "$SPS_ESCAPE" = 1 ]; then
        PS1="\
\["'`_SPS_status_color`'"\]"'`_SPS_status`'" \
\[${_e}[0;95m\]${_sps_env} \
\[${_e}[33m\]"'`_SPS_cwd`'" \
\[${_e}[0;36m\]"'`_SPS_git_open_bracket`'"\
\[${_e}[35m\]"'`_SPS_git_branch`'"\
\[${_e}[0;97m\]"'`_SPS_git_sep`'"\
\["'`_SPS_git_status_color`'"\]"'`_SPS_git_status`'"\
\[${_e}[0;36m\]"'`_SPS_git_close_bracket`'"
\[${_e}[38;2;140;206;250m\]${USER}\
\[${_e}[1;97m\]@\
\[${_e}[0;38;2;140;206;250m\]${_sps_hostname} \
\[${_e}[38;2;220;20;60m\]>\
\[${_e}[0m\] "
    else
        PS1="\
"'`_SPS_status_color``_SPS_status`'" \
${_e}[0;95m${_sps_env} \
${_e}[33m"'`_SPS_cwd`'" \
${_e}[0;36m"'`_SPS_git_open_bracket`'"\
${_e}[35m"'`_SPS_git_branch`'"\
${_e}[0;97m"'`_SPS_git_sep`'"\
"'`_SPS_git_status_color``_SPS_git_status`'"\
${_e}[0;36m"'`_SPS_git_close_bracket`'"
${_e}[38;2;140;206;250m${USER}\
${_e}[1;97m@\
${_e}[0;38;2;140;206;250m${_sps_hostname} \
${_e}[38;2;220;20;60m>\
${_e}[0m "
    fi

else # zsh

    setopt PROMPT_SUBST

    precmd() {
        printf "\
$(_SPS_status_color)$(_SPS_status) \
\033[0;95m${_sps_env} \
\033[33m$(_SPS_cwd) \
\033[0;36m$(_SPS_git_open_bracket)\
\033[35m$(_SPS_git_branch)\
\033[0;97m$(_SPS_git_sep)\
$(_SPS_git_status_color)$(_SPS_git_status)\
\033[0;36m$(_SPS_git_close_bracket)
"
    }

    PS1="%{${_e}[38;2;140;206;250m%}${USER}%{${_e}[1;97m%}@%{${_e}[0m${_e}[38;2;140;206;250m%}${_sps_hostname} %{${_e}[38;2;220;20;60m%}>%{${_e}[0m%} "
fi

unset _e _sps_hostname
