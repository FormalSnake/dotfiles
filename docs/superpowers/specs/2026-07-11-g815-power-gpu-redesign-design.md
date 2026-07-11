# g815 power/GPU/relog redesign — design

Date: 2026-07-11
Status: approved (design), pending implementation plan

## Problem

The g815's power management chases the charger with session relogs and a
dGPU-primary mode that exists only for Linux gaming — which has moved to
Windows. Symptoms:

- Every AC↔battery/USB-C transition forces an automatic relog (15s countdown).
- Booting on battery then plugging in triggers a relog into dGPU-primary that
  can come up broken ("grey Hyprland with a ghost monitor").
- Plugging the charger while asleep leaves HDMI/USB dead after resume (the
  compositor wedges on an nvidia pageflip; input stops being serviced).
- Steam and nvidia-powerd are started/stopped by the power path for a gaming
  workflow that no longer exists on this OS.

## Decisions (user-confirmed)

1. **iGPU-primary always.** dGPU-primary sessions are removed entirely (no
   manual escape hatch). Acceptance criterion: the external HDMI monitor must
   not feel laggy through the cross-GPU copy — verified live before locking in.
2. **Battery + connected external monitor keeps the dGPU powered.** Battery
   powers the dGPU off only when no external monitor is connected (and the
   session doesn't hold it).
3. **No automatic relogs.** Any relog is gated on a persistent notification
   with [Relog now] / [Not now] action buttons (Noctalia daemon); fallback is
   a persistent notification + the Super+Shift+Backspace bind as confirm.
4. **Steam decoupled from the power path.** Stays installed/autostarted, no
   longer follows the charger.
5. **Battery dim-backlight trade-off stays.** dGPU off on battery still means
   the panel backlight falls to its dim hardware default (backlight is wired
   through the dGPU's WMI). Accepted, as today.

## Design

### 1. dGPU power policy — `modules/nixos/mixins/power.nix`

Unchanged: `power-source` classifier (ac / powerbank / battery), the PPD
profile mapping (performance / balanced / power-saver), `/run/power/state`
publication, udev triggers, and the split power-reconcile / dgpu-reconcile
service architecture (restart-safe vs start-only).

`dgpu-reconcile` policy becomes:

- **ac or powerbank** → `dgpu-power on` (driver loaded, chip powered).
  Nothing else: no Steam, no nvidia-powerd.
- **battery** → `dgpu-power off`, **except** when an external monitor is
  connected on the dGPU (kernel connector status,
  `/sys/class/drm/<dgpu-card>-*/status` == `connected`). A session that still
  holds the dGPU (charging-booted) is handled by the existing wait-for-free:
  if nothing frees the device within its window, `dgpu-power off` gives up
  gracefully (logged, non-failing) and the chip stays powered — the consent
  popup is the only path that frees it. Never force-release.

**Convergence at login:** `dgpu-reconcile.service` is additionally started
once at session start by `power-tune`, authorized by a polkit rule scoped to
exactly that unit (start only) for the user. This closes the gap where a
popup-confirmed relog happens long after the battery event: the new session's
`power-tune` kick is what finally powers the dGPU off. Invariant:
dgpu-reconcile runs at boot, on power events, at resume, and at session
start.

`dgpu-power` keeps all three kernel-wedge guards verbatim (flock
serialization, nvidia-modprobe circuit breaker, wait-for-free before unload)
— load-bearing, not renegotiated. It loses the `on`/`on-quiet` split (only
`on`/`off` remain) and all `steam.service` wiring.

`nvidia-powerd` (Dynamic Boost) is disabled outright — it only matters for
gaming loads on the dGPU.

### 2. Session GPU env — `users/kyandesutter/mixins/hyprland.nix` (`env-hyprland`)

One rule: **iGPU primary, always.** Keyed on device presence, not power
source:

- dGPU DRM node exists at login → `AQ_DRM_DEVICES="$igpu:$dgpu"` (iGPU
  renders; dGPU is a secondary output head for HDMI) +
  `AQ_FORCE_LINEAR_BLIT=1` (protects the iGPU→dGPU HDMI blit across
  suspend). Marker `igpu+dgpu`.
- dGPU absent (battery boot) → `AQ_DRM_DEVICES="$igpu"`. Marker `igpu`.

Always-on (no AC branch): `LIBVA_DRIVER_NAME=iHD`, Mesa-only
`__EGL_VENDOR_LIBRARY_FILENAMES`, Intel-only `VK_DRIVER_FILES`/
`VK_ICD_FILENAMES`. Apps that want the dGPU use `nvidiaOffloadEnv`
explicitly.

Deleted: dGPU-primary mode, the AC-keyed VA-API/ICD/GPU branches, and the
"session GPU mode must chase the charger" premise. Plugging the charger into
a battery-booted session powers the dGPU on and restores brightness control
with **no relog and no popup** (backlight needs only the driver, not session
enumeration).

### 3. Consent popup — `power-tune` + `gpu-relog-prompt` (replaces `dock-relog`)

`power-tune` keeps aura repaint on source change and refresh-rate-follows-
profile, and adds DRM connector hotplug (`udevadm monitor
--subsystem-match=drm`) to its event mux (existing: `/run/power/state`
inotify + PPD dbus). Each event re-evaluates the session-fit question. Two
mismatches exist, each raising a **persistent** notification with buttons —
no countdown, no default action:

1. **Monitor wants in:** dGPU powered + external monitor connected + session
   marker `igpu` → "External monitor detected — relog to enable it?"
2. **Battery wants the dGPU freed:** battery + no monitor + session marker
   `igpu+dgpu` → "Relog to power off the dGPU and save battery?" (dismissing
   costs ~10W until the next natural logout).

[Relog now] re-checks the condition, takes a session snapshot, `uwsm stop`s;
session-restore relaunches windows on the next login (existing machinery,
unchanged). Buttons via `notify-send -A` against Noctalia's daemon;
**implementation step 0 tests this** — fallback is persistent notification +
Super+Shift+Backspace repurposed as confirm. One popup outstanding at a
time; a dismissal doesn't re-prompt until conditions change again. The
2-minute anti-loop stamp is deleted (no automatic relog → no loop risk).

**Hot-add experiment (before building popup case 1):** aquamarine watches
udev; if a battery-booted session picks up the dGPU's HDMI head when the
chip powers on mid-session, popup case 1 is unnecessary and is not built.
Hot-*remove* is never attempted (nvidia + open compositor fds = the known
kernel-wedge path).

### 4. Sleep/resume

- **New:** a post-resume oneshot (`After=`/`WantedBy=` the four sleep
  services, same pattern as nvidia-resume-recovery) that restarts
  `power-reconcile.service`, so charger changes made while asleep are
  reconciled at wake. dGPU transitions still flow through dgpu-reconcile's
  start-only, sleep-inhibited, serialized path.
- **Removed by design:** the grey-screen ghost monitor (was the auto-relog
  into dGPU-primary) and eDP-1's dependence on nvidia buffers after resume.
- **Kept:** `nvidia-resume-recovery` as a last-resort safety net (a docked
  HDMI head on the dGPU can still theoretically stall after resume).

### 5. Cleanup

Deleted: `on-quiet`; Steam wiring in `power.nix`; the auto-relog
countdown/cancel/anti-loop machinery; AC-keyed VA-API/ICD/GPU-primary
branches; nvidia-powerd start/stop (service disabled).

Untouched: `game-mode` (manual, PPD-only), monitor layout in `hyprland.lua`,
session snapshot/restore, `lock-before-sleep`, asusd/battery-limit/Aura.

Post-implementation: update the power sections of CLAUDE.md and the memory
bank to the new model.

## Error handling

- All dGPU transitions remain behind the existing three guards; a held or
  wedged device is always left alone (exit 0, log line).
- The popup path re-checks its precondition after user confirmation; a stale
  confirm is a no-op.
- The session env no longer consults `power-source` at all — it keys on DRM
  device presence, which cannot disagree with reality. If the iGPU node is
  somehow unresolvable, `AQ_DRM_DEVICES` is left unset (aquamarine probes),
  matching today's fallback.

## Verification

1. `nix-instantiate --parse` on every changed .nix file.
2. `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'`.
3. Rebuild on g815 (owner answers sudo), then push + macbook pull/rebuild
   (macbook is unaffected functionally — all changes are Linux-gated).
4. Live tests on g815:
   - Plug/unplug AC and USB-C: profile + `/run/power/state` + `dgpu_disable`
     correct; **no relog, no popup** in the no-monitor cases.
   - Battery boot → plug charger: brightness control returns, no relog.
   - Hot-add experiment: does HDMI light up without a relog? (determines
     popup case 1)
   - Popup flows: confirm relogs + windows restore; dismiss does nothing and
     doesn't nag.
   - Battery + monitor connected: dGPU stays powered, monitor stays up.
   - Suspend with charger state changed while asleep: correct state at wake,
     HDMI/USB alive.
   - Subjective HDMI lag check (acceptance gate for iGPU-primary).
