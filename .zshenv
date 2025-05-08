# Always use unicode
export LANG=en_US.UTF-8

# Set path
typeset -U path
for dir in /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin /usr/glue/bin /usr/glue/sbin $HOME/bin $HOME/local/bin $HOME/streamux/bin; do
    [[ -e $dir ]] && path=($dir $path)
done

# Add streamux commands inside streamux shell
if [[ $STREAMUX && -e $HOME/streamux/libexec ]]; then
    path=($HOME/streamux/libexec $path)
fi

# Load extra functions
typeset -U fpath
fpath=("$HOME/.zsh/functions" $fpath)

# Editor is vim if it exists
if whence vim > /dev/null; then
    export EDITOR='vim'
else
    export EDITOR='vi'
fi

# Set some standard programs
export VISUAL=$EDITOR
export PAGER='less'

# For my custom terminal types
export TERMINFO="${HOME}/.terminfo"

# Enable X apps through sudo (along with env_keep)
export XAUTHORITY="${XAUTHORITY-$HOME/.Xauthority}"

# Enable access to ssh-agent that may be running under systemd or Cygwin
case $OSTYPE in
    'cygwin')
        export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-/tmp/ssh-agent-${UID}.socket}"
        ;;
    'linux-android')
        export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-/data/data/com.termux/files/usr/tmp/ssh-agent.socket}"
        ;;
    *)
        export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-${XDG_RUNTIME_DIR}/ssh-agent.socket}"
        ;;
esac

# Use Plasma theme outside of Plasma
export QT_QPA_PLATFORMTHEME=kde

# To find my custom ruby libraries
export RUBYLIB="${HOME}/lib/ruby"

# Don't mess with system gems
export GEM_HOME='/root/.local/share/gem/ruby/3.2.0'
path=($path "${GEM_HOME}/bin")

# XXX: Experimental settings
export MOZ_DBUS_REMOTE=1
export PAN_MESA_DEBUG=gl3

# For macOS
export CLICOLOR=1

# Let kubectl access my cluster by default
export KUBECONFIG=/nest/home/kubeconfigs/eyrie.conf

# vim:ft=zsh
