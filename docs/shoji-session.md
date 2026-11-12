# The formalwm session

formalwm is FormalShell's window manager on ShojiWM (FormalStudio/FormalShell `wm/`, the
design in its `docs/superpowers/specs/2026-11-11-shoji.md`). It is a second session beside
Hyprland, and the default one per host is the `session` argument of `linux()` in
`hosts/<host>/host.star`: `hyprland-uwsm` or `formalwm-uwsm`. This file is the checklist for
switching a host: what `hyprland.lua` does besides managing windows, and where each of those
now lives.

## How the session starts

| Step | Hyprland | formalwm |
| --- | --- | --- |
| Greeter entry | `wayland-sessions/hyprland-uwsm.desktop` | `wayland-sessions/formalwm-uwsm.desktop` |
| What uwsm starts | `hyprland.desktop` (the distro's) | `/usr/local/share/wayland-sessions/formalwm.desktop`, which runs `/usr/local/libexec/formalwm-session`, which runs `formalwm --tty` |
| Boot, nothing picked | `formalshell-login.sh`: uwsm, Hyprland with `--locked-cmd` | `formalshell-login.sh` reads `/etc/formalshell-greeter/default-session`: uwsm, `formalwm.desktop --locked`, which sets `FORMALWM_START_LOCKED=1` |
| Boot, another session picked on the lock | the boot lock's session chip lists `greeter.sessionDirs` from the user's own settings (the greeter's are 0700); with another session picked the password is checked, the lock stays, answers the keyring, writes `$XDG_RUNTIME_DIR/formalshell/login-session` and ends Hyprland, and `formalshell-login.sh` starts that session in the same login, taking the marker only from a runtime directory no other user can reach | the same, ending formalwm |
| Environment | `~/.config/uwsm/env`, `env-hyprland` (g815: the NVIDIA card as `AQ_DRM_DEVICES`) | `~/.config/uwsm/env`, `env-shojiwm` (g815: sources `env-hyprland`, the card as `SHOJI_TTY_DRM_DEVICE`) |
| `XDG_CURRENT_DESKTOP` | `Hyprland` | `ShojiWM`, which the core sets whatever uwsm says |
| The shell | `formalshell.service` from `graphical-session.target`, or the locked login's `--locked-cmd` | `~/.config/formalwm/formalshell-start.sh`, which formalwm runs once its socket is up |
| Portals | `hyprland-portals.conf` | `shojiwm-portals.conf` |
| Logout | the shell exits Hyprland, uwsm stops the session | the shell's `session.exit`, formalwm quits, uwsm stops the session and unsets `SHOJIWM_SOCKET` (put on its list by `uwsm finalize` in the start script) |

`formalshell.service` and every `gui(..., formalshell = True)` unit run under either desktop
(`XDG_CURRENT_DESKTOP` Hyprland or ShojiWM) and never under Plasma or Gaming Mode. The greeter
offers the host's default first (`greeter.defaultSession` in its settings, from
`sessions.star`), unless the user picked another one last.

## hyprland.lua, top to bottom

Engine paths are in FormalStudio/FormalShell, `wm/`, at the rev `formalwm` is pinned to.
"Settings" is `~/.config/formalwm/settings.json` (shared) and `host.json` (per host, g815 only).

| Lines | What | Under formalwm |
| --- | --- | --- |
| 1-8 | The boot splash ends before the compositor opens the card | spec: `formalwm-session` starts `formalos-splash-quit.service` before `formalwm` |
| 10-155 | Mac apps under atoll: while one has focus the shell switches to the submap `mac`, every bind but the SUPER and SUPER+SHIFT chords not in `macApps.reservedBinds`, so those reach the app as Command | engine: the hand over, `binds.handOver` on the engine's socket (FormalShell `7513a855`). The shell names the Mac window and sends `macApps.reservedBinds`; while that window has the keyboard the SUPER and SUPER+SHIFT binds are off the keys save the reserved ones, and every bind is back over any other window, a layer surface, the lock or the overview. No setting on the engine side |
| 156-178 | Window colours from `formalshell-colors.lua`, `hyprctl reload` | engine: the shell's `theme.set` on every connect and theme change (`formalwm/src/ipc.rs`); the fallback is `fs-wm-proto`'s `Theme::default()` |
| 180-219 | Rounding, blur, gaps, border, shadow, motion from `formalshell-chrome.lua` | engine: the same `theme.set` |
| 222-239 | Per-host `host.lua` | spec: `hosts/g815/home/.config/formalwm/host.json`, read by `core/src/settings.rs` over `settings.json`. e1504g has no `host.lua`, so it gets no `host.json`: the defaults (the laptop panel `eDP-1`, opacity 1) are what `hyprland.lua` gives it |
| 241-260 | The lid output dark while shut, flipped by the lid switch | engine: `lidOutput` (`core/src/settings.rs`, `formalwm/src/session.rs`), the core's lid switch. Proven headless only |
| 265 | Any other display at its highest refresh rate | settings: the catch-all `{ "mode": "highrr" }` |
| 268-281 | Nine named workspaces, the host's pins | settings, host.json |
| 284-297 | `XCURSOR_*`, `QS_ICON_THEME`, `QT_QPA_PLATFORMTHEME`, the host's GPU variables | engine: settings `env` and host.json `env` (`formalwm/src/session.rs`, `COMPOSITOR.env.apply`), which reach only what formalwm starts itself. Before formalwm starts: the cursor variables from `environment.d/10-session.conf` in the user manager, the rest from `uwsm/env` and g815's `env-shojiwm` |
| 301-329 | Keyboard, repeat, pointer and touchpad | settings `input`. Handed to the core's libinput; not proven on a real device |
| 330-454 | Gaps, border, tape, gestures, decoration, dim, opacity, blur | engine and settings. Group colours have no counterpart (no groups). Window opacity let less through than set in every engine build before `6f82047c`, the one pinned here (0.5 came out as 0.75, g815's 0.96 near opaque) |
| 425 | Black under everything | engine: `COMPOSITOR.output.set_clear_color` black (`formalwm/src/session.rs`), from the first frame |
| 430 | `focus_on_activate` | engine |
| 431 | `anr_missed_pings` | missing: the core has no dialog for a client that stopped answering. Proposal: drop, nothing depends on it |
| 434 | A restarted shell takes the lock back | core's session lock; lock and unlock proven, a restart while locked not yet |
| 440 | `direct_scanout = 0` on g815 (NVIDIA marks a fullscreen Vulkan swapchain out of date, black flashes in Sober) | engine: host.json `directScanout` false, handed to the core per output (`formalwm/src/session.rs`). Watch Sober on g815 after the switch |
| 445 | `cm_auto_hdr = 1` | engine: every output SDR until a fullscreen window shows HDR content (`formalwm/src/session.rs`). Not proven on an HDR panel |
| 452-454 | `xwayland.force_zero_scaling` | missing as a setting: X11 goes through the core's in-process xwayland-satellite, which scales on its own. Check an X11 app on g815's 1.25 panel after the switch |
| 464-468 | The DualSense touchpad: flat, 0.7 | settings `input.devices`. Not proven on the device |
| 475-492 | Animations on the shell's curves, no zoom on a new output | engine motion; nothing animates an output |
| 503-504 | Three-finger gestures | engine (`formalwm/src/gestures.rs`). Proven headless only |
| 506-561, 591-593 | The pointer hidden until the shell arrives, back after ten seconds without one | engine: `cursor_hidden` from the start, `wait_for_shell` (`formalwm/src/session.rs`), through the core's cursor override. No blank theme: the `formalos-blank` swap is Hyprland's alone |
| 563-580 | hypr-dynamic-cursors: lean and shake to find | engine: settings `cursor.dynamic` (stretch, tilt 20 at 3000, shake on), `formalwm/src/cursor.rs`. The `hypr-dynamic-cursors` package stays for Hyprland |
| 581-590 | XWayland's primary output, again on every new output | engine: `xwayland_primary` runs `xrandr` (`formalwm/src/session.rs`); `xrandr` is in `packages.star` |
| 598-739 | Every bind: the shell's IPC, volume, brightness, media, screenshots, the Copilot key (SUPER+SHIFT+F23), helium, lock and suspend, the MX Master's buttons | settings `binds`. SUPER+plus is bound twice in `hyprland.lua` (console and +10% width) and both are kept |
| 744-834 | Window rules: workspaces, floats, pins, Sober and Steam as games, Steam's idle pointer, picture in picture, Atoll's tag | settings `rules` |
| 789 | Minecraft confines the pointer | settings: the `confinePointer` rule on `Minecraft.*` |
| 843-862 | Blur and alpha threshold per shell layer, no layer animation | settings `layers` (`formalwm/src/layers.rs`) |

## Outside hyprland.lua

| What | Where |
| --- | --- |
| `formalshell.service` gated on Hyprland | spec: either desktop |
| `gui(..., hyprland = True)` units (Discord, wl-clip-persist, panel-gamma, padbridge) | spec: `formalshell = True`, either desktop. panel-gamma needs wlr-gamma-control, which the core has (`gamma_control.rs`) |
| `gtk-session-css` before the session | spec: wanted by both sessions' pre targets |
| earlyoom's list of processes it spares | spec: `formalwm` added |
| Screencast and screenshot portals | spec: ShojiWM's portal for ScreenCast and Screenshot, gtk for the rest, gnome-keyring and trove as for Hyprland |
| The greeter's default | spec: `greeter.defaultSession` per host; needs the shell at or past FormalShell `b8e8eb0e` |
| Starting locked | engine: `FORMALWM_START_LOCKED=1` drives `ConfigBuilder::start_locked`: nothing but the lock surface is drawn, the start script still runs and starts the shell, which takes the lock on `$XDG_RUNTIME_DIR/formalshell/login-lock` as under Hyprland (`formalshell-login.sh` writes it for both). Until the shell locks the screen is black and takes no input; with no shell it stays so and binds do nothing |
| logind's `Desktop` at the boot login | `/etc/formalshell/login-env.conf` defaults `XDG_SESSION_DESKTOP` to Hyprland, so a formalwm boot login is recorded as Hyprland in `loginctl`. Cosmetic: uwsm and the core set the desktop the session uses |
| The login keyring at an autologin | spec: `gnome-keyring-daemon.socket` in the user manager. The daemon PAM starts for a login with no password has no pkcs11 or secrets part (`module_instances: assertion 'funcs != NULL'`), so it refused the boot lock's unlock under either compositor, and the distro's autostart entries that add those parts show only under GNOME, MATE and Xfce. The socket's daemon carries both from the start |
| `~/.config/hypr/formalshell.lua` | the shell installer's Hyprland include, which `hyprland.lua` does not load. Nothing to move |

The shell matches on no desktop name: its OnlyShowIn and NotShowIn filter reads whatever
`XDG_CURRENT_DESKTOP` holds, so `ShojiWM` passes through. It uses no portal either
(screenshots through grim, recordings through wf-recorder, both wlr-screencopy, thumbnails
through the toplevel capture protocol), so the portals only matter to other apps.

## The Screenshot portal

ShojiWM's own portal answers Screenshot as well as ScreenCast from ShojiWM `85f78ef` on
(`4d0514924`), so `shojiwm-portals.conf` names `shojiwm` for both and no wlr portal is installed.

## Proven on the VM

fstestvm3 on g815, software rendering, with the spec of this branch: formalwm at FormalShell `6f82047c`,
ShojiWM at `85f78ef`, the shell at `ffb11cc3`.

| What | How |
| --- | --- |
| Boot into formalwm, locked | the boot's autologin with `FORMALWM_START_LOCKED=1`, recorded every 200 ms from power on: the boot splash, then black only, then the shell's boot lock (the splash's last picture dissolving into the backdrop, then the card). No frame shows the bar, a window or the wallpaper before it. The start script ran (it alone starts `formalshell.service`, which has no `WantedBy`), and the password opens the desktop |
| The greeter offers formalwm | preselected after a logout, beside Hyprland's entry |
| A greeter login reaches the bar over a window | foot from SUPER+Return, `graphical-session.target` and `formalshell.service` active with `XDG_CURRENT_DESKTOP=ShojiWM` and `SHOJIWM_SOCKET` |
| The Screenshot portal | answered by ShojiWM's own portal ("serving ScreenCast and Screenshot"), with no wlr portal installed; the picture shows the bar over foot |
| Lock and unlock | the shell's lock, unlocked by password |
| Logout | back to the greeter; no formalwm, Xwayland, shell, portal or client left, `SHOJIWM_SOCKET` gone from the user manager |
| Hyprland from the same greeter | logs in, the shell runs with `XDG_CURRENT_DESKTOP=Hyprland` |
| The pointer | Bibata-Modern-Classic, the arrow on the desktop and its text beam over foot |

The boot lock's session pick, with the shell at `4c5821f3`:

| What | How |
| --- | --- |
| The chip on the boot lock | lists FormalShell and formalwm, the running one ticked, over formalwm's locked boot and over Hyprland's |
| formalwm to Hyprland | Tab, Return, FormalShell, Return, the password: the lock holds until formalwm has gone, then Hyprland comes up unlocked in the same seat0 login (`loginctl` shows the one session, the login script's uwsm starts `hyprland.desktop`), no formalwm left, the marker gone |
| Hyprland to formalwm | the same from a boot with Hyprland as the slot's default, into formalwm with `SHOJIWM_SOCKET` |
| Logout after a pick | back to the greeter, from either direction |
| A wrong password with another session picked | "Wrong password", the pick kept, the compositor still running, no marker |
| The screen between the two compositors | QEMU screendumps at about 90 a second: the lock ("Unlocking…"), then black alone (one colour, no console text) for 1.1 s towards Hyprland and 3.1 s towards formalwm, then the destination's own fade in, unlocked |
| The login keyring | unlocked after a plain boot-lock unlock and after a pick in either direction (`org.freedesktop.Secret.Collection` `Locked` false) |
| Mac apps' hand over | `dev/mac-stub.py` focused under formalwm gets SUPER+Q and quits; the reserved SUPER+H stays formalwm's (the stub sees its release, not its press) |

![formalwm's pointer on Bibata-Modern-Classic](shoji-session/cursor.png)

With no theme found under `XCURSOR_PATH` (and openSUSE ships no `default` theme), the core draws its
own outline glyph (`fallback_cursor_image` in ShojiWM's `src/shojiwm_lib/src/cursor.rs`), as the VM
did before it had the `bibata` package and the cursor variables
([shoji-session/fallback-cursor.png](shoji-session/fallback-cursor.png), at the centre). Hyprland
falls back to its own logo there. The real hosts carry both, so the owner's first login gets
Bibata; after the switch, check the pointer once on each host. A fallback to an installed theme
such as Adwaita before the glyph is a candidate core patch.
