## sh-prompt-simple

This is a simple, lightweight, and nice looking prompt that runs quickly
even in very slow shells like MSYS2, Cygwin and WSL.

It's colorful and shows the git branch when in a git checkout, as well as the
last command exit status (green checkmark for success and red X mark for
non-zero exit.)

On MSYS2 it also shows the current value of `$MSYSTEM`, that is either `MSYS`,
`MINGW32` or `MINGW64`.

It is compatible bash, zsh or any POSIX compliant sh implementation such as
busybox, (d)ash, ksh, etc..

It's based on the [Solarized
Extravagant](https://github.com/magicmonty/bash-git-prompt/blob/master/themes/Solarized_Extravagant.bgptheme)
theme in [bash-git-prompt](https://github.com/magicmonty/bash-git-prompt), but
it doesn't have any of the bash-git-prompt features except the git branch, exit
status and nice colors.

Enjoy!

### installation

```shell
mkdir -p ~/source/repos
cd ~/source/repos
git clone https://github.com/rkitover/sh-prompt-simple
```

Somewhere in your shell startup file such as `~/.bashrc` put something like this:

```bash
source ~/source/repos/sh-prompt-simple/prompt.sh
```

. For bash I also recommend:

```bash
shopt -s checkwinsize
export PROMPT_COMMAND='history -a'
```
.
