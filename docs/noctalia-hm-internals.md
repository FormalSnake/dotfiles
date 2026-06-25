# Noctalia home-manager module — internals & IPC reference

Notes on how the upstream `noctalia` flake input's home-manager module
(`programs.noctalia`) actually behaves on disk, plus the runtime IPC surface.
Captured so we don't have to re-read the input source every time. The module
lives at `nix/home-module.nix` inside the `noctalia` flake input (find the
current source with `nix eval --raw .#inputs.noctalia 2>/dev/null` or via
`flake.lock`'s `noctalia` rev). Our wiring is in
`users/kyandesutter/mixins/noctalia.nix`.

## Where config & state live (THE important part)

| File | Owner | Survives `home-manager switch`? |
|------|-------|---------------------------------|
| `~/.config/noctalia/config.toml` | **home-manager** — a read-only symlink into the nix store, generated from `programs.noctalia.settings` | **No — overwritten every switch.** This is the declarative base. |
| `~/.local/state/noctalia/settings.toml` | **Noctalia runtime** — written by the Settings UI | **Yes — never touched by HM.** Runtime overrides layer on top of `config.toml`. |
| `~/.local/state/noctalia/state.toml` | Noctalia runtime | Yes. Holds `[calendar_credentials]`: per-account `<id>_refresh_token`, `<id>_access_token`, `<id>_access_expiry`. |
| `~/.cache/noctalia/...` | Noctalia runtime | Yes (it's a cache). Calendar event cache at `~/.cache/noctalia/calendar/events.json`. |

**Consequences:**
- **Google Calendar accounts logged in via the Settings UI persist across
  rebuilds** — their OAuth tokens live in `state.toml`, which HM never writes.
- Anything you change in Noctalia's Settings UI persists (it goes to
  `settings.toml`), and *shadows* the declarative `config.toml` value. So if a
  setting looks "stuck" after editing the nix config, check whether a runtime
  override in `settings.toml` is winning.
- `config.toml` is validated at build time (`noctalia config validate`), so an
  unknown/misspelled key in `programs.noctalia.settings` fails the build.

## Settings schema — sections (from upstream `example.toml`)

`[shell]` (+ `.privacy` `.animation` `.shadow` `.panel` `.mpris`), `[wallpaper]`
(+ `.default` `.automation`), `[theme]` (+ `.templates`), `[backdrop]`,
`[notification]`, `[osd]` (+ `.kinds` — per-event OSD toggles: volume,
brightness, wifi, bt…), `[lockscreen]`, `[system.monitor]`, `[weather]`,
`[audio]`, `[brightness]`, `[nightlight]`, `[location]`, `[idle]`, `[keybinds]`,
`[bar.main]`, `[dock]`, `[desktop_widgets]`, `[control_center]`, `[hooks]`,
`[widget.*]`.

`[calendar]` does **not** exist in `example.toml` — calendar accounts are managed
entirely through the Settings UI → `state.toml`/`settings.toml`.

### `[brightness]` (DDC/CI for external monitors)

```toml
[brightness]
enable_ddcutil   = false   # set true to drive external monitors over DDC/CI
# ignore_mmids   = []      # monitor IDs to skip (see `ddcutil --verbose detect`)
# minimum_brightness = 0.0 # floor, float 0.0–1.0

# Optional per-monitor backend override:
# [brightness.monitor.eDP-1]
# backend = "backlight"    # "auto" | "none" | "backlight" | "ddcutil"
# [brightness.monitor.HDMI-A-1]
# backend = "ddcutil"
```

Requires the i2c stack (already wired on g815: `hardware.i2c.enable`, user in the
`i2c` group, `ddcutil` installed — see `modules/nixos/mixins/hyprland.nix` and
`modules/nixos/mixins/users.nix`).

## Runtime IPC — `noctalia msg <command>`

`noctalia msg --help` lists everything; the load-bearing ones for keybinds:

| Command | Notes |
|---------|-------|
| `brightness-up [current\|*\|all\|<connector>] [step]` | **Defaults to the monitor the cursor is on.** Uses the backlight backend for the internal panel and ddcutil for externals (when `enable_ddcutil`). Shows the brightness OSD. |
| `brightness-down [...] [step]` | As above. |
| `brightness-set <value>` / `brightness-set <sel> <value>` | Absolute set. |
| `brightness-osd <value>` | Show OSD without changing brightness. |
| `media <next\|previous\|toggle\|stop>` | **Controls the *active* MPRIS player Noctalia tracks** (the one shown in its media widget) — not whatever `playerctl` picks first. Fixes "media keys hit YouTube instead of Spotify". |
| `volume-up/-down [step]`, `volume-set <v>`, `volume-mute` | Speaker, with OSD. `mic-mute`, `mic-volume-*` for the mic. |
| `nightlight-toggle / -enable / -disable / -force-toggle` | Color-temperature night light (config under `[nightlight]`). |
| `caffeine-toggle` | Idle inhibitor. |
| `dpms-on / -off` | Used by our `[idle]` screen-off hooks. |
| `theme-mode-toggle / -set <dark\|light\|auto>` | Used by SUPER+SHIFT+T. |
| `panel-toggle <id> [context]` | e.g. `control-center audio`, `launcher /emo`. |
| `screenshot-fullscreen [pick\|monitor\|all]`, `screenshot-region` | Used by Print / SUPER+SHIFT+S. |
| `status` | Prints current state as JSON (brightness/volume/etc.) — useful for scripting/snapping. |
| `session <lock\|suspend\|lock-and-suspend\|logout\|reboot\|shutdown>` | Used by SUPER+SHIFT+Escape. |

`noctalia msg <cmd>` requires the running user instance (the systemd user service
bound to the graphical-session target).

## Bar widgets & per-widget config

The bar's `[bar.main]` `start` / `center` / `end` are arrays of **widget id
strings**. Built-in ids: `launcher`, `wallpaper`, `workspaces`, `clock`, `media`,
`tray`, `notifications`, `clipboard`, `network`, `bluetooth`, `volume`,
`brightness`, `battery`, `control-center`, `session`, `settings`, `spacer`,
`sysmon`, … Overriding a list replaces it wholesale — repeat the defaults you want
to keep.

Per-instance config lives in a top-level `[widget.<id>]` table. If `<id>` is a
built-in name the `type` is implied (`[widget.clock]`); otherwise set `type`
explicitly, which also lets you define **multiple instances of one type** under
distinct ids:

```toml
[widget.gpu_temp]            # arbitrary id, referenced from bar start/center/end
type = "sysmon"
stat = "gpu_temp"
display = "text"             # "text" | "gauge" (default gauge)
```

`sysmon` `stat` values: `cpu_usage`, `cpu_temp`, `gpu_temp`, `gpu_usage`,
`gpu_vram`, `ram_used`, `ram_pct`, `swap_pct`, `disk_pct`, `net_rx`, `net_tx`.
Other `[widget.<id>]` keys: `display` (`gauge`|`text`|`graph`), `show_label`
(value text in gauge mode), `glyph` (icon override — each stat has a default icon
like `cpu-usage`/`gpu-temperature`), `path` (for `disk_pct`), `interface` (net).
Sampling/poll intervals + alert thresholds are under `[system.monitor]` (on by
default).

**NVIDIA GPU stats need NVML.** noctalia reads `gpu_temp`/`gpu_usage`/`gpu_vram`
via NVML (`libnvidia-ml.so.1`), which it dlopens by soname (sysfs `gpu_busy_percent`
/`mem_info_vram_*` are amdgpu-only). On NixOS that lib is in `/run/opengl-driver/lib`,
off the loader path, so the service logs `NVML unavailable` and the widgets read
`--`. Fix: give the noctalia user service `Environment = [
"LD_LIBRARY_PATH=/run/opengl-driver/lib" ]` (that dir has only vendor impls, no
glvnd dispatch libs, so it won't shadow noctalia's GL). PRIME-offload caveat: NVML
polling keeps the dGPU awake (it's on anyway while the external monitor is docked).
Diagnose via `~/.cache/noctalia/noctalia.log` (`[sysmon] detected GPU … source:`).

**Compacting a cluster:** `bar.main.capsule_group = [{ id = "..."; members = [ … ];
}]` wraps listed widgets in one pill **without** enabling bar-wide `capsule` mode.
Other group keys: `fill`, `foreground`, `border`, `padding`, `radius`, `opacity`.
Members must be contiguous in the `start`/`center`/`end` list for the pill to look
right.

## Hooks (`[hooks]`) — events & env vars

Each key is a shell command (string) or list of commands, run on the event:
`started`, `wallpaper_changed`, `colors_changed`, `theme_mode_changed`
(`$NOCTALIA_THEME_MODE`), `session_locked`/`unlocked`, `logging_out`,
`rebooting`/`shutting_down`, `wifi_enabled`/`disabled`,
`bluetooth_enabled`/`disabled`, `battery_state_changed`
(`$NOCTALIA_BATTERY_STATE`), `power_profile_changed` (`$NOCTALIA_POWER_PROFILE`),
and `battery_under_threshold` (`$NOCTALIA_BATTERY_PERCENT`) — the last requires
`battery_low_percent_threshold > 0`.

Gotchas when set declaratively from Nix: the noctalia **user** service has a
limited PATH, so pin binaries by store path (e.g. `${pkgs.libnotify}/bin/notify-send`);
and escape the shell vars as `\${NOCTALIA_…}` so Nix doesn't try to interpolate
them. Notifications surface through noctalia's own daemon.
