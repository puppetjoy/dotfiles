# Check for newer local version of zsh
autoload -U is-at-least
if ! is-at-least 5.2; then
    for zsh in $HOME/local/bin/zsh; do
        [[ -x $zsh ]] && exec $zsh
    done
fi

# Re-assert environment after system zprofile modifications
source "$HOME/.zshenv"

# Override TERM for Windows Terminal so tmux can match truecolor support
if [[ $WT_SESSION && $TERM == xterm-256color* && $TERM != *truecolor* ]]; then
    export TERM="${TERM/xterm-256color/xterm-truecolor}"
fi

# Override TERM for VS Code. It can't be configured.
if [[ $TERM_PROGRAM == 'vscode' && $TERM != *-powerline ]]; then
    export TERM="${TERM}-powerline"
fi

# Prefer an explicit override, otherwise follow the host appearance
# VS Code's shell integration does not expose the active color theme
colorscheme_light_is_enabled() {
    local apps_use_light_theme
    local color_scheme
    local gtk_theme
    local kde_background
    local kdeglobals
    local -a rgb

    case ${COLORSCHEME_LIGHT_OVERRIDE:l} in
        1|yes|true|on|light)
            return 0
            ;;
        0|no|false|off|dark)
            return 1
            ;;
    esac

    case $OSTYPE in
        darwin*)
            [[ $(defaults read -g AppleInterfaceStyle 2>/dev/null) != 'Dark' ]]
            return
            ;;
        cygwin*|msys*)
            if whence reg.exe > /dev/null; then
                apps_use_light_theme=$(reg.exe query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' /v AppsUseLightTheme 2>/dev/null | awk '/AppsUseLightTheme/ { print $NF; exit }')
                case $apps_use_light_theme in
                    0x1|1)
                        return 0
                        ;;
                    0x0|0)
                        return 1
                        ;;
                esac
            fi
            ;;
        linux*)
            if [[ -n $DBUS_SESSION_BUS_ADDRESS || -n $DISPLAY || -n $WAYLAND_DISPLAY ]] && whence gsettings > /dev/null; then
                color_scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
                case $color_scheme in
                    prefer-dark)
                        return 1
                        ;;
                    prefer-light)
                        return 0
                        ;;
                esac

                gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
                if [[ -n $gtk_theme ]]; then
                    if [[ ${gtk_theme:l} == *dark* ]]; then
                        return 1
                    fi

                    return 0
                fi
            fi

            if [[ -n $DBUS_SESSION_BUS_ADDRESS || -n $DISPLAY || -n $WAYLAND_DISPLAY ]]; then
                kdeglobals="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
                if [[ -r $kdeglobals ]]; then
                    kde_background=$(awk -F= '
                        $0 == "[Colors:Window]" { in_window = 1; next }
                        /^\[/ { in_window = 0 }
                        in_window && $1 == "BackgroundNormal" { print $2; exit }
                    ' "$kdeglobals")
                    if [[ -n $kde_background ]]; then
                        rgb=(${(s:,:)kde_background})
                        if (( $#rgb == 3 )); then
                            (( rgb[1] * 299 + rgb[2] * 587 + rgb[3] * 114 >= 128000 ))
                            return
                        fi
                    fi
                fi
            fi
            ;;
    esac

    return 1
}

if colorscheme_light_is_enabled; then
    export COLORSCHEME_LIGHT=1
else
    export COLORSCHEME_LIGHT=0
fi

# Keep shell state aligned with the dark-only Linux console palette so the
# prompt and any downstream consumers do not pick a light scheme.
if [[ $TERM == 'linux' ]]; then
    export COLORSCHEME_LIGHT=0
fi

if [[ ($TERM == *256color* || $TERM == foot* || $TERM == mintty*) && $TERM != tmux* ]]; then
    # Configure color palette on modern terminals
    if [[ $COLORSCHEME_LIGHT == 1 ]]; then
        print -Pn '\e]4;0;rgb:ff/ff/ff\a\e]4;1;rgb:c8/28/29\a\e]4;2;rgb:71/8c/00\a\e]4;3;rgb:ea/b7/00\a\e]4;4;rgb:42/71/ae\a\e]4;5;rgb:89/59/a8\a\e]4;6;rgb:3e/99/9f\a\e]4;7;rgb:4d/4d/4c\a\e]4;8;rgb:8e/90/8c\a\e]4;9;rgb:c8/28/29\a\e]4;10;rgb:71/8c/00\a\e]4;11;rgb:ea/b7/00\a\e]4;12;rgb:42/71/ae\a\e]4;13;rgb:89/59/a8\a\e]4;14;rgb:3e/99/9f\a\e]4;15;rgb:1d/1f/21\a\e]4;16;rgb:f5/87/1f\a\e]4;17;rgb:a3/68/5a\a\e]4;18;rgb:e0/e0/e0\a\e]4;19;rgb:d6/d6/d6\a\e]4;20;rgb:96/98/96\a\e]4;21;rgb:28/2a/2e\a\e]10;rgb:4d/4d/4c\a\e]11;rgb:ff/ff/ff\a\e]12;rgb:4d/4d/4c\a'
    else
        print -Pn '\e]4;0;rgb:00/00/00\a\e]4;1;rgb:ab/46/42\a\e]4;2;rgb:a1/b5/6c\a\e]4;3;rgb:f7/ca/88\a\e]4;4;rgb:7c/af/c2\a\e]4;5;rgb:ba/8b/af\a\e]4;6;rgb:86/c1/b9\a\e]4;7;rgb:d8/d8/d8\a\e]4;8;rgb:58/58/58\a\e]4;9;rgb:ab/46/42\a\e]4;10;rgb:a1/b5/6c\a\e]4;11;rgb:f7/ca/88\a\e]4;12;rgb:7c/af/c2\a\e]4;13;rgb:ba/8b/af\a\e]4;14;rgb:86/c1/b9\a\e]4;15;rgb:f8/f8/f8\a\e]4;16;rgb:dc/96/56\a\e]4;17;rgb:a1/69/46\a\e]4;18;rgb:28/28/28\a\e]4;19;rgb:38/38/38\a\e]4;20;rgb:b8/b8/b8\a\e]4;21;rgb:e8/e8/e8\a\e]10;rgb:d8/d8/d8\a\e]11;rgb:00/00/00\a\e]12;rgb:d8/d8/d8\a'
    fi
elif [[ $TERM == 'linux' && -o login && ! $SSH_CONNECTION ]]; then
    # Set Linux console color palette.  See console(4).
    print -Pn '\e]P0000000\e]P1ab4642\e]P2a1b56c\e]P3f7ca88\e]P47cafc2\e]P5ba8baf\e]P686c1b9\e]P7d8d8d8\e]P8585858\e]P9ab4642\e]Paa1b56c\e]Pbf7ca88\e]Pc7cafc2\e]Pdba8baf\e]Pe86c1b9\e]Pff8f8f8'
    clear
fi

# Run tmux if it's not running, except in Codex shells.  I don't exec
# 't' in general because if tmux is unavailable, then it will return a
# non-zero exit code and zsh will continue as a fallback; and when tmux
# does run and exits cleanly, I still want ~/.zlogout evaluated.
# Cygwin xterm visibly warns that a process received SIGHUP when the
# window is closed, so exec tmux there to remove the parent zsh from the
# shutdown path.
t3code_shell_is_running() {
    [[ $T3CODE_PROJECT_ROOT || $CHROME_DESKTOP == 't3code.desktop' ]]
}

if [[ ! $TMUX && $CODEX_SHELL != 1 ]] && ! t3code_shell_is_running; then
    if [[ $OSTYPE == 'cygwin' && $TERM == xterm* && -x $(whence -p tmux) ]]; then
        exec t 2>/dev/null
    fi

    t 2>/dev/null && exit
fi

# History settings
HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=10000
setopt inc_append_history

if [[ ! -e $HISTFILE ]]; then
    if [[ -f ~/.history.$HOST ]]; then
        # Migrate from per-host history file
        mv -f ~/.history.$HOST $HISTFILE
    else
        touch $HISTFILE
        chmod 600 $HISTFILE
    fi
fi

if [[ ! -w $HISTFILE ]]; then
    echo
    echo "HISTFILE is not writable..."
    echo "Run \"s chown $USER:$(id -gn) $HISTFILE\" to fix."
    echo
fi

# Restore default redirect behavior
setopt clobber

# Disable annoying beep
unsetopt beep

# Enable vi keybindings
bindkey -v

# Make mode switches faster
export KEYTIMEOUT=1

# Enable history commands from emacs mode
# (just too useful)
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^R' history-incremental-pattern-search-backward
bindkey '^S' history-incremental-pattern-search-forward
stty -ixon      # make ^S available to shell

# Show user name at prompt if not one of my usual ones
zstyle ':prompt:mine' hide-users '(james|jlee|joy|jtl|root)'

# Figure out if I'm running as a priviliged user
if [[ $EUID == 0 ]]; then
    zstyle ':prompt:mine' root true
elif [[ $OS == 'Windows_NT' ]] && id -Gnz | tr '\0' '\n' | grep -q '^Administrators$'; then
    zstyle ':prompt:mine' root true
fi

# Figure out if I'm running with Glue admin rights
if klist 2>&1 | grep jtl/admin > /dev/null; then
    zstyle ':prompt:mine' admin true
fi

# Fallback to flat appearance if using a stupid terminal
if [[ $TERM != *powerline* ]]; then
    zstyle ':prompt:mine' flat true
fi

# Enable my command prompt
autoload -U promptinit && promptinit
prompt mine

# Enable command autocompletion
autoload -U compinit
compinit -u

# Color list autocompletion
if whence dircolors > /dev/null; then
    eval $(dircolors)
    zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
fi

# Aliases
ls --help 2>&1 | grep -- '--color=auto' > /dev/null && alias ls='ls --color=auto'
alias vi="$EDITOR"
unalias cp 2>/dev/null
alias mv='mv -f'
alias rm='rm -f'
alias r='[[ -S ${TMUX%%,*} ]] && eval "$(t show-environment -s)" && TERM="${${(s/ /)$(t show-options -s default-terminal)}[2]//\"/}"; exec $SHELL'
alias R=reset
alias bigsnaps='zfs list -t snapshot -s used'
alias caracara='xfreerdp /d: /dynamic-resolution /scale:180 /v:caracara.nest -grab-keyboard'
unalias suafs 2>/dev/null
unalias a 2>/dev/null
compdef a=sudo
compdef s=sudo
compdef t=tmux
compdef glue=ssh

alias j='ssh -J avw-unix-jump-noafs.umd.edu'
compdef j=ssh

# Kubernetes aliases
alias k='kubectl'
alias kg='kubectl get'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias klf='kubectl logs -f'

kdf() { watch -n 3 --no-wrap "kubectl describe $@ | tail -$((LINES - 3))" }
_kdf() { words=(kubectl describe $words[2,-1] ''); CURRENT=$((CURRENT + 1)); _kubectl }
compdef _kdf kdf

# systemd aliases
alias sc='systemctl'
alias scu='systemctl --user'
alias jc='journalctl'
alias jce='journalctl -e'
alias jcf='journalctl -f'
alias jcu='journalctl --user'
alias jcue='journalctl --user -e'
alias jcuf='journalctl --user -f'

# streamux aliases
alias sx='streamux'

# Easy way to switch to project
p() { cd "${HOME}/projects/${1}" && ls }
compdef "_files -W ${HOME}/projects" p

# Set standard umask
umask 022

# Start ssh-agent on platforms where/if necessary
if ([[ $OSTYPE == 'cygwin' ]] && ! pgrep -U $UID -x ssh-agent > /dev/null) ||
    [[ $OSTYPE == 'linux-android' && ! -S $SSH_AUTH_SOCK ]]; then
    rm -f "$SSH_AUTH_SOCK"
    eval $(ssh-agent -a "$SSH_AUTH_SOCK") > /dev/null
fi

# VS Code terminal settings
if [[ $TERM_PROGRAM == 'vscode' ]]; then
    # (Re)load shell integration
    # see: https://code.visualstudio.com/docs/terminal/shell-integration
    source "$(code --locate-shell-integration-path zsh 2>/dev/null)"
fi

# vim:ft=zsh
