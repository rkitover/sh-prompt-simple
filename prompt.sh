#!/bin/sh

_SPS_main() {
	# init user config constants
	_SPS_vet_sps_escape

	# init system constants
	_SPS_vet_user
	_SPS_set_sps_hostname
	_SPS_set_sps_env
	_SPS_set_sps_tmp

	# init script constants
	_SPS_set_sps_csi
	_SPS_set_sps_prompt_char

	# do action
	_SPS_set_ps1
}

# init user config constants

## SPS_ESCAPE

_SPS_vet_sps_escape() {
	if [ -z "$SPS_ESCAPE" ] && _SPS_is_bash_or_ash_or_ksh; then
		SPS_ESCAPE=1
	fi
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

_SPS_vet_user() {
	: "${USER:=$(whoami)}"
}

## _SPS_HOSTNAME

_SPS_set_sps_hostname() {
	_SPS_HOSTNAME=$(hostname | sed -E 's/\..*//')
}

## _SPS_ENV

_SPS_set_sps_env() {
	case "$(_SPS_uname_o)" in
		*Linux)
			_SPS_ENV=$(_SPS_detect_distro)
			: "${_SPS_ENV:=linux}"
			;;
		*)
			_SPS_ENV=$(_SPS_detect_non_linux_env)
			;;
	esac
}

_SPS_uname_o() {
	# macOS does not have `uname -o`.
	uname -o 2>/dev/null || uname
}

_SPS_detect_distro() {
	[ -f /etc/os-release ] || return

	local distro="$(sed -nE '/^ID="/s/^ID="([^"]+)".*/\1/p; s/^ID=([^[:space:]]+)/\1/p; t match; d; :match; q' '/etc/os-release')"

	local normalized="$(echo "$distro" | sed -E '
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
	if [ "$(printf '%s' "$normalized" | wc -c)" -gt 15 ]; then
		normalized="$(echo "$distro" | sed -E '
			:abbrev
			s/(^|[[:space:][:punct:]]+)([[:alpha:]])[[:alpha:]]+/\1\2/
			t abbrev
			s/[[:space:][:punct:]]+//g
		')"
	fi

	printf '%s' "$normalized"
}

_SPS_detect_non_linux_env() {
	if [ -n "$TERMUX_VERSION" ]; then
		echo 'termux'
	elif [ "$(_SPS_uname_o)" = 'Darwin' ]; then
		echo 'macOS'
	elif [ "$(_SPS_uname_o)" = 'Msys' ] && [ -n "$MSYSTEM" ]; then
		echo "$MSYSTEM" | tr '[:upper:]' '[:lower:]'
	elif [ "$(_SPS_uname_o)" = Cygwin ]; then
		echo 'cygwin'
	elif _SPS_is_windows; then
		SPS_ESCAPE=1 # Possibly a busybox for Windows build.
		echo 'windows'
	else
		uname | sed -E 's/[[:space:][:punct:]]+/_/g'
	fi
}

_SPS_is_windows() {
	[ -d '/Windows/System32' ] && return 0

	printf '%s' "$(_SPS_uname_o)$(uname 2>/dev/null)" | grep -qi 'windows'
}

## _SPS_TMP

