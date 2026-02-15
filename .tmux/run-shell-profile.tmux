#!/usr/bin/env zsh
#
# run-shell-profile.tmux
#
# Lightweight wrapper for timing tmux run-shell commands during startup.
# Enabled only when TMUX_STARTUP_PROFILE=1 is present in the environment.
#

label="$1"
shift

if [[ $TMUX_STARTUP_PROFILE != '1' ]]; then
    exec "$@"
fi

logfile="${TMUX_STARTUP_PROFILE_LOG:-/tmp/tmux-startup-${UID}.log}"

now_ns() {
    local ts
    ts="$(date +%s%N 2>/dev/null)"
    if [[ $ts == *N ]]; then
        # Fallback when %N is unsupported.
        ts="$(($(date +%s) * 1000000000))"
    fi
    print "$ts"
}

start_ns="$(now_ns)"
"$@"
rc="$?"
end_ns="$(now_ns)"

elapsed_ms="$(((end_ns - start_ns) / 1000000))"
print -r -- "$(date '+%Y-%m-%d %H:%M:%S') ${elapsed_ms}ms ${label} rc=${rc}" >> "$logfile"
exit "$rc"
