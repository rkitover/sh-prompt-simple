<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [sh-prompt-simple](#sh-prompt-simple)
  - [installation](#installation)
  - [configuration](#configuration)
    - [SPS_STATUS](#sps_status)
    - [SPS_ESCAPE](#sps_escape)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## sh-prompt-simple

![how the prompt looks in a
window](/screenshots/sh-prompt-simple-demo.png?raw=true)

This is a simple, lightweight, and nice looking prompt that runs quickly
even in very slow shells like MSYS2, Cygwin and WSL.

It shows the short name of the current environment (distribution, OS, etc.,) the
git branch when in a git checkout, the last command exit status (green checkmark
for success and red X mark for non-zero exit) and an optional clean/dirty git
status indicator.

This prompt is compatible with bash, zsh and some other POSIX sh
implementations such as busybox, (d)ash, ksh, etc..

It's based on the [Solarized
Extravagant](https://github.com/magicmonty/bash-git-prompt/blob/master/themes/Solarized_Extravagant.bgptheme)
theme in [bash-git-prompt](https://github.com/magicmonty/bash-git-prompt).

I also made a [PowerShell version of this
prompt](https://gist.github.com/rkitover/61b85690896e29b42897b99c2486477c).

### installation

```shell
mkdir -p ~/source/repos
cd ~/source/repos
git clone https://github.com/rkitover/sh-prompt-simple
```

Somewhere in your shell startup file such as `~/.bashrc` put something like this:

```bash
SPS_STATUS=1
. ~/source/repos/sh-prompt-simple/prompt.sh
```
. For bash I also recommend:

```bash
shopt -s checkwinsize
PROMPT_COMMAND='history -a'
```
.

### configuration

#### SPS_STATUS

To show a clean/dirty git status indicator, set this variable:

```bash
SPS_STATUS=1
```
. This is disabled by default because it makes the prompt much slower on things
like MSYS2/Cygwin, but it will work fine on Linux. You can also try it on
MSYS2/Cygwin and see if the slowdown is acceptable for you.

You can turn it on or off without re-sourcing any files, so if it's
particularly slow in a large repository you can just do:

```bash
unset SPS_STATUS
```

, to turn it off.

It may be particularly slow when entering a repository, but after that it will
be cached and the prompt will be much faster.

#### SPS_ESCAPE

The prompt tries to detect bash/busybox/(d)ash/ksh and use zero-width escape
sequences if found. If your shell does not support the `\[ ... \]` zero-width
escape sequences, for example because you didn't turn on the fancy prompt
feature in busybox, you can turn them off by setting:

```bash
SPS_ESCAPE=0
```
, or force them on with:

```bash
SPS_ESCAPE=1
```
. If you have a wide enough window, the prompt will work more or less ok without
the escape sequences in shells that don't support them.
