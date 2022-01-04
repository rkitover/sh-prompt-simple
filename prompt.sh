#!/bin/sh

_sps_hostname=$(hostname | sed 's/\..*//')
_e=$(printf "\033")
_esc= _end=
[ -n "$BASH_VERSION" ]  && _esc=$(printf '\001') _end=$(printf '\002')

_SPS_detect_distro() {
    [ -f /etc/os-release ] || return

    distro=$(sed -nE 's/^ID="([^"]+)".*/\1/p' /etc/os-release)

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
    ' | tr 'a-z' 'A-Z');

    # If normalized name is longer than 15 characters, abbreviate
    # instead.
    if [ "$(printf %s "$normalized" | wc -c)" -gt 15 ]; then
        normalized=$(echo "$distro" | sed -E '
            :abbrev
            s/(^|[[:space:][:punct:]]+)([[:alpha:]])[[:alpha:]]+/\1\2/
            t abbrev
            s/[[:space:][:punct:]]+//g
        ' | tr 'a-z' 'A-Z')
    fi

    echo "$normalized"

    unset distro normalized
}

_SPS_detect_env() {
    case "$(uname -o)" in
        Msys)
            _sps_env='$MSYSTEM'
            ;;
        *Linux)
            _sps_env=$(_SPS_detect_distro)

            if [ -z "$_sps_env" ]; then
                _sps_env=LINUX
            fi
            ;;
        *)
            _sps_env=$(uname -o | \
                sed -E 's/[[:space:][:punct:]]+/_/g' | \
                tr 'a-z' 'A-Z' \
            )
            ;;
    esac
}

_SPS_env() {
    eval printf "\"${_esc}${_e}\""\''[0;95m'\'"\"${_end}%s\"" "\"$_sps_env\""
}

_SPS_cmd_status() {
    if [ "$?" -eq 0 ]; then
        printf "${_esc}${_e}[0;32m${_end}%s" 'v'
    else
        printf "${_esc}${_e}[0;31m${_end}%s" 'x'
    fi
}

_SPS_in_git_tree() {
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
        return 0
    fi

    unset OLDPWD _matched
    return 1
}

_SPS_git_status() {
    _status=$(LANG=C git status 2>/dev/null)
    _clean=

    if echo "$_status" | grep -Eq 'working tree clean'; then
        if echo "$_status" | grep -Eq '^Your branch is up to date with'; then
            _clean=1
        fi
    fi

    if [ -n "$_clean" ]; then
        printf "${_esc}${_e}[0;32m${_end}%s" 'v'
    else
        printf "${_esc}${_e}[0;31m${_end}%s" '~~~'
    fi

    unset _status _clean
}

_SPS_git_bar() {
    ! _SPS_in_git_tree && return 0

    _br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    _status=
    if [ -n "$SPS_STATUS" ]; then
        _status="${_esc}${_e}[0;97m${_end}|${_esc}${_e}[0m${_end}$(_SPS_git_status)"
    fi

    if [ -n "$_br" ]; then
        printf "${_esc}${_e}[0;36m${_end}[${_esc}${_e}[35m${_end}%s%s${_esc}${_e}[36m${_end}]${_esc}${_e}[0m${_end}" "$_br" "$_status"
    fi

    unset _br _status
}

_SPS_cwd() {
    case "$PWD" in
        "$HOME")
            printf "${_esc}${_e}[33m${_end}%s" '~'
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

            printf "${_esc}${_e}[33m${_end}~/%s" "${_pwd}"
            ;;
        *)
            printf "${_esc}${_e}[33m${_end}%s" "${PWD}"
            ;;
    esac
}

_SPS_detect_env

: ${USER:=$(whoami)}

if [ -z "$ZSH_VERSION" ]; then

    PS1='`_SPS_cmd_status` `_SPS_env` `_SPS_cwd` `_SPS_git_bar`
'"${_esc}${_e}[38;2;140;206;250m${_end}${USER}${_esc}${_e}[1;97m${_end}@${_esc}${_e}[0m${_e}[38;2;140;206;250m${_end}${_sps_hostname} ${_esc}${_e}[38;2;220;20;60m${_end}>${_esc}${_e}[0m${_end} "

else # zsh

    setopt PROMPT_SUBST

    precmd() {
        echo "$(_SPS_cmd_status) $(_SPS_env) $(_SPS_cwd) $(_SPS_git_bar)"
    }

    PS1="%{${_e}[38;2;140;206;250m%}${USER}%{${_e}[1;97m%}@%{${_e}[0m${_e}[38;2;140;206;250m%}${_sps_hostname} %{${_e}[38;2;220;20;60m%}>%{${_e}[0m%} "
fi

unset _sps_hostname
