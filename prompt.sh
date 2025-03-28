#!/bin/sh
# shellcheck shell=sh

# STYLE GUIDE
# SPS_SCREAMING_SNAKE_CASE  - user config environment variables (constants)
# _SPS_SCREAMING_SNAKE_CASE - (global) constants - does not change in a session
# _sps_snake_case           - (global) variables - may change with each prompt
# _SPS_snake_case           - functions

_SPS_main() {
	# init user config constants
	_SPS_set_sps_escape

	# init system constants
	_SPS_set_user
	_SPS_set_sps_hostname
	_SPS_set_sps_platform
	_SPS_set_sps_tmp

	# init script constants
	_SPS_set_sps_csi
	_SPS_set_sps_prompt_char
	_SPS_set_sps_sgr_colors

	# do action
	_SPS_set_ps1
}

# init user config constants

## SPS_ESCAPE

_SPS_set_sps_escape() {
	[ -n "$SPS_ESCAPE" ] && return 0

	_SPS_is_bash_or_ash_or_ksh && SPS_ESCAPE=1
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

# init system constants

## USER

_SPS_set_user() {
	: "${USER:=$(whoami)}"
}

## _SPS_HOSTNAME

_SPS_set_sps_hostname() {
	_SPS_HOSTNAME=$(hostname | sed -E 's/\..*//')
}

## _SPS_PLATFORM

_SPS_set_sps_platform() {
	case "$(_SPS_uname_o)" in
		*Linux)
			_SPS_PLATFORM=$(_SPS_get_linux_platform)
			: "${_SPS_PLATFORM:=linux}"
			;;
		*)
			_SPS_PLATFORM=$(_SPS_get_non_linux_platform)
			;;
	esac
}

_SPS_uname_o() {
	# macOS does not have `uname -o`.
	uname -o 2>/dev/null || uname
}

_SPS_get_linux_platform() {
	[ -f '/etc/os-release' ] || return

	_sps_linux_release="$(sed -nE '/^ID="/s/^ID="([^"]+)".*/\1/p; s/^ID=([^[:space:]]+)/\1/p; t match; d; :match; q' '/etc/os-release')"

	_sps_linux_platform="$(printf '%s' "$_sps_linux_release" | sed -E '
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
	')";

	# If normalized name is longer than 15 characters, abbreviate instead.
	if [ "$(printf '%s' "$_sps_linux_platform" | wc -c)" -gt 15 ]; then
		_sps_linux_platform="$(printf '%s' "$_sps_linux_release" | sed -E '
			:abbrev
			s/(^|[[:space:][:punct:]]+)([[:alpha:]])[[:alpha:]]+/\1\2/
			t abbrev
			s/[[:space:][:punct:]]+//g
		')"
	fi

	printf '%s' "$_sps_linux_platform"
}

_SPS_get_non_linux_platform() {
	if [ -n "$TERMUX_VERSION" ]; then
		printf '%s' 'termux'
	elif [ "$(_SPS_uname_o)" = 'Darwin' ]; then
		printf '%s' 'macOS'
	elif [ "$(_SPS_uname_o)" = 'Msys' ] && [ -n "$MSYSTEM" ]; then
		printf '%s' "$MSYSTEM" | tr '[:upper:]' '[:lower:]'
	elif [ "$(_SPS_uname_o)" = Cygwin ]; then
		printf '%s' 'cygwin'
	elif _SPS_is_windows; then
		SPS_ESCAPE=1 # Possibly a busybox for Windows build.
		printf '%s' 'windows'
	else
		uname | sed -E 's/[[:space:][:punct:]]+/_/g'
	fi
}

_SPS_is_windows() {
	[ -d '/Windows/System32' ] && return 0

	printf '%s' "$(_SPS_uname_o)$(uname 2>/dev/null)" | grep -qi 'windows'
}

## _SPS_TMP

# create temp folder per shell session ($$)
#   to pass messagess between PS1 functions
#   as these functions are run in different subshells
_SPS_set_sps_tmp() {
	_SPS_TMP="${XDG_RUNTIME_DIR:-${TMP:-${TEMP:-${TMPDIR:-/tmp}}}}/sh-prompt-simple/$$"

	if [ "$_SPS_PLATFORM" = 'windows' ] && [ -z "$_SPS_TMP" ]; then
		_SPS_TMP="$(printf '%s' "$USERPROFILE/AppData/Local/Temp/sh-prompt-simple/$$" | tr '\\' '/')"
	fi

	mkdir -p "$_SPS_TMP"
}

