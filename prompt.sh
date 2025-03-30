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
	_SPS_set_sps_colors
	_SPS_set_sps_prompt_char

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
	_SPS_TMP="${XDG_RUNTIME_DIR:-${TMPDIR:-${TEMP:-${TMP:-/tmp}}}}/sh-prompt-simple/$$"

	if [ "$_SPS_PLATFORM" = 'windows' ] && [ -z "$_SPS_TMP" ]; then
		_SPS_TMP="$(printf '%s' "$USERPROFILE/AppData/Local/Temp/sh-prompt-simple/$$" | tr '\\' '/')"
	fi

	mkdir -p "$_SPS_TMP"
}

# init script constants

## ANSI Escape Codes

_SPS_set_sps_colors() {
	# background-color

	# (foreground) color
	_SPS_SGR_FG_RED='\033[31m'
	_SPS_SGR_FG_GREEN='\033[32m'
	_SPS_SGR_FG_YELLOW='\033[33m'
	_SPS_SGR_FG_MAGENTA='\033[35m'
	_SPS_SGR_FG_CYAN='\033[36m'
	_SPS_SGR_FG_BRIGHT_MAGENTA='\033[95m'
	_SPS_SGR_FG_WHITE='\033[97m'
	_SPS_SGR_FG_8CCEFA='\033[38;2;140;206;250m'
	_SPS_SGR_FG_C8143C='\033[38;2;220;20;60m'

	# text-decoration
	_SPS_SGR_TD_NORMAL='\033[0m'
	_SPS_SGR_TD_BOLD='\033[1m'
}

## _SPS_PROMPT_CHAR

_SPS_set_sps_prompt_char() {
	[ "$(id -u)" = 0 ] && _SPS_PROMPT_CHAR='#' || _SPS_PROMPT_CHAR='>'
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
${_SPS_SGR_FG_BRIGHT_MAGENTA}${_SPS_PLATFORM} \
${_SPS_SGR_FG_YELLOW}$(_SPS_pwd)\
${_SPS_SGR_FG_CYAN}$(_SPS_git_open_bracket)\
${_SPS_SGR_FG_MAGENTA}$(_SPS_git_branch)\
${_SPS_SGR_FG_WHITE}$(_SPS_git_sep)\
$(_SPS_git_status_color)$(_SPS_git_status_symbol)\
${_SPS_SGR_FG_CYAN}$(_SPS_git_close_bracket)
"
	}

	PS1="%{${_SPS_SGR_FG_8CCEFA}%}${USER}%{${_SPS_SGR_TD_BOLD}${_SPS_SGR_FG_WHITE}%}@%{${_SPS_SGR_TD_NORMAL}${_SPS_SGR_FG_8CCEFA}%}${_SPS_HOSTNAME} %{${_SPS_SGR_FG_C8143C}%}${_SPS_PROMPT_CHAR}%{${_SPS_SGR_TD_NORMAL}%} "
}

## Shells that support esacpe

# TODO: Why are these using backticks '`...`' for command substitution?
# TODO:  Is it to support old shels that do not support '$(...)'?
_SPS_set_ps1_not_zsh_with_escape() {
	PS1="\
"'`_SPS_save_last_exit_status`'"\
\["'`_SPS_set_window_title`'"\]\
\["'`_SPS_last_exit_status_color`'"\]"'`_SPS_last_exit_status_symbol`'" \
\[${_SPS_SGR_FG_BRIGHT_MAGENTA}\]${_SPS_PLATFORM} \
\[${_SPS_SGR_FG_YELLOW}\]"'`_SPS_pwd`'"\
\[${_SPS_SGR_FG_CYAN}\]"'`_SPS_git_open_bracket`'"\
\[${_SPS_SGR_FG_MAGENTA}\]"'`_SPS_git_branch`'"\
\[${_SPS_SGR_FG_WHITE}\]"'`_SPS_git_sep`'"\
\["'`_SPS_git_status_color`'"\]"'`_SPS_git_status_symbol`'"\
\[${_SPS_SGR_FG_CYAN}\]"'`_SPS_git_close_bracket`'"
\[${_SPS_SGR_FG_8CCEFA}\]${USER}\
\[${_SPS_SGR_TD_BOLD}${_SPS_SGR_FG_WHITE}\]@\
\[${_SPS_SGR_FG_8CCEFA}\]${_SPS_HOSTNAME} \
\[${_SPS_SGR_FG_C8143C}\]${_SPS_PROMPT_CHAR}\
\[${_SPS_SGR_TD_NORMAL}\] "
}

