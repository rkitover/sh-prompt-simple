## sh-prompt-simple

![how the prompt looks in a window](/screenshots/sh-prompt-simple-screenshot.png?raw=true)

This is a simple, lightweight, and nice looking prompt that runs quickly
even in very slow shells like MSYS2, Cygwin and WSL.

It's colorful and shows the git branch when in a git checkout, as well as the
last command exit status (green checkmark for success and red X mark for
non-zero exit.)

It can also show a clean/dirty git status indicator if you set this variable:

```bash
export SPS_STATUS=1
```
. This is disabled by default because it makes the prompt much slower on things
like MSYS2/Cygwin, but it will work fine on Linux. You can also try it on
MSYS2/Cygwin and see if the slowdown is acceptable for you.

You can turn it on or off without re-sourcing any files, so if it's particularly
slow in a large repository you can just do:

```bash
unset SPS_STATUS
```
, to turn it off.

It may be particularly slow when entering a repository, but after that it will
be cached and the prompt will be much faster.

On MSYS2 it also shows the current value of `$MSYSTEM`, that is either `MSYS`,
`MINGW32` or `MINGW64`.

It is compatible with bash, zsh and some other POSIX sh implementations such as
busybox, (d)ash, ksh, etc..

It's based on the [Solarized
Extravagant](https://github.com/magicmonty/bash-git-prompt/blob/master/themes/Solarized_Extravagant.bgptheme)
theme in [bash-git-prompt](https://github.com/magicmonty/bash-git-prompt), but
it doesn't have any of the bash-git-prompt features except the git branch, exit
status and nice colors. And the optional status indicator mentioned above.

Enjoy!

### installation

```shell
mkdir -p ~/source/repos
cd ~/source/repos
git clone https://github.com/rkitover/sh-prompt-simple
```

Somewhere in your shell startup file such as `~/.bashrc` put something like this:

```bash
. ~/source/repos/sh-prompt-simple/prompt.sh
```

. For bash I also recommend:

```bash
shopt -s checkwinsize
export PROMPT_COMMAND='history -a'
```
.