# init script constants

## _SPS_CSI

_SPS_set_sps_csi() {
	_SPS_CSI="$(printf '\033')"
}

## _SPS_PROMPT_CHAR

_SPS_set_sps_prompt_char() {
	[ "$(id -u)" = 0 ] && _SPS_PROMPT_CHAR='#' || _SPS_PROMPT_CHAR='>'
}

## _SPS_SGR_*

# https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
# http://www.bashguru.com/2010/01/shell-colors-colorizing-shell-scripts.html
# http://www.pixelbeat.org/docs/terminal_colours/

_SPS_set_sps_sgr_colors() {
	# background-color
	_SPS_SGR_BG_BLACK='\033[40m'
	_SPS_SGR_BG_RED='\033[41m'
	_SPS_SGR_BG_GREEN='\033[42m'
	_SPS_SGR_BG_YELLOW='\033[43m'
	_SPS_SGR_BG_BLUE='\033[44m'
	_SPS_SGR_BG_MAGENTA='\033[45m'
	_SPS_SGR_BG_CYAN='\033[46m'
	_SPS_SGR_BG_WHITE='\033[47m'

	# (foreground) color
	_SPS_SGR_FG_BLACK='\033[0;30m'
	_SPS_SGR_FG_RED='\033[0;31m'
	_SPS_SGR_FG_GREEN='\033[0;32m'
	_SPS_SGR_FG_YELLOW='\033[0;33m'
	_SPS_SGR_FG_BLUE='\033[0;34m'
	_SPS_SGR_FG_MAGENTA='\033[0;35m'
	_SPS_SGR_FG_CYAN='\033[0;36m'
	_SPS_SGR_FG_GRAY='\033[0;37m'
	_SPS_SGR_FG_DARK_GRAY='\033[1;30m'
	_SPS_SGR_FG_BRIGHT_RED='\033[1;31m'
	_SPS_SGR_FG_BRIGHT_GREEN='\033[1;32m'
	_SPS_SGR_FG_BRIGHT_YELLOW='\033[1;33m'
	_SPS_SGR_FG_BRIGHT_BLUE='\033[1;34m'
	_SPS_SGR_FG_BRIGHT_MAGENTA='\033[1;35m'
	_SPS_SGR_FG_BRIGHT_CYAN='\033[1;36m'
	_SPS_SGR_FG_WHITE='\033[1;37m'

	# text-decoration
	_SPS_SGR_TD_NORMAL='\033[0m'
	_SPS_SGR_TD_BOLD='\033[1m'
	_SPS_SGR_TD_UNDERLINE='\033[4m'
	_SPS_SGR_TD_BLINK='\033[5m'
	_SPS_SGR_TD_REVERSE='\033[7m'
}

# do action

_SPS_set_ps1() {
	if [ "$ZSH_VERSION" ]; then
		_SPS_set_ps1_zsh
	else
		if [ "$SPS_ESCAPE" = 1 ]; then
			_SPS_set_ps1_not_zsh_with_escape
		else
			_SPS_set_ps1_not_zsh_without_escape
		fi
	fi
}

## ZSH

_SPS_set_ps1_zsh() {
	setopt PROMPT_SUBST

	precmd() {
		printf "\
$(_SPS_save_last_exit_status)\
$(_SPS_set_window_title)\
$(_SPS_last_exit_status_color)$(_SPS_last_exit_status_symbol) \
\033[0;95m${_SPS_PLATFORM} \
\033[33m$(_SPS_pwd)\
\033[0;36m$(_SPS_git_open_bracket)\
\033[35m$(_SPS_git_branch)\
\033[0;97m$(_SPS_git_sep)\
$(_SPS_git_status_color)$(_SPS_git_status_symbol)\
\033[0;36m$(_SPS_git_close_bracket)
"
	}

	PS1="%{${_SPS_CSI}[38;2;140;206;250m%}${USER}%{${_SPS_CSI}[1;97m%}@%{${_SPS_CSI}[0m${_SPS_CSI}[38;2;140;206;250m%}${_SPS_HOSTNAME} %{${_SPS_CSI}[38;2;220;20;60m%}${_SPS_PROMPT_CHAR}%{${_SPS_CSI}[0m%} "
}