_SPS_set_sps_tmp() {
	_SPS_TMP="${TMP:-${TEMP:-${TMPDIR:-${XDG_RUNTIME_DIR:-/tmp}}}}/sh-prompt-simple/$$"

	if [ "$_SPS_ENV" = 'windows' ] && [ -z "$_SPS_TMP" ]; then
		_SPS_TMP="$(echo "$USERPROFILE/AppData/Local/Temp/sh-prompt-simple/$$" | tr '\\' '/')"
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

## SPS_WINDOW_TITLE

_SPS_window_title() {
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

# do action

## PS1

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

_SPS_set_ps1_zsh() {
	setopt PROMPT_SUBST

	precmd() {
		printf "\
$(_SPS_get_status)\
$(_SPS_window_title)\
$(_SPS_status_color)$(_SPS_status) \
\033[0;95m${_SPS_ENV} \
\033[33m$(_SPS_cwd) \
\033[0;36m$(_SPS_git_open_bracket)\
\033[35m$(_SPS_git_branch)\
\033[0;97m$(_SPS_git_sep)\
$(_SPS_git_status_color)$(_SPS_git_status)\
\033[0;36m$(_SPS_git_close_bracket)
"
	}

	PS1="%{${_SPS_CSI}[38;2;140;206;250m%}${USER}%{${_SPS_CSI}[1;97m%}@%{${_SPS_CSI}[0m${_SPS_CSI}[38;2;140;206;250m%}${_SPS_HOSTNAME} %{${_SPS_CSI}[38;2;220;20;60m%}${_SPS_PROMPT_CHAR}%{${_SPS_CSI}[0m%} "
}

_SPS_set_ps1_not_zsh_with_escape() {
	PS1="\
"'`_SPS_get_status`'"\
\["'`_SPS_window_title`'"\]\
\["'`_SPS_status_color`'"\]"'`_SPS_status`'" \
\[${_SPS_CSI}[0;95m\]${_SPS_ENV} \
\[${_SPS_CSI}[33m\]"'`_SPS_cwd`'" \
\[${_SPS_CSI}[0;36m\]"'`_SPS_git_open_bracket`'"\
\[${_SPS_CSI}[35m\]"'`_SPS_git_branch`'"\
\[${_SPS_CSI}[0;97m\]"'`_SPS_git_sep`'"\
\["'`_SPS_git_status_color`'"\]"'`_SPS_git_status`'"\
\[${_SPS_CSI}[0;36m\]"'`_SPS_git_close_bracket`'"
\[${_SPS_CSI}[38;2;140;206;250m\]${USER}\
\[${_SPS_CSI}[1;97m\]@\
\[${_SPS_CSI}[0;38;2;140;206;250m\]${_SPS_HOSTNAME} \
\[${_SPS_CSI}[38;2;220;20;60m\]${_SPS_PROMPT_CHAR}\
\[${_SPS_CSI}[0m\] "
}

_SPS_set_ps1_not_zsh_without_escape() {
	PS1="\
"'`_SPS_get_status`'"\
"'`_SPS_window_title`'"\
"'`_SPS_status_color``_SPS_status`'" \
${_SPS_CSI}[0;95m${_SPS_ENV} \
${_SPS_CSI}[33m"'`_SPS_cwd`'" \
${_SPS_CSI}[0;36m"'`_SPS_git_open_bracket`'"\
${_SPS_CSI}[35m"'`_SPS_git_branch`'"\
${_SPS_CSI}[0;97m"'`_SPS_git_sep`'"\
"'`_SPS_git_status_color``_SPS_git_status`'"\
${_SPS_CSI}[0;36m"'`_SPS_git_close_bracket`'"
${_SPS_CSI}[38;2;140;206;250m${USER}\
${_SPS_CSI}[1;97m@\
${_SPS_CSI}[0;38;2;140;206;250m${_SPS_HOSTNAME} \
${_SPS_CSI}[38;2;220;20;60m${_SPS_PROMPT_CHAR}\
${_SPS_CSI}[0m "
}

_SPS_quit() {
	rm -rf "$_SPS_TMP"

	local tmp_root=${_SPS_TMP%/*}

	if [ -z "$(find "$tmp_root" -mindepth 1 -type d)" ]; then
		rm -rf "$tmp_root"
	fi

	return 0
}

trap "_SPS_quit" EXIT


_SPS_get_status() {
	if [ "$?" -eq 0 ]; then
		echo 0 > "$_SPS_TMP/cmd_status"
	else
		echo 1 > "$_SPS_TMP/cmd_status"
	fi
}

_SPS_status_color() {
	if [ "$(cat "$_SPS_TMP/cmd_status")" -eq 0 ]; then
		printf "\033[0;32m"
	else
		printf "\033[0;31m"
	fi
}

_SPS_status() {
	if [ "$(cat "$_SPS_TMP/cmd_status")" -eq 0 ]; then
		printf 'v'
	else
		printf 'x'
	fi
}

_SPS_in_git_tree() {
	! command -v git >/dev/null && return 1

	if [ -f "$_SPS_TMP/in_git_tree" ]; then
		return "$(cat "$_SPS_TMP/in_git_tree")"
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
		echo 0 > "$_SPS_TMP/in_git_tree"

		return 0
	fi

	echo 1 > "$_SPS_TMP/in_git_tree"

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
		echo 0 > "$_SPS_TMP/git_status"
		printf "\033[0;32m"
	else
		echo 1 > "$_SPS_TMP/git_status"
		printf "\033[0;31m"
	fi
}

_SPS_git_status() {
	if [ -z "$SPS_STATUS" ] || ! _SPS_in_git_tree; then
		return
	fi

	if [ "$(cat "$_SPS_TMP/git_status")" = 0 ]; then
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

	rm "$_SPS_TMP/"*git* 2>/dev/null
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
