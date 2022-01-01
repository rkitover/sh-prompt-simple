#!/bin/sh

_sps_hostname=$(hostname | sed 's/\..*//')
_e=$(printf "\033")
_esc= _end=
[ -n "$BASH_VERSION" ]  && _esc=$(printf '\001') _end=$(printf '\002')

_SPS_cmd_status() {
    if [ "$?" -eq 0 ]; then
        printf "${_esc}${_e}[0;32m${_end}%s" 'v'
    else
        printf "${_esc}${_e}[0;31m${_end}%s" 'x'
    fi
}

_SPS_in_msys2() {
    if [ -n "$MSYSTEM" ] && [ -z "$_SPS_IN_MSYS2" ]; then
        if [ "$(uname -o)" = Msys ]; then
            _SPS_IN_MSYS2=1
        fi
    fi

    if [ -n "$_SPS_IN_MSYS2" ]; then
        return 0
    fi

    return 1
}

_SPS_msystem() {
    if [ -n "$MSYSTEM" ] && _SPS_in_msys2; then
        # Need trailing space in case it's empty.
        printf "${_esc}${_e}[0;95m${_end}%s " "$MSYSTEM"
    fi
}

_SPS_in_git_tree() {
    (
        while [ "$PWD" != / ]; do
            [ -d .git ] && exit 0
            cd ..
        done
        exit 1
    )
    return $?
}

_SPS_git_branch() {
    ! _SPS_in_git_tree && return 0

    _br=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [ -n "$_br" ]; then
        printf "${_esc}${_e}[0;36m${_end}[${_esc}${_e}[35m${_end}%s${_esc}${_e}[36m${_end}]${_esc}${_e}[0m${_end}" "${_br}"
    fi
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

: ${USER:=$(whoami)}

if [ -z "$ZSH_VERSION" ]; then

    PS1='`_SPS_cmd_status` `_SPS_msystem``_SPS_cwd` `_SPS_git_branch`
'"${_esc}${_e}[38;2;140;206;250m${_end}${USER}${_esc}${_e}[1;97m${_end}@${_esc}${_e}[0m${_e}[38;2;140;206;250m${_end}${_sps_hostname} ${_esc}${_e}[38;2;220;20;60m${_end}>${_esc}${_e}[0m${_end} "

else # zsh

    setopt PROMPT_SUBST

    precmd() {
        echo "$(_SPS_cmd_status) $(_SPS_msystem)$(_SPS_cwd) $(_SPS_git_branch)"
    }

    PS1="%{${_e}[38;2;140;206;250m%}${USER}%{${_e}[1;97m%}@%{${_e}[0m${_e}[38;2;140;206;250m%}${_sps_hostname} %{${_e}[38;2;220;20;60m%}>%{${_e}[0m%} "
fi