## Shells that support esacpe

# TODO: Why are these using backticks '`...`' for command substitution?
# TODO:  Is it to support old shels that do not support '$(...)'?
_SPS_set_ps1_not_zsh_with_escape() {
	PS1="\
"'`_SPS_save_last_exit_status`'"\
\["'`_SPS_set_window_title`'"\]\
\["'`_SPS_last_exit_status_color`'"\]"'`_SPS_last_exit_status_symbol`'" \
\[${_SPS_CSI}[0;95m\]${_SPS_PLATFORM} \
\[${_SPS_CSI}[33m\]"'`_SPS_pwd`'"\
\[${_SPS_CSI}[0;36m\]"'`_SPS_git_open_bracket`'"\
\[${_SPS_CSI}[35m\]"'`_SPS_git_branch`'"\
\[${_SPS_CSI}[0;97m\]"'`_SPS_git_sep`'"\
\["'`_SPS_git_status_color`'"\]"'`_SPS_git_status_symbol`'"\
\[${_SPS_CSI}[0;36m\]"'`_SPS_git_close_bracket`'"
\[${_SPS_CSI}[38;2;140;206;250m\]${USER}\
\[${_SPS_CSI}[1;97m\]@\
\[${_SPS_CSI}[0;38;2;140;206;250m\]${_SPS_HOSTNAME} \
\[${_SPS_CSI}[38;2;220;20;60m\]${_SPS_PROMPT_CHAR}\
\[${_SPS_CSI}[0m\] "
}

## Shells that do not support esacpe

# TODO: Why are these using backticks '`...`' for command substitution?
# TODO:  Is it to support old shells that do not support '$(...)'?
_SPS_set_ps1_not_zsh_without_escape() {
	PS1="\
"'`_SPS_save_last_exit_status`'"\
"'`_SPS_set_window_title`'"\
"'`_SPS_last_exit_status_color``_SPS_last_exit_status_symbol`'" \
${_SPS_CSI}[0;95m${_SPS_PLATFORM} \
${_SPS_CSI}[33m"'`_SPS_pwd`'"\
${_SPS_CSI}[0;36m"'`_SPS_git_open_bracket`'"\
${_SPS_CSI}[35m"'`_SPS_git_branch`'"\
${_SPS_CSI}[0;97m"'`_SPS_git_sep`'"\
"'`_SPS_git_status_color``_SPS_git_status_symbol`'"\
${_SPS_CSI}[0;36m"'`_SPS_git_close_bracket`'"
${_SPS_CSI}[38;2;140;206;250m${USER}\
${_SPS_CSI}[1;97m@\
${_SPS_CSI}[0;38;2;140;206;250m${_SPS_HOSTNAME} \
${_SPS_CSI}[38;2;220;20;60m${_SPS_PROMPT_CHAR}\
${_SPS_CSI}[0m "
}

# Last Command Exit Status

# Save status to file as run in a subshell, so cannot pass to other functions
_SPS_save_last_exit_status() {
	if [ "$?" -eq 0 ]; then
		touch "$_SPS_TMP/last_exit_status_0"
	else
		rm -f "$_SPS_TMP/last_exit_status_0"
	fi
}

# TODO: why are color and symbol separate functions?
#   is it to support the shells not supporting zero-width escape sequences?
_SPS_last_exit_status_color() {
	if [ -f "$_SPS_TMP/last_exit_status_0" ]; then
		printf "$_SPS_SGR_FG_GREEN"
	else
		printf "$_SPS_SGR_FG_RED"
	fi
}

# TODO: why are color and symbol separate functions?
#   is it to support the shells not supporting zero-width escape sequences?
_SPS_last_exit_status_symbol() {
	if [ -f "$_SPS_TMP/last_exit_status_0" ]; then
		printf 'v'
	else
		printf 'x'
	fi
}

## SPS_WINDOW_TITLE

_SPS_set_window_title() {
	[ "$SPS_WINDOW_TITLE" = 0 ] && return

	printf '\033]0;%s\007' "$(_SPS_domain_or_localnet_host)"
}

_SPS_domain_or_localnet_host() {
	[ -z "$_SPS_DOMAIN_OR_LOCALNET_HOST" ] \
		&& _SPS_DOMAIN_OR_LOCALNET_HOST="$(_SPS_get_domain_or_localnet_host)"

	printf '%s' "$_SPS_DOMAIN_OR_LOCALNET_HOST"
}

_SPS_get_domain_or_localnet_host() {
	hostname | sed -E '
		/\..*\./{
			s/[^.]+\.//
			b
		}
		s/\..*//
	'
}

## Current Working Directory

_SPS_pwd() {
	case "$PWD" in
		"$HOME")
			printf '%s' '~'
			;;
		"$HOME"/*)
			local pwd=${PWD#$HOME}

			# TODO: this assumes that there are multiple leading '/',
			#   otherwise this 'while' block is redundant,
			#   as the final 'printf' adds back a single '/'.
			#   and this could be just "printf '~${PWD#$HOME}'".
			#   However, why would $PWD have multiple '/' after $HOME?
			# strip leading `/`
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

			printf '%s' "~/${pwd}"
			;;
		*)
			printf '%s' "${PWD}"
			;;
	esac
}

## Git

# only print if in git repo
_SPS_git_open_bracket() {
	_SPS_save_is_git_repo
	_SPS_is_git_repo && printf ' ['
}

# This function  and 'is_git_repo' assume that
#   'touch' and 'test -f' are faster than 'git'
#   otherwise they can be replaced by the `git rev-parse` call.
_SPS_save_is_git_repo() {
	git rev-parse --abbrev-ref HEAD >"$_SPS_TMP/git_branch" 2>/dev/null && return

	rm -f "$_SPS_TMP/git_branch"
}

_SPS_is_git_repo() {
	[ -f "$_SPS_TMP/git_branch" ] && return 0 || return 1
}

_SPS_git_branch() {
	_SPS_is_git_repo || return

	cat "$_SPS_TMP/git_branch"
}

_SPS_git_sep() {
	{ [ -n "$SPS_STATUS" ] && _SPS_is_git_repo; } || return

	printf '|'
}

# TODO: why are color and symbol separate functions?
#   is it to support the shells not supporting zero-width escape sequences?
_SPS_git_status_color() {
	{ [ -n "$SPS_STATUS" ] && _SPS_is_git_repo; } || return

	_SPS_save_git_status

	if [ -f "$_SPS_TMP/git_clean" ]; then
		printf "$_SPS_SGR_FG_GREEN"
	else
		printf "$_SPS_SGR_FG_RED"
	fi
}

_SPS_save_git_status() {
	# if in a git work tree
	if _sps_local="$(LANG=C LC_ALL=C git status --branch --porcelain 2>/dev/null)"; then
		# first line has branch info. 2nd line onwards have change info
		if [ "$(printf '%s\n' "$_sps_local" | wc -l)" -gt 1 ]; then
			rm -f "$_SPS_TMP/git_clean"
			return
		fi
	fi

	touch "$_SPS_TMP/git_clean"
}

# TODO: why are color and symbol separate functions?
#   is it to support the shells not supporting zero-width escape sequences?
_SPS_git_status_symbol() {
	{ [ -n "$SPS_STATUS" ] && _SPS_is_git_repo; } || return

	if [ -f "$_SPS_TMP/git_clean" ]; then
		printf 'v'
	else
		printf '~~~'
	fi
}

_SPS_git_close_bracket() {
	_SPS_is_git_repo && printf ']'
}

# Cleanup on exit

# called by `trap` when shell session is exited
_SPS_cleanup() {
	rm -rf "$_SPS_TMP"

	local tmp_root=${_SPS_TMP%/*}

	if [ -z "$(find "$tmp_root" -mindepth 1 -type d)" ]; then
		rm -rf "$tmp_root"
	fi

	return 0
}

# trap when shell session is exited
trap "_SPS_cleanup" EXIT

# Main

_SPS_main