## Shells that do not support esacpe

# TODO: Why are these using backticks '`...`' for command substitution?
# TODO:  Is it to support old shells that do not support '$(...)'?
_SPS_set_ps1_not_zsh_without_escape() {
	PS1="\
"'`_SPS_save_last_exit_status`'"\
"'`_SPS_set_window_title`'"\
"'`_SPS_last_exit_status_color``_SPS_last_exit_status_symbol`'" \
${_SPS_SGR_FG_BRIGHT_MAGENTA}${_SPS_PLATFORM} \
${_SPS_SGR_FG_YELLOW}"'`_SPS_pwd`'"\
${_SPS_SGR_FG_CYAN}"'`_SPS_git_open_bracket`'"\
${_SPS_SGR_FG_MAGENTA}"'`_SPS_git_branch`'"\
${_SPS_SGR_FG_WHITE}"'`_SPS_git_sep`'"\
"'`_SPS_git_status_color``_SPS_git_status_symbol`'"\
${_SPS_SGR_FG_CYAN}"'`_SPS_git_close_bracket`'"
${_SPS_SGR_FG_8CCEFA}${USER}\
${_SPS_SGR_TD_BOLD}${_SPS_SGR_FG_WHITE}@\
${_SPS_SGR_FG_8CCEFA}${_SPS_HOSTNAME} \
${_SPS_SGR_FG_C8143C}${_SPS_PROMPT_CHAR}\
${_SPS_SGR_TD_NORMAL} "
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
		printf '%b' "$_SPS_SGR_FG_GREEN"
	else
		printf '%b' "$_SPS_SGR_FG_RED"
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
	_SPS_save_git_status
	_SPS_is_git_repo && printf ' ['
}

# `git status --branch --porcelain`
# IF is in work tree
#   1st line has branch info in format
#     '## LOCAL_BRANCH
#     '## LOCAL_BRANCH...REMOTE/REMOTE_BRANCH
#     '## LOCAL_BRANCH...REMOTE/REMOTE_BRANCH [ahead N, behind Y]
#   2nd line onwards have change info, one line per file, if any changes.
# IF is bare repo or in .git directory
#   fatal: this operation must be run in a work tree
# IF is not a git repo
#   fatal: not a git repository (or any of the parent directories): .git
#
_SPS_save_git_status() {
	if _sps_local="$(LANG=C LC_ALL=C git status --branch --porcelain 2>&1)"; then
		# IF   `git status` does not error out
		# THEN PWD is in a git work tree

		if [ "$(printf '%s\n' "$_sps_local" | wc -l)" -eq 1 ]; then
			# IF   the output is only 1 line
			# THEN the work tree is clean

			if [ "${_sps_local#\[*}" != "$_sps_local" ]; then
				# IF   the output (first line) includes a '['
				# THEN the local branch is ahead or behind the upstream
				rm -f "$_SPS_TMP/git_clean"
			else
				# ELSE the local branch is either in sync with the upsteam, or has no upstream
				touch "$_SPS_TMP/git_clean"
			fi
		else
			# ELSE the work tree is dirty
			# AND the local branch matches the remote branch (if any)
			rm -f "$_SPS_TMP/git_clean"
		fi

		# get branch name
		_sps_local="${_sps_local%%\n*}"  # take only first line
		_sps_local="${_sps_local#* }"    # strip leading '## '
		_sps_local="${_sps_local%%...*}" # strip from (first) '...' onwards
		printf '%s' "$_sps_local" > "$_SPS_TMP/git_branch"
	else
		# ELSE PWD is in the .git tree or in a bare repo or not in a git repo

		if [ "${_sps_local%.git}" != "$_sps_local" ]; then
			# IF   STDERR message ends with '.git'
			# THEN PWD is not in a git repo
			rm -f "$_SPS_TMP/git_branch"
		else
			# ELSE PWD is in the .git tree or in a bare repo
			touch "$_SPS_TMP/git_clean"

			# get branch name
			_sps_local="$(git branch)"
			_sps_local="${_sps_local#*\* }"
			_sps_local="${_sps_local%% *}"
			printf '%s' "$_sps_local" > "$_SPS_TMP/git_branch"
		fi
	fi
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

	if [ -f "$_SPS_TMP/git_clean" ]; then
		printf '%b' "$_SPS_SGR_FG_GREEN"
	else
		printf '%b' "$_SPS_SGR_FG_RED"
	fi
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
}

# trap when shell session is exited
trap "_SPS_cleanup" EXIT

# Main

_SPS_main
