# AC-Dock Auto-Relog + Session Restore — Design

Date: 2026-06-20
Host: G815 (hybrid laptop — Intel iGPU drives eDP-1, NVIDIA dGPU drives external ports)
Scope: `users/kyandesutter/mixins/hyprland.nix` (home-manager user config)

## Problem

`AQ_DRM_DEVICES` selects the primary render/allocator GPU and is read **once** at
Hyprland/aquamarine init — there is no runtime GPU-primary switch. Today
`uwsm/env-hyprland` sets it to dGPU-primary only when a dGPU *connector* is
connected. That misses the real goal: the owner uses this as a **gaming laptop on
AC power while traveling**, with no external monitor — games run on the dGPU and
present to the internal panel, and they want the dGPU-primary zero-copy path
there too. On battery, iGPU-primary is wanted so the dGPU can RTD3-sleep and save
power.

Because the GPU choice is a session-start env var, applying it requires a full
session restart (logout → SDDM → login). That restart kills every window. So we
also need to **restore the open windows** afterward — and not just for the
AC-triggered relog, but for any manual relog too.

## Goals

1. On **AC plug-in** (battery → mains), auto-trigger a relog so the session comes
   back dGPU-primary — guarded by a cancelable countdown.
2. `AQ_DRM_DEVICES` is chosen from **AC power state**, not monitor presence.
3. After **any** login (AC-triggered or manual), **restore open windows**:
   relaunch each app and place it on the workspace it was on.
4. **Do not meaningfully impact game performance.**

## Non-goals

- Restoring in-app state (open files, terminal cwd/processes) — impossible across
  a relog; explicitly out of scope.
- Restoring exact pixel geometry of tiled windows — only workspace + floating
  state are restored.
- Auto-relog on AC **unplug** — only plug-in triggers a relog (the owner accepts
  staying dGPU-primary on battery until the next manual relog/reboot).
- Skipping the SDDM password — the relog returns to the login screen and the user
  re-authenticates. This cannot be securely automated and is accepted.

## Key accepted constraint

"Relog" = log out to SDDM, type password, log back in. The session-start env var
cannot be changed any other way. Restore runs on the next Hyprland start.

## Architecture (Approach A: periodic snapshot + restore-on-start)

Five units, all added to `users/kyandesutter/mixins/hyprland.nix`, following the
existing style there (`pkgs.writeShellApplication` scripts + `hl.on(
"hyprland.start")` guarded background launches).

### 1. GPU choice → AC power  (modify `xdg.configFile."uwsm/env-hyprland"`)

Replace the dGPU-connector check with an AC check:

- Resolve dGPU/iGPU card nodes via the existing stable by-path PCI symlinks
  (`/dev/dri/by-path/pci-0000:02:00.0-card`, `pci-0000:00:02.0-card`).
- AC is "on" if any `/sys/class/power_supply/*/type` == `Mains` has `online` == 1.
- On AC → `export AQ_DRM_DEVICES="$dgpu:$igpu"` (dGPU primary). Off AC → leave
  unset (iGPU primary, dGPU can sleep).
- Write a runtime marker `$XDG_RUNTIME_DIR/session-gpu-mode` = `dgpu` | `igpu`
  recording what this session chose, so `dock-watcher` can avoid redundant relogs.

This change alone fixes traveling-on-AC gaming even before any hook fires; the
relog mechanism simply causes `env-hyprland` to be re-evaluated.

### 2. `session-snapshot` — periodic, game-aware saver

A guarded background loop started from `hyprland.start` (pgrep guard, same as the
alttab launcher). Every ~20s:

1. **Game-aware skip:** read `hyprctl -j activewindow`; if `.fullscreen` != 0
   (gaming), `continue` — no `clients` dump, no `/proc` walk. Steady-state cost
   during gaming ≈ zero.
2. Otherwise read `hyprctl -j clients`; for each window capture:
   `class`, `title`, `workspace.id`, `floating`, and the launch command read from
   `/proc/<pid>/cmdline` (NUL-separated → JSON argv array).
3. Write atomically (temp file + rename) to
   `$XDG_STATE_HOME/hypr-session/windows.json`.

Rationale for periodic over event-driven (socket2): simpler, robust, and the
game-aware skip removes the only perf-sensitive case. Event-driven (Approach C)
is a possible future refinement.

### 3. `session-restore` — runs on login

Invoked from `hyprland.start` (after the autostart execs). Reads the snapshot and,
for each window:

- **Skip-list (never restore — autostart owns these, regardless of current open
  state, to avoid the startup race):** classes matching
  `helium`, `beeper`, `bluebubbles`, `spotify`, `steam`, `steam_app_.*`,
  `equibop`, plus shell/helper surfaces `quickshell`, `noctalia`, polkit agent,
  and the empty-class PiP/notification windows.
- **Count-based dedup (idempotent, handles multiples):** group remaining snapshot
  entries by class; for each class, let `open` = count currently in
  `hyprctl clients`; launch only the surplus (`snapshot_count - open`), assigning
  the not-yet-covered target workspaces. Re-running restore is safe; multiple
  terminals on different workspaces are each restored.
