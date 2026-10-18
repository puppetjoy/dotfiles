# Falcon adaptive mouse profile

## Cause confirmed on 2026-10-17

Falcon runs XMonad/X11 with Plasma 6.7.5 background services and
xf86-input-libinput 1.5.0. Its MX Master 3S Mouse (XInput product identifiers
1133:45108 in XInput's decimal notation) has speed 0, non-natural scrolling,
and an adaptive driver default (`1,0,0`). Device ID 12 and event18 were only
observations, not stable policy identifiers.

Plasma has two distinct keys in `[Mouse]` of application-owned `kcminputrc`:

- `X11LibInputXAccelProfileFlat`: a computed default, overwritten by kcminit
- `XLbInptAccelProfileFlat`: the actual saved preference, previously absent

The previous mitigation corrected only the first key and the runtime property.
It did not save an explicit preference. In Plasma 6.7.5,
`X11LibinputDummyDevice::defaultsFromX()` initializes `flatProfile=true` and
ignores properties unless `num_items_return == 2`. The installed libinput
manual documents **three** bits: adaptive, flat, custom. Consequently startup
writes the computed default as true even when the device is adaptive. The
next initialization loads that default and applies flat acceleration. Speed
and hardware DPI need not change to cause this symptom.

References (exact examined release):

- https://github.com/KDE/plasma-desktop/blob/v6.7.5/kcms/mouse/backends/x11/x11_libinput_dummydevice.cpp#L205-L240
- https://github.com/KDE/plasma-desktop/blob/v6.7.5/kcms/mouse/backends/x11/x11_libinput_dummydevice.h#L302-L306
- https://github.com/KDE/plasma-desktop/blob/v6.7.5/kcms/mouse/backends/x11/x11_libinput_backend.cpp#L36-L42

A suspected in-memory kded mouse writer was not established. The inspected
kded touchpad backend explicitly selects touchpads, not this mouse. Nest's
`manifests/gui/xorg.pp` and `templates/xorg/libinput.conf.erb` specify the driver,
tapping and DPI scale, not flat acceleration. No Nest edit is needed.

## Real binary reproduction without changing the desktop

On Falcon, a fresh isolated `XDG_CONFIG_HOME` started with only the computed
default set false. An `LD_PRELOAD` interposer suppressed every XIChangeProperty
call and root cursor changes. A private `dbus-run-session` avoided using the
active session bus. No input events, credentials or application state were
captured. Running the installed module through kcminit produced:

    Initialization 1: computed key rewritten true; requested profile 1,0,0
    Initialization 2: computed key true; requested profile 0,1,0
    Add XLbInptAccelProfileFlat=false
    Initialization 3: computed key true; requested profile 1,0,0
    Initialization 4: computed key true; requested profile 1,0,0

This proves the writer and repeat-startup failure with the installed binary,
not merely a reimplementation of upstream logic. The real device remained
adaptive throughout. `test/fixtures/block-xi-writes.c` retains the interposer.
Use it only for this examined module; it is not a general X11 sandbox.

The tested invocation, with an isolated writable config directory and the
compiled interposer at `$probe/block-xi-writes.so`, was:

    DISPLAY=:0 QT_QPA_PLATFORM=xcb XDG_CONFIG_HOME="$probe/config" \
      LD_PRELOAD="$probe/block-xi-writes.so" dbus-run-session -- \
      kcminit /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_mouse.so

The short name `kcm_mouse` was not accepted by this installed kcminit; those
initial attempts were not reproduction passes.

## Durable policy and scope

`falcon-mouse-profile.service` runs `bin/configure-falcon-mouse` before
plasma-kcminit and plasma-ksmserver in the XMonad target. Both the service and
helper guard the host; the helper also rejects missing X display and Wayland.
It uses KConfig's native writer for **only** the explicit saved profile key.
It does not track or replace kcminputrc, rewrite the computed default, change
DPI, speed, scrolling, or unrelated settings, or issue runtime xinput commands.
A missing mouse at session startup is intentional: the saved preference must
already exist when it returns. There is no polling loop or hotplug daemon.

KDE's X11 mouse preference is inherently mouse-global on Falcon, not a
per-device preference. This is explicit rather than pretending that a global
KDE key can select one mouse. It does not alter other hosts or Wayland; KDE
uses a separate touchpad backend. Live runtime verification/mitigation must
match the MX Master mouse name and product identifiers, never a numeric ID.

For reconnect, the Xorg driver already initializes this mouse as adaptive,
speed 0 and natural scrolling off. The explicit native preference prevents
KDE initialization from replacing that with the erroneous computed default.
This fixes the demonstrated startup writer rather than fighting it after
every reconnect. No timer, Xorg override, hardware DPI reset or unrelated
scrolling-service change is necessary.

## Validation and deployment boundary

- `python3 test/falcon_mouse_profile_test.py`: host/session guards, exact key,
  repeated startup, disconnected-start independence, failure propagation,
  target wiring and ordering
- `python3 test/falcon_mouse_native_test.py`: optional real KDE tools with a
  temporary config; missing file, preservation of unrelated groups/keys and
  mode 0640, byte-idempotent second run. Passed on Falcon; explicitly skipped
  where KDE tools are absent
- Existing graphical session, XMonad fullscreen and follow-through tests
- `zsh -n bin/configure-falcon-mouse` and `git diff --check`
- A bounded 75-second property-only watch saw no natural reconnect or property
  change. No Bluetooth disconnect, logout, session/compositor restart or reboot
  was forced. Full-session restart and real reconnect remain unexercised;
  the installed-binary replay is startup-path coverage, not a full login test

Follow-through mode: merge + dotfiles refresh/deploy/apply and verify live
state on Falcon. These are plain tracked files; no ERB rendering or Puppet
apply is needed for their correctness. Refresh the clean canonical home clone
only after merge, reload user units, and start only the new preference service
with the current X11 environment. Do not restart KDE or the desktop to test it.
Verify the native preference plus the exact mouse's effective profile, speed
and scrolling after deployment. Do not run refresh-dotfiles in a linked
worktree (`.git` is a file there).
