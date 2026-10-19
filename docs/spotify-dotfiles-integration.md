# Spotify dotfiles integration

## Scope and ownership

This is the dotfiles source portion of rollout ^1990, prepared in ^1991.
Nest owns packages and `/usr/local/bin/nest-spotify`. The parent rollout owns
merge, managed deployment, real identity verification and acceptance.
No application launch, playback, login, live refresh or XMonad restart is part
of this child. This document is an integration contract, not live playback proof.

Follow-through mode: **merge + managed dotfiles refresh/deploy/apply on Falcon
and Hawk and verify live state**, owned by the parent after the Hawk package/DRM
canary and integration gates. Do not merge or deploy this child independently.

## Music workspace

- Workspace 4 is still `music`. Only entering an empty topic invokes its action.
  Existing Firefox/YTM sessions or other windows on that workspace are not closed
  or replaced, and therefore suppress the empty-topic action as before.
- An executable `/usr/local/bin/nest-spotify` selects Spotify at runtime; there
  are no new hostname conditions. Without it, the original Firefox music-profile
  kiosk action runs unchanged.
- Exact X11 classes `Spotify` and `nest-spotify` identify candidate music windows.
  Newly managed matches shift to `music` without imposing fullscreen. On empty
  topic activation, an existing managed match is moved back to `music` and
  focused rather than launching another window. The lowest window ID wins if
  multiple matches already exist; this does not close any duplicates.
- A twenty-second pending-launch timer prevents rapid empty-topic re-entry from
  spawning repeated launcher processes while a window maps. It expires to allow
  retries after failed launches. The launcher/backend must itself preserve
  single-instance behavior across slow startup or repeated manual invocation;
  this timer is not proof of application-level singleton behavior.
- Super+Ctrl+Y explicitly opens the original Firefox/YTM action separately.
- There is no global music autostart. Manual fullscreen, EWMH activation and all
  other manage-hook rules remain intact.

## Media controls

XMonad Super+Space and XF86AudioPlay still invoke `~/bin/playerctl play-pause`.
Sway now names that same wrapper explicitly instead of depending on PATH order.

The zsh wrapper retains the existing Gwenview exclusion. For unqualified
transport commands and seek/volume/loop/shuffle setters it discovers candidates:

- Exact native name `spotify`, or `spotify.instance` followed only by digits.
- Exact Chrome family `chromium`/`chrome`, optionally `.instance` followed only
  by digits, **and** `xesam:url` with exact origin `https://open.spotify.com/`,
  or a `spotify:track:`/`spotify:episode:` URI. Titles, artists and generic
  Chrome identity alone never qualify.

Selection does not depend on Playing versus Paused ordering. Exactly one
candidate is selected; multiple candidates or a dotted-prefix selector collision
fail without issuing a playback command. A selected-player command failure is
returned, never retried against an unrelated player. Playerctl itself matches
both a name and its dotted descendants, hence the overlap check.

No positive candidate retains the pre-existing generic playerctl fallback.
Unknown or missing browser metadata is not positive identification: this fallback
is compatibility behavior, not proof of Spotify control. In particular, parent
acceptance must show that Hawk retains identifying metadata while paused.

Explicit `--player`/`-p`, ignore overrides, `--all`, `--follow`, list commands,
status/metadata and read-only property queries pass through unchanged. A follow
stream keeps playerctl's own dynamic discovery, rather than pinning a startup
snapshot. Unrecognized command forms also preserve upstream behavior.

A normal Chrome Spotify page may have the same exact metadata as the dedicated
app. MPRIS metadata cannot prove Chrome profile ownership. Two matching sessions
therefore fail closed instead of guessing which profile is intended. If the live
Chrome build exposes a different name or URL, adjust the narrow contract with
real evidence; do not identify every Chrome session as Spotify.

## Parent integration gates before merge/deployment acceptance

1. Nest must install the launcher only on enabled hosts, with executable mode,
   native or dedicated official Chrome app-mode behavior, and no playback on
   launch. Keep `${XDG_CONFIG_HOME:-$HOME/.config}/nest-spotify` isolated from
   ordinary Chrome and Firefox profiles. No additional dotfiles launcher exists.
2. Verify real native WM_CLASS and MPRIS names. Verify what Chrome
   `--class=nest-spotify` actually emits; the XMonad query currently requires
   exact class `nest-spotify`, not a generic Google-chrome class or window title.
   Dialogs retain existing float/transience handling while sharing music placement.
3. Verify real Chrome `xesam:url` in playing and paused states, including after
   another browser plays media. If its media session aggregates unrelated tabs
   or loses identifying metadata, the proposed media-selection contract is not
   accepted. Record actual sanitized identities and revise source before rollout.
4. Compile the rendered Falcon and Hawk XMonad configurations using installed
   XMonad, xmonad-contrib and Taffybar dependencies. This worker has no GHC;
   successful ERB rendering and source assertions are not Haskell compilation.
5. Verify rapid repeated activation, moving a music window off its workspace,
   returning to an empty music topic, startup slower than the launch debounce,
   application close/relaunch and already-open YTM. Confirm launcher singleton
   behavior and no duplicate windows, including beyond the debounce interval.
6. After the parent's approved merge, use its normal managed dotfiles deployment
   and host package apply. These are separate from source rendering. Do not run
   the refresh script inside a linked worktree: its `.git/` test is unsafe there.
7. Coordinate live session activation separately. Joy normally uses Super+Q on
   Hawk; no XMonad restart without fresh permission. Test physical Super+Space,
   XF86AudioPlay, pause/resume and seek from another workspace with competing
   Firefox/YTM/Chrome sessions. Verify actual audio without changing audio routes.

## Source validation

Run from the isolated repository:

    zsh -n bin/playerctl
    python3 test/spotify_playerctl_test.py
    ruby test/spotify_music_workspace_test.rb
    ruby test/xmonad_manual_fullscreen_test.rb
    ruby test/agent_request_followthrough_semantics_test.rb
    git diff --check

The Python test substitutes a private backend into a temporary copy of the actual
wrapper; every invocation is recorded and no production playerctl is reachable.
It exercises native and URL-based selection, competing sessions, ambiguity,
explicit options, observations, seeking, fallback and failure propagation.
The Ruby test renders actual templates with fixture facts for multiple hosts and
asserts the lifecycle wiring. Its compile test runs GHC when available, otherwise
explicitly skips. Neither suite proves real window behavior or real MPRIS identity.
The new checks also run in the existing MR CI test job.

Collision hotspot: `.gitlab-ci.yml` has recent session-environment and Falcon
mouse checks. Preserve all of those commands when integrating this append-only
Spotify test addition.
