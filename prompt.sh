#!/bin/sh

_SPS_main() {
    local hostname=$(hostname | sed -E 's/\..*//')

	  _SPS_set_window_title

    if [ -z "$SPS_ESCAPE" ] && _SPS_is_bash_or_ash_or_ksh; then
        SPS_ESCAPE=1
    fi

    _SPS_detect_env

    _sps_tmp="${TMP:-${TEMP:-${TMPDIR:-/tmp}}}/sh-prompt-simple/$$"

    if [ "$_sps_env" = windows ] && [ -z "$_sps_tmp" ]; then
        _sps_tmp=$(echo "$USERPROFILE/AppData/Local/Temp/sh-prompt-simple/$$" | tr '\\' '/')
    fi

    mkdir -p "$_sps_tmp"

    : ${USER:=$(whoami)}

    prompt_char='>'

    [ "$(id -u)" = 0 ] && prompt_char='#'

    _e=$(printf "\033")

    if [ -z "$ZSH_VERSION" ]; then
        if [ "$SPS_ESCAPE" = 1 ]; then
            PS1="\
"'`_SPS_get_status`'"\
\["'`_SPS_window_title`'"\]\
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
\[${_e}[0;38;2;140;206;250m\]${hostname} \
\[${_e}[38;2;220;20;60m\]${prompt_char}\
\[${_e}[0m\] "
        else
            PS1="\
"'`_SPS_get_status`'"\
"'`_SPS_window_title`'"\
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
${_e}[0;38;2;140;206;250m${hostname} \
${_e}[38;2;220;20;60m${prompt_char}\
${_e}[0m "
        fi

    else # zsh

        setopt PROMPT_SUBST

        precmd() {
            printf "\
$(_SPS_get_status)\
$(_SPS_window_title)\
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

        PS1="%{${_e}[38;2;140;206;250m%}${USER}%{${_e}[1;97m%}@%{${_e}[0m${_e}[38;2;140;206;250m%}${hostname} %{${_e}[38;2;220;20;60m%}${prompt_char}%{${_e}[0m%} "
    fi
}

# SPS_WINDOW_TITLE

_SPS_set_window_title() {
	_SPS_WINDOW_TITLE="$(_SPS_domain_or_localnet_host)"
}

_SPS_domain_or_localnet_host() {
  	hostname | sed -E '
        /\..*\./{
            s/[^.]+\.//
            b
        }
        s/\..*//
    '
}

_SPS_window_title() {
    [ "$SPS_WINDOW_TITLE" = 0 ] && return

    printf '\033]0;%s\007' "$_SPS_WINDOW_TITLE"
}

_SPS_is_bash_or_ash_or_ksh() {
	[ "$BASH_VERSION" ] && return 0
	_SPS_is_ash_or_ksh
}

_SPS_is_ash_or_ksh() {
	[ -f /proc/$$/exe ] || return 1

	readlink /proc/$$/exe 2>/dev/null \
		| grep -Eq '(^|/)(busybox|bb|ginit|.?ash|ksh.*)$'
}

_SPS_quit() {
    rm -rf "$_sps_tmp"

    local tmp_root=${_sps_tmp%/*}

    if [ -z "$(find "$tmp_root" -mindepth 1 -type d)" ]; then
        rm -rf "$tmp_root"
    fi

    return 0
}

trap "_SPS_quit" EXIT

_SPS_uname_o() {
    # macOS does not have `uname -o`.
    uname -o 2>/dev/null || uname
}

_SPS_detect_non_linux_env() {
    if [ -n "$TERMUX_VERSION" ]; then
        echo termux
        return
    elif [ "$(_SPS_uname_o)" = Darwin ]; then
        echo macOS
        return
    elif [ "$(_SPS_uname_o)" = Msys ] && [ -n "$MSYSTEM" ]; then
        echo "$MSYSTEM" | tr '[:upper:]' '[:lower:]'
        return
    elif [ "$(_SPS_uname_o)" = Cygwin ]; then
        echo cygwin
        return
    elif echo "$(_SPS_uname_o)$(uname 2>/dev/null)" | grep -qi windows || \
         [ -d /Windows/System32 ]; then
        SPS_ESCAPE=1 # Possibly a busybox for Windows build.
        echo windows
        return
    fi

    uname | sed -E 's/[[:space:][:punct:]]+/_/g'
}

_SPS_detect_distro() {
    [ -f /etc/os-release ] || return

    local distro=$(sed -nE '/^ID="/s/^ID="([^"]+)".*/\1/p; s/^ID=([^[:space:]]+)/\1/p; t match; d; :match; q' /etc/os-release)

    local normalized=$(echo "$distro" | sed -E '
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

        # Normalize all suse products to suse.

        s/.*(^|[[:space:][:punct:]])SUSE($|[[:space:][:punct:]]).*/suse/i
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
    ');

    # If normalized name is longer than 15 characters, abbreviate
    # instead.
    if [ "$(printf %s "$normalized" | wc -c)" -gt 15 ]; then
        normalized=$(echo "$distro" | sed -E '
            :abbrev
            s/(^|[[:space:][:punct:]]+)([[:alpha:]])[[:alpha:]]+/\1\2/
            t abbrev
            s/[[:space:][:punct:]]+//g
        ')
    fi

    echo "$normalized"
}

_SPS_detect_env() {
    case "$(_SPS_uname_o)" in
        *Linux)
            _sps_env=$(_SPS_detect_distro)
            : ${_sps_env:=linux}
            ;;
        *)
            _sps_env=$(_SPS_detect_non_linux_env)
            ;;
    esac
}

_SPS_get_status() {
    if [ "$?" -eq 0 ]; then
        echo 0 > "$_sps_tmp/cmd_status"
    else
        echo 1 > "$_sps_tmp/cmd_status"
    fi
}

_SPS_status_color() {
    if [ "$(cat "$_sps_tmp/cmd_status")" -eq 0 ]; then
        printf "\033[0;32m"
    else
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
    ! command -v git >/dev/null && return 1

    if [ -f "$_sps_tmp/in_git_tree" ]; then
        return "$(cat "$_sps_tmp/in_git_tree")"
    fi

    local OLDPWD=$PWD

    local matched=

    while ! (printf "$PWD" | grep -Eqi '^([[:alnum:]]+:)?[\/]$'); do
        if [ -d .git ]; then
            matched=1
            break
        fi
        cd ..
    done

    cd "$OLDPWD"

    if [ -n "$matched" ]; then
        echo 0 > "$_sps_tmp/in_git_tree"

        return 0
    fi

    echo 1 > "$_sps_tmp/in_git_tree"

    return 1
}

_SPS_git_status_color() {
    if [ -z "$SPS_STATUS" ] || ! _SPS_in_git_tree; then
        return
    fi

    status=$(LANG=C LC_ALL=C git status 2>/dev/null)
    clean=

    if echo "$status" | grep -Eq 'working tree clean'; then
        # For remote tracking branches, check that the branch is up-to-date with the remote branch.
        if [ "$(echo "$status" | wc -l)" -le 2 ] || echo "$status" | grep -Eq '^Your branch is up to date with'; then
            clean=1
        fi
    fi

    if [ -n "$clean" ]; then
        echo 0 > "$_sps_tmp/git_status"
        printf "\033[0;32m"
    else
        echo 1 > "$_sps_tmp/git_status"
        printf "\033[0;31m"
    fi
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
            local pwd=${PWD#$HOME}

            while :; do
                case "$pwd" in
                    /*)
                        pwd=${pwd#/}
                        ;;
                    *)
                        break
                        ;;
                esac
            done

            printf "~/${pwd}"
            ;;
        *)
            printf "${PWD}"
            ;;
    esac
}

_SPS_main