- **Launch + place:** reconstruct a shell-quoted command from the argv array
  (`jq @sh`) and run
  `hyprctl dispatch exec "[workspace <N> silent; float <bool>] <cmd>"` so the new
  window lands on its workspace (and floats if it was floating) without stealing
  focus.
- **Stale-path fallback:** if the captured absolute (Nix store) path no longer
  exists, retry with the binary basename resolved on `$PATH`.

Restores **workspace + floating state** only (per non-goals).

### 4. `dock-watcher` — AC detection daemon

Guarded background daemon started from `hyprland.start`. Blocks on
`udevadm monitor --udev --subsystem-match=power_supply`; on each event re-reads AC
online state with a ~15s debounce. On a **battery → AC** transition, and only if
`$XDG_RUNTIME_DIR/session-gpu-mode` == `igpu` (don't relog a session that already
booted dGPU-primary), it invokes `dock-relog`. Event-driven → idle cost is zero.

### 5. `dock-relog` — guarded relog trigger

1. `notify-send` (noctalia): "Docking — relog in 10s to enable dGPU. Cancel with
   Super+Shift+Backspace."
2. Wait up to 10s, polling for a cancel flag file
   (`$XDG_RUNTIME_DIR/dock-relog.cancel`).
3. A new keybind **`SUPER+SHIFT+BackSpace`** → `dock-relog cancel` writes that
   flag to abort.
4. If not canceled: run a fresh `session-snapshot` (one-shot), then `uwsm stop`
   (clean uwsm teardown → SDDM).

A subcommand layout (`dock-relog`, `dock-relog cancel`) keeps it one script.

## Data flow

```
[battery→AC udev event]
        │
   dock-watcher (debounce, mode==igpu guard)
        │
   dock-relog ── notify + 10s cancel window ──(canceled)──▶ abort
        │ (proceed)
   session-snapshot (fresh) ──▶ windows.json
        │
   uwsm stop ──▶ SDDM ──▶ user logs in
        │
   env-hyprland: AC on → AQ_DRM_DEVICES=dGPU:iGPU, marker=dgpu
        │
   hyprland.start: autostart apps + session-restore (relaunch + place) + session-snapshot loop + dock-watcher
```

Manual relog path is identical from `uwsm stop` onward; the periodic snapshot
(refreshed ≤20s ago) is what gets restored.

## Files changed

- `users/kyandesutter/mixins/hyprland.nix`:
  - Modify the `uwsm/env-hyprland` text (AC-based GPU choice + mode marker).
  - Add `writeShellApplication`s: `session-snapshot`, `session-restore`,
    `dock-watcher`, `dock-relog`.
  - Add to `hl.on("hyprland.start")`: guarded launches of `session-snapshot`
    (loop) and `dock-watcher`, plus a one-shot `session-restore`.
  - Add keybind `SUPER+SHIFT+BackSpace` → `dock-relog cancel`.
  - Add `udev`/`upower` runtime deps to the relevant `runtimeInputs`
    (`hyprland` for hyprctl, `jq`, `systemd` for udevadm, `libnotify`,
    `coreutils`).

No system-module (`modules/nixos/mixins/hyprland.nix`) change required:
`upower` is already enabled, sysfs `power_supply` is world-readable, and
`udevadm monitor --udev` works unprivileged.

## Error handling / edge cases

- Snapshot file missing/empty on first ever login → restore is a no-op.
- Stale Nix store path in cmdline → basename-on-PATH fallback (mitigated anyway by
  the 20s refresh keeping paths current).
- Messy Electron/flatpak cmdlines → best-effort relaunch; accepted trade-off of
  the `/proc/cmdline` method.
- Redundant/duplicate udev events → debounce + `mode==igpu` guard.
- Accidental brief AC plug → 10s cancelable countdown.
- Restore re-run (e.g. Hyprland restart-without-logout) → count-based dedup makes
  it idempotent.

## Testing strategy

- `env-hyprland`: shell-lint; manually verify AC-on vs AC-off branch picks the
  right `AQ_DRM_DEVICES` and writes the marker (run the snippet standalone).
- `session-snapshot`: run once on a live session; assert `windows.json` lists the
  open windows with plausible workspaces and argv arrays; verify the fullscreen
  skip by going fullscreen and confirming no new write.
- `session-restore`: with a hand-crafted `windows.json`, confirm apps launch onto
  the right workspaces, the skip-list is honored, and a second run is a no-op.
- `dock-relog`: dry-run with `uwsm stop` stubbed — verify notify, the 10s window,
  and that `dock-relog cancel` aborts.
- `dock-watcher`: stub `dock-relog`, plug/unplug AC, confirm it fires only on
  battery→AC and only when marker==igpu.
- End-to-end: on battery, open some ad-hoc windows, plug AC, let it relog, log in,
  confirm windows return to their workspaces and `AQ_DRM_DEVICES` is dGPU-first
  (`hyprctl getoption` / `cat /proc/<hyprland-pid>/environ`).

Note: the owner (kyandesutter) runs all rebuilds — this config will be staged and
git-added, then handed off for `darwin-rebuild`/`nixos-rebuild`.
