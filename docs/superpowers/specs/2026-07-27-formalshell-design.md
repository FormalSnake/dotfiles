# FormalShell — design

**Date:** 2026-07-27
**Status:** approved design, pre-implementation
**Repo:** `FormalSnake/FormalShell` (new; the existing `FormalSnake/formalshell` Go
terminal shell gets renamed to `formalshell-go` first, GitHub redirects old links)
**License:** MIT (matches DMS so ported service code stays clean; quickshell is
LGPL-3.0, fine as a runtime dependency)

## What it is

A from-scratch Wayland desktop shell built on QuickShell (Qt/QML toolkit,
v0.3.x): one long-running process hosting bar, unified menu/launcher,
notifications, OSD, lock screen, screensaver, greeter, panels, clipboard
history, media, weather — compositor-agnostic behind a formal backend interface (niri primary,
Hyprland second), matugen-driven colors, brutalist/terminal aesthetic, and
first-party nix support designed so the consuming config needs near-zero glue
(the 712-line `dms.nix` is the anti-benchmark).

**Primary functional reference: Omarchy 4 ("quattro" branch).** Omarchy v4
hand-rolled its entire interactive shell in QuickShell (single process, plugin
surfaces, unified theming, IPC contract), replacing waybar/walker/mako/
swayosd/hyprlock. FormalShell is that architecture, generalized off Hyprland.
Where Omarchy and DMS both implement a surface, **Omarchy's implementation is
the reference** (its audio/network/bluetooth/power panels are explicitly
preferred over DMS's). DMS (MIT) is the reference only where Omarchy has
nothing: multi-compositor backend, matugen orchestration, media/now-playing,
greeter. The end goal is to replace DMS on the g815/e1504g; all development
and testing happens in isolation (nested niri) until the switchover gate.

## Non-goals for v1 (explicit backlog)

Plugin system with manifests/registry (surfaces are structured so it can be
retrofitted without rearchitecting), settings GUI, dock, notepad, process
list, polkit agent, screenshot/recording tooling (stays external CLI tools),
sway/river backends (the interface must not preclude them), binary cache
(add when the package does nontrivial work).

## Stack

Pure QML/JS on QuickShell — no compiled companion binary in v1. Matugen
orchestration, brightness, and the niri socket client are all QML via
`Quickshell.Io` (`Process`, `Socket`, `FileView`). The `formalshell` CLI is a
thin installed shell script wrapping `qs ipc call -c <path> …` (plus
completions). A Zig `formalctl` is a post-v1 option if a genuine need appears;
nothing in v1 may depend on one existing.

QuickShell built-ins used (all confirmed present in v0.3.0): Pipewire, Mpris,
Notifications (server), SystemTray, UPower + PowerProfiles, Networking
(NetworkManager), Bluetooth, Pam, Greetd, DesktopEntries, WlSessionLock,
IdleInhibitor, IdleMonitor (ext-idle-notify — drives the screensaver),
IpcHandler, FileView/JsonAdapter. From Qt itself: QtPositioning
(`PositionSource`, geoclue2 D-Bus backend) for location. Hand-rolled:
brightness (`brightnessctl` via Process), the entire niri backend, weather
fetch.

## Architecture

One QuickShell process launched as `qs -p <store-path>/share/formalshell`
(path baked in by the nix wrapper; non-nix users get the same tree under
`~/.config/quickshell/formalshell` or `/etc/xdg/quickshell/formalshell`).

```
shell.qml            ShellRoot + surface wiring (Variants over screens)
greeter.qml          separate entry point for the greetd greeter
Core/                Config, State, Paths, Theme singletons
Compositor/          CompositorService facade + NiriBackend, HyprlandBackend
Services/            Audio, Network, Bluetooth, Battery, Brightness, Media,
                     AppleMusicArt, NotificationService, ThemeEngine,
                     Clipboard, Weather, Location, Idle
Components/          4-state control primitives, sliders, BarIconButton,
                     PanelKeyCatcher (the ONE shared keyboard-nav primitive,
                     Omarchy-style — every popout/menu reuses it)
Surfaces/            Bar/, Menu/, Panels/{audio,network,bluetooth,power,
                     clock,weather}/, Notifications/, Osd/, Lock/,
                     Screensaver/, ImagePicker/, Greeter/
Ipc/                 all IpcHandler targets in one place
```

Services are `pragma Singleton` QML files owning their I/O; Surfaces bind to
service properties and hold no persistent state (DMS's separation pattern,
which is sound). Reload identity: `Scope`-managed `reloadableId`s so
QuickShell's live-reload preserves window state during development.

## Compositor layer

The core deliverable. A **formal `CompositorBackend` contract** — not DMS's
`isNiri`/`isHyprland` boolean if-ladder.

Normalized value shapes (ids are opaque strings on every backend — niri
reserves the right to randomize, Hyprland's are hex addresses):

- `Workspace { id, idx, name, output, isActive, isFocused, isUrgent }`
- `Window { id, title, appId, workspaceId, isFocused, isFloating, isUrgent }`
- `Output { name, logical geometry, scale }`

Required backend surface (the lowest common denominator proven by the niri
26.4 / Hyprland IPC survey): hydrated reactive lists of the three shapes,
focused window/workspace/output, keyboard layout + switch events,
`focusWorkspace(id)`, `focusWindow(id)`, `closeWindow(id)`, `spawn(argv)`,
`powerOffMonitors()/powerOnMonitors()`, `applyThemeFragment()` (compositor
config hot-reload), and a config-reloaded signal. Semantics are
**hydrate-then-diff** (niri's EventStream model is canonical: full state
replay on connect, diffs after; the Hyprland backend synthesizes the same).

Per-compositor extras are feature-flagged extensions, never in the base
contract: niri overview state/toggle, `DoScreenTransition`, rich
`WindowLayout` (scrolling-layout column/row); Hyprland special workspaces,
window groups.

- **NiriBackend** (hand-rolled — QuickShell has no niri module): two `Socket`
  connections to `$NIRI_SOCKET` because `EventStream` monopolizes its
  connection — one streaming events (`SplitParser` + `JSON.parse` per line,
  unknown event keys ignored gracefully per niri's forward-compat mandate),
  one for `Action`/`Output` requests. Bar sits on the `top` layer (required:
  bottom/background layers zoom away during Overview).
- **HyprlandBackend**: `Quickshell.Hyprland` for state (workspaces,
  toplevels, monitors, rawEvent); every dispatch branches on
  `Hyprland.usingLua` — Hyprland ≥0.55's Lua config replaced the classic
  dispatch grammar with no compatibility shim, so both grammars are carried
  indefinitely (`hl.dsp.*({...})` vs legacy strings).
- **Detection**: port DMS's socket-owner walk of `/proc/net/unix` for
  `$WAYLAND_DISPLAY` (env vars leak stale through systemd user environments),
  falling back to liveness-tested env vars (`NIRI_SOCKET`,
  `HYPRLAND_INSTANCE_SIGNATURE`, …).
- **Prototype note**: niri ≥25.08 implements `ext-workspace-v1` +
  `ext-foreign-toplevel-list`; QuickShell's generic `WindowManager`/
  `ToplevelManager` may cover parts of the read path for free. Validate
  empirically during milestone 2 before hand-rolling more than necessary —
  but actions still require the socket regardless.

## Theming

**Colors — matugen-driven** (the user's existing template ecosystem must keep
working unchanged). `ThemeEngine` runs matugen from QML via `Process` on
wallpaper pick / light-dark flip, building a merged config in DMS's proven
order: user `[config]` → shell base templates → the canonical shell
color-export template (renders `theme.json`) → user `[templates]` from
`~/.config/matugen/config.toml` → drop-in `*.toml` fragments from
`~/.config/formalshell/matugen.d/` (the nix-friendly registration point).
Runs are serialized (a queued/superseding single-worker pattern; no
overlapping matugen processes). The shell consumes colors solely by watching
`theme.json` via `FileView { watchChanges: true }` — colors changed is a file
event, not an IPC round-trip. Static schemes (Flexoki pinning et al.) flow
through the same pipeline with the color source overridden, so per-wallpaper
pinning becomes a shell feature, not an external `inotifywait` systemd unit.

**Tokens — Omarchy's vocabulary, adopted near-verbatim:**

- Four-state control model: `normal / hover / focus / selected`, each with
  fill color+alpha and independent border color/width/alpha. `focus` mirrors
  `hover` by default so mouse/keyboard/tab read identically.
- Borders as first-class objects: solid or 45° two-stop gradient, per-side
  widths (CSS shorthand), one shared "active border" token every floating
  surface references so the whole shell tracks the window-border accent.
- One rem-based type scale (`base-size` × fixed multipliers) and one
  `spacing.scale` multiplier — bump one number, the whole shell rescales;
  individual tokens can still be pinned.

**Brutalist defaults**: corner radius 0, no blur (single exception: the lock
screen's frozen wallpaper backdrop), no shadows, 2px borders, monospace
everywhere via the fontconfig `monospace` alias (system mono font change
reflows the entire shell, no restart), Nerd Font glyphs as the icon language
(no SVG icon set).

**Visual reference (added 2026-07-27): https://www.mek.gallery/** — the
owner's canonical look, matugen-recolored. Codified as the "ruled ledger
grid" language in the FormalShell repo's `docs/DESIGN.md` (cells sharing
hairline rules instead of floating cards, selection by fg/bg inversion,
accent as full-bleed cells, uppercase meta labels, dense spacing). That doc
binds all UI surfaces from M4 on; M9 retrofits M1–M3 surfaces. Animation posture: snappy functional micro-feedback
(120–420ms eased color/state transitions, Omarchy's "breathing" opacity pulse
for active-process states); no showy choreography.

**niri border sync is built in**: the shell renders the `layout {}` KDL
fragment and calls `niri msg action load-config-file` itself (replacing the
`niri-border` matugen template + post_hook glue in `dms.nix`).

## Configuration

Two files, strictly split by ownership — the direct lesson from `dms.nix`:

- `~/.config/formalshell/settings.json` — user configuration. The shell
  **only reads and watches** this file (live reload via FileView), and never
  writes it. Home-manager can therefore fully own it declaratively
  (`programs.formalshell.settings`); non-nix users hand-edit the same file.
  Contents: bar layout/widgets, menu customization, theme overrides, optional manual
  weather coordinates (override for the geoclue default), screensaver
  timeout/effect, custom power buttons, Apple Music art opt-in.
- `$XDG_STATE_HOME/formalshell/state.json` — runtime-mutable session state
  the shell owns and rewrites: current wallpaper, light/dark mode, DND,
  clipboard-history pointer. Nix never touches it.

Any future settings UI writes exclusively to a mechanism that composes with
(not overwrites) `settings.json` — decided now so the nix contract can't rot.

## Surfaces (v1)

1. **Bar** — three regions (left/center/right), top-layer. Widgets:
   workspaces, active window, SNI tray (grouped drawer), indicators slot
   (DND, idle-inhibit, recording…), clock, battery, audio, network/BT
   glyphs, now-playing. Custom user modules in settings: `command` type
   (Waybar-JSON-compatible `{text, tooltip, class}`, polled) and `qml` type.
   Panel-open accent dot on the owning widget (Omarchy detail).
2. **Panels** (per-widget popouts, Omarchy's implementations as reference —
   explicitly preferred over DMS's): audio (Pipewire sliders per node),
   network (Wi-Fi list/connect via `Quickshell.Networking`), bluetooth
   (BlueZ), power/battery (profile picker, keyboard-navigable; charging
   pulse animation), clock/calendar, **weather** (Omarchy's weather panel as
   the model; open-meteo fetch). Location comes from a `Location` service:
   **geoclue by default** via QtPositioning's `PositionSource` (the user's
   networks are registered in the Wi-Fi positioning DB), streaming updates so
   an early inaccurate seed never becomes permanent (PR #2914's lesson);
   manual lat/lon in settings overrides it entirely, and is the fallback
   when geoclue stalls (known failure mode: empty wpa_supplicant BSS cache
   on a long-idle association).
3. **Unified menu** — Omarchy's model: one hierarchical JSONC tree (user
   file merged over default, per-key), dotted-id hierarchy, fuzzy tiered
   search, provider nodes (`apps` from DesktopEntries, `clipboard`, emoji),
   `when`/`checked` shell-condition fields with a self-pruning tree,
   `select`/`input` modes as the themed dmenu-replacement API
   (`formalshell menu select "Prompt" a b c`). **Every route is directly
   summonable** (`formalshell menu summon clipboard`) so compositor keybinds
   like super+ñ open a specific surface without traversing the tree. Power
   actions are a submenu here — Lock/Logout/Suspend/Reboot/Shutdown plus
   **custom power buttons** from settings (PR #2916 as a native feature:
   label/icon/command, hold-to-confirm, excluded from any locked context).
4. **Clipboard history** — capture service (`wl-paste --watch` or
   ext-data-control), JSON history capped at 300 entries in state dir,
   surfaced as a menu provider sharing the menu's theme tokens.
5. **Now playing** — bar widget + panel on `Quickshell.Services.Mpris`
   (DMS-informed since Omarchy has no strong media UI), with **Apple Music
   animated album covers** ported from PR #2918: opt-in setting, service
   resolves via iTunes Search + amp-api `editorialVideo` (undocumented API —
   isolated in one service, static-art fallback on every failure), MP4
   cached to `~/.cache/formalshell/applemusic-art/` (atomic rename, misses
   cached, 30-day prune), muted looping video only while playing, zero
   network when disabled.
6. **Notifications** — freedesktop server via QuickShell; Omarchy's
   three-tier model (popup → pending → past with rolling TTL), DND with a
   narrow bypass allowlist (critical urgency from `notify-send` only, not
   chat apps), click → default action or focus-by-app-id fallback, popups
   dodge the bar edge. IPC: dnd toggle, history, clear, dismiss, invoke-last.
7. **OSD** — volume/brightness/media; single bottom-centered card with
   fixed-width icon/value columns so nothing jitters between states.
8. **Lock screen** — `WlSessionLock` + `PamContext` directly (no external
   binary). Blurred current wallpaper backdrop, idle blanking with the
   wall-clock resume guard, fingerprint as a parallel PAM flow when
   enrolled. IPC target `lock`: `lock`, `isLocked`, `status` — the
   `lock-before-sleep` unit changes one command and keeps its exit-0-always
   contract.
9. **Greeter** — separate `greeter.qml` entry point on
   `Quickshell.Services.Greetd`, sharing Core/Theme so it looks like the
   lock screen. Shipped as its own package output + `nixosModules.
   formalshell-greeter` configuring greetd to spawn it.
10. **Screensaver** — Omarchy-style, natively: the `Idle` service
    (`IdleMonitor`, ext-idle-notify) triggers a full-screen overlay-layer
    surface per monitor after the configured timeout, rendering a themed
    terminal-text-effect animation (TTE-style rain/decrypt/matrix drawn in
    QML with the shell's mono font and palette — no spawned terminal
    windows). Any input dismisses it; optionally chains into lock after a
    further timeout. Never activates while an idle inhibitor or active
    media playback (configurable) holds. IPC target `screensaver`:
    `start`, `stop`, `status`.
11. **Image/wallpaper picker** — grid first (Omarchy's skewed carousel is a
    later flourish); selecting a wallpaper triggers ThemeEngine; doubles as
    a generic image-selector IPC surface.

## IPC / CLI

All control flows through QuickShell's native `IpcHandler` targets
(`menu`, `lock`, `osd`, `notifications`, `wallpaper`, `settings`, `media`,
`clipboard`, `screensaver`) — string/int/bool/real/color args, introspectable via
`qs ipc show`. The installed `formalshell` script wraps `qs ipc call` with
the right config path, subcommand sugar (`formalshell menu summon X`,
`formalshell lock`, `formalshell select …`) and shell completions. DMS's Go
wrapper exists mainly for completions; a script buys the same for v1.

## Nix

Flake outputs:

- `packages.<system>.{formalshell,default}` — `makeWrapper` around
  `${quickshell}/bin/qs` with `--add-flags "-p $out/share/formalshell"`,
  plus `qt6.qtpositioning` (and its geoclue2 plugin) on the QML import
  path; self-contained, no dependency on XDG config population. Separate
  `formalshell-greeter` package for the greeter entry point.
- `homeModules.formalshell` — `programs.formalshell.{enable, package,
  settings (nix→JSON, fully owned), systemd.{enable, target (default
  graphical-session.target)}}`.
- `nixosModules.formalshell` — system-side prerequisites:
  `services.geoclue2.enable` (+ agent) for the default location source.
- `nixosModules.formalshell-greeter` — greetd wiring (system-side, can't be
  done from home-manager).
- `devShells.default` — quickshell, qmlls/qmllint wiring (`.qmlls.ini`),
  matugen.
- `checks.<system>.qmllint` — qmllint over the QML tree with explicit
  `-I`/import paths (does not auto-discover under nix); no existing
  QuickShell shell ships this — it is the "first-party nix" differentiator
  and the CI gate.

`quickshell` is a **pinned direct flake input with `nixpkgs.follows`**
(caelestia's pattern; quickshell docs warn Qt/QML ABI mismatch causes
crashes). Bumps are deliberate, tested actions — quickshell is pre-1.0 with
real breaking changes per minor; `Quickshell.hasVersion()` + `//@ if` gates
cover transitions. Matugen comes from nixpkgs.

## Verification

- Per-change: `qmllint` (also the flake check) + launching the shell in a
  **nested niri window** on the g815 — full isolation, instant iteration,
  QuickShell live-reloads on file save.
- Scripted smoke tests through `qs ipc` (open menu, query lock status,
  toggle DND) — QuickShell has no QML test harness, so IPC-driven checks +
  manual QA are the honest baseline.
- Hyprland backend verified in a nested Hyprland session before the
  interface is declared stable.
- Switchover gate: FormalShell daily-driven on the e1504g first; the g815
  stays on DMS until parity is proven.

## Build order

Mirrors Omarchy's own incremental phase history:

1. Repo bootstrap: rename Go repo, create FormalShell, flake + package +
   homeModule skeleton, empty themed bar renders in nested niri.
2. Compositor layer: `CompositorBackend` contract, NiriBackend
   (workspaces + active-window widgets live), then HyprlandBackend to prove
   the interface generalizes.
3. Theme engine: matugen pipeline → `theme.json` → token singletons →
   styled bar; niri border sync.
4. Unified menu: tree + search + `apps` provider + IPC summon routes +
   `select`/`input` dmenu API; power submenu with custom buttons.
5. Notifications + OSD.
6. Clipboard history + panels (audio, network, bluetooth, power, clock,
   weather).
7. Now playing + Apple Music art; lock screen; screensaver (Idle service);
   image picker.
8. Greeter + `nixosModules.formalshell-greeter`.
9. Polish pass (animation/token sweep), e1504g daily-drive trial →
   switchover gate for the g815.

## Risks

- **QuickShell pre-1.0 churn**: real breaking changes per minor release;
  mitigated by the pinned input and deliberate bump cadence.
- **Hyprland dispatch volatility**: the dual-grammar (`usingLua`) shim is
  permanent carry; isolated inside HyprlandBackend.
- **Apple Music amp-api is undocumented** and can break silently; isolated
  in one opt-in service with total fallback to static art.
- **Fractional scaling** is inherited Qt6/qtwayland behavior — not
  controllable at the shell layer; test early on the g815's scaled panel.
- **Scope**: v1 is large. The build order is strictly sequential and each
  milestone leaves a usable partial shell; nothing later may block earlier
  milestones from being daily-drivable in a nested session.
