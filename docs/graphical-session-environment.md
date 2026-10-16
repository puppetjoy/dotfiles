Graphical session environment contract
======================================

XMonad's startupHook (spawnOnce) and Sway's initial exec both stop the previous
graphical-session.target, run bin/reset-systemd-environment from the compositor's
own environment, then start their session target with && ordering. These hooks
run after the X server / Wayland compositor has established its display context.
An XMonad recompile/restart is not a new graphical session; spawnOnce deliberately
does not restart all applications. No caller or target ordering change is needed.

The shared helper clears SESSION_VARS from the persistent systemd user manager,
imports the current supported session values and explicit shell runtime defaults,
and synchronizes the existing user's D-Bus activation environment. DISPLAY and
XAUTHORITY belong to the same cleanup list as WAYLAND_DISPLAY and SWAYSOCK. Tmux
also uses this list, so reattachment propagates or removes the display context.
Only supported variable names are imported, never --all or an unqualified
import-environment. PATH and RUBYLIB are retained deliberately: their support was
why commit 0022b5d8 introduced whole-environment systemd import. Other deliberate
runtime defaults are enumerated in the helper; arbitrary credentials are not.

D-Bus cannot unset activation variables. An absent session value is explicitly
set to the empty string in D-Bus, while remaining absent in systemd. This clears
stale X11/Wayland display and authentication context across session transitions.
The helper does not infer that a compositor-provided DISPLAY is stale (Sway can
supply a valid Xwayland DISPLAY). It uses the current compositor's values, not a
persistent tmux or SSH environment. DBUS_SESSION_BUS_ADDRESS is not rewritten in
D-Bus: bus ownership is outside the graphical session lifecycle. No new bus is
created, and activation stays enabled. Existing reset-failed startup behavior is
preserved, but occurs only after successful synchronization. Synchronization
errors fail the helper and prevent callers starting session targets prematurely.

Validation
----------

Run python3 test/graphical_session_environment_test.py and zsh -n
bin/reset-systemd-environment. Command-double tests exercise X11, native Wayland,
repeated application, changed displays/auth paths, absent cross-session values,
allowlisting, error propagation and both existing caller orderings. They do not
claim a real Sway compositor launch or a fresh interactive login was performed.

On an explicitly authorized live canary, test/graphical_activation_probe.py
registers a unique temporary D-Bus service on the EXISTING bus, reads only four
nonsecret display/session variable values in its activated process, and calls
XOpenDisplay/XCloseDisplay without opening windows or reading window data. It
removes the service and scratch script/output afterward. It requires dbus-python
and libX11. Run it with the intended user's existing bus address; do not create a
parallel dbus-run-session bus as proof of the live bus state. The daemon's /proc
startup environment is not its mutable activation environment.

Deployment and live safety
--------------------------

Follow-through: merge + dotfiles refresh/deploy/apply and verify live state.
The changed helper and variable list are plain tracked files: no ERB edits or
rendering are required for their correctness. Nest::Base::Users owns /home/joy
as Vcsrepo[/home/joy], with refresh-/home/joy subscribed to it. Use that established
resource ownership for deployment, not direct source edits in a live home. Do
not run the hard-resetting refresh on a dirty home or in a linked worktree.

Do not restart the compositor, X, the user bus, or applications for verification.
For the current-session repair, use the current compositor's supported values.
Do not stop/start graphical targets: that could stop applications. Do not clear
failed units to make the canary look clean. A narrow synchronization can bypass
only the legacy reset-failed step while executing the helper's synchronization
logic. Record existing failed units separately and leave them unchanged.

Falcon is the live X11 canary, not a scope restriction. Both session types share
the correction; other host deployments and real Wayland verification must be
reported separately. An already-running Telegram single-instance handoff is not
proof of cold D-Bus activation. Preserve the running client and report any genuine
cold Telegram launch still requiring Joy to close and relaunch it voluntarily.
