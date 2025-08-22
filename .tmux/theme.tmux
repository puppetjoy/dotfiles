#!/usr/bin/env zsh
#
# theme.tmux
#
# Try to determine the actual terminal in which the session is attached
# and set colors and status bar appearance based on the available
# capabilities.
#
# The theme is loosely modeled off of my custom Vim Airline tabline theme.
#

# Grab and export the current outside TERM variable.
eval $(tmux show-environment -gs TERM)

tmux_term='tmux'

if [[ $TERM == *truecolor* ]]; then
    tmux_term+='-truecolor'
    base00='#000000'
    base01='#282828'
    base02='#383838'
    base03='#585858'
    base04='#b8b8b8'
    base05='#d8d8d8'
    base06='#e8e8e8'
    base07='#f8f8f8'
    base08='#ab4642'
    base09='#dc9656'
    base0A='#f7ca88'
    base0B='#a1b56c'
    base0C='#86c1b9'
    base0D='#7cafc2'
    base0E='#ba8baf'
    base0F='#a16946'
    status_style="bold"
    version_style="fg=${base00},none"
    tmux setw -g window-status-last-style "bg=${base02}"
elif (( terminfo[colors] >= 256 )); then
    tmux_term+='-256color'
    base00='colour0'
    base01='colour18'
    base02='colour19'
    base03='colour8'
    base04='colour20'
    base05='colour7'
    base06='colour21'
    base07='colour15'
    base08='colour1'
    base09='colour16'
    base0A='colour3'
    base0B='colour2'
    base0C='colour6'
    base0D='colour4'
    base0E='colour5'
    base0F='colour17'
    status_style="bold"
    version_style="fg=${base00},none"
    tmux setw -g window-status-last-style "bg=${base02}"
elif (( terminfo[colors] >= 16 )); then
    base00='colour0'
    base01='colour0'
    base02='colour0'
    base03='colour8'
    base04='colour7'
    base05='colour7'
    base06='colour15'
    base07='colour15'
    base08='colour1'
    base09='colour3'
    base0A='colour3'
    base0B='colour2'
    base0C='colour6'
    base0D='colour4'
    base0E='colour5'
    base0F='colour8'
    status_style="bold"
    version_style="fg=colour8,none"
    tmux setw -g window-status-last-style "bold"
else
    base00='colour0'
    base01='colour0'
    base02='colour0'
    base03='colour0'
    base04='colour7'
    base05='colour7'
    base06='colour7'
    base07='colour7'
    base08='colour1'
    base09='colour3'
    base0A='colour3'
    base0B='colour2'
    base0C='colour6'
    base0D='colour4'
    base0E='colour5'
    base0F='colour0'
    status_style="nobold"
    version_style="fg=colour8,bold"
    tmux setw -g window-status-last-style "bold"
fi

# Appearance settings that apply to all terminal types
tmux set -g status-style "bg=${base01}"
tmux set -g status-left-length 100
tmux set -g status-right "#[fg=${base08},bold]#{?pane_synchronized,<SYNC>,}#[${version_style}] v$(< ~/.version) "
tmux setw -g window-status-separator ''
tmux setw -g window-status-format ' #I: #W#F '
tmux setw -g window-status-current-format ' #I: #W#F '
tmux setw -g window-status-current-style "bg=blue,fg=${base01},${status_style}"
tmux setw -g window-status-activity-style "bg=green,fg=${base01}"
tmux setw -g window-status-bell-style "bg=yellow,fg=${base01}"

# Per-terminal settings
if [[ $TERM == *powerline* ]]; then
    tmux_term+='-powerline'
    separator=''
else
    separator='>'
fi

if [[ $TERM == vt* ]]; then
    separator=''
    tmux set -g set-titles off
else
    tmux set -g set-titles on
    tmux set -g set-titles-string '#S:#I:#W > #T'
fi

# Detect if we're running in another tmux session and set prefix and
# appearance accordingly
if [[ $TERM == tmux* ]]; then
    tmux unbind C-b; tmux set -g prefix C-a; tmux bind C-a send-prefix
    session_color='magenta'
else
    tmux unbind C-a; tmux set -g prefix C-b; tmux bind C-b send-prefix
    session_color='cyan'
fi

tmux set -g status-left-style "bg=${session_color},fg=${base01}"
tmux set -g status-left " #[${status_style}]#S#[nobold] #[reverse]${separator} "

# 'tmux_term' is built up based on the outside terminal capabilities and is
# one of:
#
# * tmux
# * tmux-powerline
# * tmux-256color
# * tmux-256color-powerline
# * tmux-truecolor
# * tmux-truecolor-powerline
#
tmux set -s default-terminal "$tmux_term"

# vim:ft=zsh
