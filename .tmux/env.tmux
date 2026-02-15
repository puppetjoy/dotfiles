#!/usr/bin/env zsh
#
# env.tmux
#
# Configure variables to be updated in session environment when session is
# attached.  This is done in a guarded fashion to prevent the list from growing
# repetitively when the tmux configuration is re-sourced.
#

# Cygwin does not switch between compositor sessions like Linux desktop hosts.
# Skip update-environment churn there to reduce startup overhead.
if [[ $OSTYPE == cygwin* || $OS == Windows_NT ]]; then
    exit 0
fi

source "${HOME}/lib/session-vars.sh"

for var in "${SESSION_VARS[@]}"; do
    if [[ ! $(tmux show -g update-environment) =~ "(^|\s|\")${var}(\"|\s|\$)" ]]; then
        tmux set -ag update-environment " ${var}"
    fi
done
