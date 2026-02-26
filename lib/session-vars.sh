#
# session-vars.sh
#
# This file contains all of the environment variables that seem to change
# between Plasma and Sway sessions.  Normally one's session and its environment
# variables are terminated upon logout, but mine has linger enabled for tmux,
# so we have to deal with these.
#

SESSION_VARS=(
    DBUS_SESSION_BUS_ADDRESS
    DESKTOP_SESSION
    GDK_DPI_SCALE
    GDK_SCALE
    GTK_MODULES
    GS_LIB
    I3SOCK
    KDEWM
    KDE_FULL_SESSION
    KDE_SESSION_UID
    KDE_SESSION_VERSION
    PLASMA_USE_QT_SCALING
    QT_AUTO_SCREEN_SCALE_FACTOR
    QT_FONT_DPI
    QT_SCALE_FACTOR
    SESSION_MANAGER
    SWAYSOCK
    WAYLAND_DISPLAY
    XCURSOR_THEME
    XCURSOR_SIZE
    XDG_RUNTIME_DIR
    XDG_CONFIG_DIRS
    XDG_CURRENT_DESKTOP
    XDG_DATA_DIRS
    XDG_SEAT
    XDG_SEAT_PATH
    XDG_SESSION_CLASS
    XDG_SESSION_DESKTOP
    XDG_SESSION_ID
    XDG_SESSION_PATH
    XDG_SESSION_TYPE
    XDG_VTNR
)
