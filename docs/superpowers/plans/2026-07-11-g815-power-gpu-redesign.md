# g815 Power/GPU/Relog Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the g815 session iGPU-primary always, turn the dGPU into a power-managed backlight/HDMI peripheral, and replace every automatic relog with a persistent consent popup.

**Architecture:** System side (`modules/nixos/mixins/power.nix`) keeps the classifier/PPD/udev skeleton but the dGPU follows "on while charging, off on battery unless a monitor is connected or the session holds it". User side (`users/kyandesutter/mixins/hyprland.nix`) drops dGPU-primary sessions entirely; a new `gpu-relog-prompt` shows button-notifications for the only two relog-worthy situations. A post-resume hook reconciles charger changes made during sleep.

**Tech Stack:** NixOS modules, home-manager, `writeShellApplication` bash, systemd units, polkit, libnotify (Noctalia daemon), Hyprland/aquamarine.

Spec: `docs/superpowers/specs/2026-07-11-g815-power-gpu-redesign-design.md`

## Global Constraints

- **Kernel-wedge safety is non-negotiable:** `dgpu-power` keeps flock serialization, the nvidia-modprobe circuit breaker, and wait-for-free before unload, verbatim. dGPU transitions are only ever `systemctl start`ed, never `restart`ed. Never force-release a held device.
- **No hardcoded `/home/...`** in module bodies; user scripts may reference `/run/current-system/sw/bin/...` absolutely (existing convention for `power-source`).
- **`power-source` stays in `environment.systemPackages`** (referenced by absolute path).
- Nix verification per task: `nix-instantiate --parse <file>` then `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'` (do NOT eval `home-manager.users.*` paths — IFD).
- `git add` every new/changed file before any eval/build (flake sees only tracked files).
- Commit style: conventional prefix, short imperative lowercase subject, no co-author lines, no commit descriptions.
- Inside `writeShellApplication` text in .nix files, shell `${var}` must be written `''${var}`.
- All scripts run under `writeShellApplication` (`set -euo pipefail`) — guard non-critical commands with `|| true`.

---

### Task 1: Simplify `dgpu-power` (drop Steam, on-quiet, nvidia-powerd; non-failing held path)

**Files:**
- Modify: `modules/nixos/mixins/power.nix:42-178` (the `dgpuPower` let-binding)

**Interfaces:**
- Consumes: nothing new.
- Produces: `dgpu-power on|off` (the `on-quiet` verb is GONE — Task 2's reconciler must only use `on`/`off`).

- [ ] **Step 1: Rewrite the `dgpuPower` binding**

Replace the whole `dgpuPower = pkgs.writeShellApplication { ... };` binding with the version below. Changes vs current: header comment rewritten (no gaming/Steam/on-quiet story); `runtimeInputs` loses `pkgs.util-linux`'s runuser use (keep `util-linux` — `flock` needs it) and keeps `psmisc`/`procps`; the `user`/`uid`/`user_systemctl` block is deleted; `off` no longer stops `nvidia-powerd`/Steam; the two give-up paths exit `0` (logged, non-failing); `on-quiet` is removed and `on` no longer starts Steam.

```nix
  # Hard dGPU power switch. RTD3/D3cold is broken on this Blackwell RTX 5070 +
  # open-kernel-module 610 (NVIDIA open-gpu-kernel-modules #882): the dGPU never
  # self-suspends, so it idles at D0 (~10W) no matter how little uses it. The
  # only way to actually reclaim that power is to power the chip OFF:
  #   off: wait for every handle on the device to be released, unload the
  #        driver stack, remove the GPU from PCI, then flip the ASUS WMI kill
  #        switch (asus-nb-wmi/dgpu_disable → ACPI _PR3) to cut power. If the
  #        device stays held (a charging-booted session lists it as a secondary
  #        head), give up QUIETLY — the consent popup (gpu-relog-prompt,
  #        users/kyandesutter/mixins/hyprland.nix) is the only path that frees
  #        it, and the next dgpu-reconcile run (login kick / power event /
  #        resume) retries.
  #   on:  un-flip the kill switch, rescan PCI, reload the driver.
  #
  # SAFETY (learned the hard way — 2026-07-03 journal): `modprobe -r nvidia` can
  # DEADLOCK inside the kernel when a module load races the unload. The stuck
  # modprobe sits in uninterruptible D-state forever: it can't be killed, every
  # later module op piles up behind the same mutex, and suspend fails from then
  # on ("Device or resource busy" — a D-state task can't be frozen). Three
  # guards address this:
  #   1. flock — never run two dGPU transitions concurrently.
  #   2. circuit breaker — if an earlier nvidia modprobe is still running, a
  #      wedge is likely already in progress: do NOT pile on, leave the dGPU be.
  #   3. wait-for-free — don't even start the unload until nothing holds a
  #      /dev/nvidia* or dGPU DRM handle.
  # modprobe is the NixOS-wrapped one (knows the module tree) via absolute path.
  dgpuPower = pkgs.writeShellApplication {
    name = "dgpu-power";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux # flock
      pkgs.psmisc # fuser
      pkgs.procps # pgrep
    ];
    text = ''
      knob=/sys/devices/platform/asus-nb-wmi/dgpu_disable
      dev=0000:02:00.0
      modprobe=/run/current-system/sw/bin/modprobe

      # No ASUS dGPU kill switch on this host → nothing to do.
      [ -e "$knob" ] || exit 0

      # Guard 1: serialize every dGPU transition (see SAFETY above). Non-blocking:
      # if another transition is mid-flight, bail — the next power event (or the
      # dgpu-reconcile converge loop) re-runs with the then-current source.
      exec 9>/run/power/dgpu.lock
      if ! flock -n 9; then
        echo "dgpu-power: another dGPU transition is in progress — skipping" >&2
        exit 0
      fi

      # Guard 2: circuit breaker. An nvidia modprobe still running means either a
      # transition we somehow didn't serialize with, or — worse — a kernel-wedged
      # unload in D-state that will never finish. Either way, touching the module
      # stack now only makes it worse. Leave the dGPU in whatever state it is.
      if pgrep -f 'modprobe.*nvidia' >/dev/null 2>&1; then
        echo "dgpu-power: an earlier nvidia modprobe is still running (kernel wedge?) — leaving the dGPU alone" >&2
        exit 0
      fi

      case "''${1:-}" in
        off)
          # Already off? (knob=1 and driver gone) — nothing to do.
          if [ "$(cat "$knob")" = 1 ] && [ ! -e /sys/module/nvidia ]; then exit 0; fi

          # Guard 3: wait (up to ~60s) for every handle on the dGPU to be
          # released before unloading — covers a just-confirmed relog whose
          # session teardown is still releasing the device. A session that
          # keeps holding it (user dismissed the popup) is respected: give up
          # quietly, stay powered.
          free=
          for _ in $(seq 20); do
            if ! fuser -s /dev/nvidia* "/dev/dri/by-path/pci-$dev-card" "/dev/dri/by-path/pci-$dev-render"* 2>/dev/null; then
              free=1; break
            fi
            sleep 3
          done
          if [ -z "$free" ]; then
            echo "dgpu-power: dGPU still in use — leaving it powered (relog popup is the release path)" >&2
            exit 0
          fi

          ok=
          for _ in 1 2 3; do
            if "$modprobe" -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null; then ok=1; break; fi
            sleep 2
          done
          if [ -z "$ok" ]; then
            echo "dgpu-power: nvidia still in use — leaving dGPU powered on" >&2
            exit 0
          fi
          [ -e "/sys/bus/pci/devices/$dev/remove" ] && echo 1 > "/sys/bus/pci/devices/$dev/remove" || true
          echo 1 > "$knob"
          ;;
        on)
          # Only touch the PCI/module stack when actually off — a no-op `on`
          # (already powered + driver loaded) must not rescan/reload anything.
          if [ "$(cat "$knob")" != 0 ] || [ ! -e /sys/module/nvidia ]; then
            echo 0 > "$knob"
            echo 1 > /sys/bus/pci/rescan
            sleep 1
            "$modprobe" nvidia nvidia_modeset nvidia_uvm nvidia_drm 2>/dev/null || true
          fi
          ;;
        *)
          echo "usage: dgpu-power off|on" >&2; exit 2 ;;
      esac
    '';
  };
```

Note: `config.systemd.package` disappears from `runtimeInputs` (no more `systemctl`/`runuser` in this script).

- [ ] **Step 2: Verify parse**

Run: `nix-instantiate --parse modules/nixos/mixins/power.nix >/dev/null`
Expected: no output, exit 0.

- [ ] **Step 3: Commit** (this task compiles standalone only together with Task 2's reconciler change if the old reconciler still calls `on-quiet` — it does. So do NOT commit yet; Tasks 1–3 commit together at the end of Task 3.)

### Task 2: Monitor-aware `dgpu-reconcile` policy

**Files:**
- Modify: `modules/nixos/mixins/power.nix:180-223` (the `dgpuReconcile` let-binding)

**Interfaces:**
- Consumes: `dgpu-power on|off` (Task 1), `power-source` (unchanged).
- Produces: `dgpu-reconcile` behavior relied on by Tasks 3/6: battery + connected dGPU monitor → stays powered; battery + held → `dgpu-power` gives up quietly.

- [ ] **Step 1: Rewrite the `dgpuReconcile` binding**

```nix
  # "Make the dGPU power match the current source." Runs as the payload of
  # dgpu-reconcile.service (below) — NEVER inline in power-reconcile, whose
  # udev-triggered restarts would SIGTERM a mid-flight module transition.
  # Re-reads the source each pass and loops until the action taken still
  # matches (a re-plug mid-transition changes the answer; systemd merges
  # `start` jobs on an active unit, so without the loop that late event would
  # be lost).
  #
  # Policy (docs/superpowers/specs/2026-07-11-g815-power-gpu-redesign-design.md):
  #   charging (ac or powerbank) → powered on. The dGPU exists for the panel
  #       backlight (nvidia_wmi_ec_backlight rides its WMI) and the HDMI port;
  #       nothing renders on it (the session is always iGPU-primary).
  #   battery → powered off (the only real battery win, RTD3 being broken),
  #       EXCEPT while an external monitor is connected on the dGPU — powering
  #       off would kill that output mid-use. A session that still holds the
  #       device (charging-booted, dGPU listed as secondary head) is left
  #       alone by dgpu-power's wait-for-free; the consent popup is the only
  #       release path.
  dgpuReconcile = pkgs.writeShellApplication {
    name = "dgpu-reconcile";
    runtimeInputs = [ pkgs.coreutils powerSource dgpuPower ];
    text = ''
      for _ in 1 2 3; do
        src="$(power-source)"
        case "$src" in
          ac|powerbank)
            dgpu-power on || true
            ;;
          *)
            # Battery: keep the dGPU powered while any of its connectors has a
            # monitor attached (kernel connector status; when the dGPU is
            # already off, the card node is gone and this loop finds nothing).
            card="$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null || true)"
            connected=
            if [ -n "$card" ]; then
              for s in "/sys/class/drm/''${card##*/}"-*/status; do
                [ -e "$s" ] || continue
                if [ "$(cat "$s" 2>/dev/null)" = connected ]; then connected=1; break; fi
              done
            fi
            if [ -n "$connected" ]; then
              echo "dgpu-reconcile: external monitor connected on the dGPU — leaving it powered" >&2
            else
              dgpu-power off || true
            fi
            ;;
        esac
        # Source unchanged since we acted on it → converged.
        [ "$(power-source)" = "$src" ] && break
      done
    '';
  };
```

Note: all `nvidia-powerd` starts/stops are gone (the service itself is removed in Task 4), so `config.systemd.package` leaves `runtimeInputs`.

- [ ] **Step 2: Also update the `powerReconcile` comment block** (`power.nix:249-267`): in the three-way policy comment, replace the `ac`/`powerbank` lines' mentions of "dGPU on + Dynamic Boost" / "no Dynamic Boost" with "dGPU powered (backlight + HDMI)". No code change — `powerReconcile`'s script body stays byte-identical.

- [ ] **Step 3: Verify parse**

Run: `nix-instantiate --parse modules/nixos/mixins/power.nix >/dev/null`
Expected: exit 0.

### Task 3: Polkit rule + post-resume reconcile service

**Files:**
- Modify: `modules/nixos/mixins/power.nix` (inside the existing `config = lib.mkIf config.kyan.asus.enable { ... }` block, after the `systemd.services.dgpu-reconcile` definition)

**Interfaces:**
- Consumes: `dgpu-reconcile.service`, `power-reconcile.service` (existing units).
- Produces: user-startable `dgpu-reconcile.service` (Task 6's `power-tune` runs `systemctl start dgpu-reconcile.service` at session start); `power-resume-reconcile.service` (resume convergence).

- [ ] **Step 1: Add the polkit rule**

Add inside the `mkIf` block (sibling of `services.power-profiles-daemon.enable`):

```nix
    # Let the active local session kick a dGPU reconcile without a password —
    # power-tune runs `systemctl start dgpu-reconcile.service` once per login.
    # This closes the popup-confirmed-relog gap: the battery event that wanted
    # the dGPU off may be long past by the time the user confirms the relog,
    # so the *new* session's kick is what finally powers it off. Start only,
    # exactly this unit.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "dgpu-reconcile.service" &&
            action.lookup("verb") == "start" &&
            subject.local && subject.active && subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
```

- [ ] **Step 2: Add the resume hook**

```nix
    # A charger plugged/unplugged while asleep produces udev events the sleeping
    # system never acted on; re-run the reconciler at wake so profile,
    # /run/power/state and dGPU power match reality the moment the lid opens.
    # Same after/wantedBy pattern as nvidia-resume-recovery.nix. `restart` on
    # power-reconcile is safe (it's the restart-tolerant unit); the dGPU side
    # still flows through dgpu-reconcile's start-only, sleep-inhibited path.
    systemd.services.power-resume-reconcile = {
      description = "Re-run power-reconcile after resume (charger may have changed while asleep)";
      after = [
        "systemd-suspend.service"
        "systemd-hibernate.service"
        "systemd-hybrid-sleep.service"
        "systemd-suspend-then-hibernate.service"
      ];
      wantedBy = [
        "systemd-suspend.service"
        "systemd-hibernate.service"
        "systemd-hybrid-sleep.service"
        "systemd-suspend-then-hibernate.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.systemd.package}/bin/systemctl restart power-reconcile.service";
      };
    };
```

Also update the file-top comment (`power.nix:1-17`) and the `dgpu-reconcile` unit's `description`/comments if they still mention Steam/Dynamic Boost.

- [ ] **Step 3: Verify parse + eval**

```bash
git add modules/nixos/mixins/power.nix
nix-instantiate --parse modules/nixos/mixins/power.nix >/dev/null
nix eval '.#nixosConfigurations.g815.config.system.stateVersion'
```
Expected: parse silent; eval prints `"25.05"` (or whatever the current value is — any successful value string is a pass).

- [ ] **Step 4: Commit Tasks 1–3**

```bash
git add modules/nixos/mixins/power.nix
git commit -m "refactor(power): dgpu follows charging only, monitor-aware battery off, resume reconcile"
```

### Task 4: Disable Dynamic Boost (`nvidia-powerd`)

**Files:**
- Modify: `modules/nixos/mixins/nvidia.nix:37-42`

**Interfaces:**
- Consumes: nothing.
- Produces: no `nvidia-powerd.service` in the system — nothing may reference it (Tasks 1–2 already removed the references).

- [ ] **Step 1: Flip the option**

Replace the `dynamicBoost` comment + line (nvidia.nix:37-42) with:

```nix
    # Dynamic Boost (nvidia-powerd) shifts power budget between CPU and dGPU
    # under combined load — a gaming feature. Gaming lives on Windows now and
    # the session never renders on the dGPU, so keep it off; the power path
    # (modules/nixos/mixins/power.nix) no longer manages the service either.
    dynamicBoost.enable = false;
```

- [ ] **Step 2: Verify**

```bash
git add modules/nixos/mixins/nvidia.nix
nix-instantiate --parse modules/nixos/mixins/nvidia.nix >/dev/null
nix eval '.#nixosConfigurations.g815.config.system.stateVersion'
```
Expected: both succeed.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(nvidia): disable dynamic boost, gaming moved to windows" modules/nixos/mixins/nvidia.nix
```

### Task 5: `env-hyprland` — iGPU primary always

**Files:**
- Modify: `users/kyandesutter/mixins/hyprland.nix` — the comment block at ~725-763 and the whole `xdg.configFile."uwsm/env-hyprland".text` value (~764-831)

**Interfaces:**
- Consumes: DRM by-path nodes.
- Produces: `$XDG_RUNTIME_DIR/session-gpu-mode` containing `igpu` or `igpu+dgpu` (Task 6's prompt reads exactly these strings).

- [ ] **Step 1: Replace the comment block and the env file**

Replace the long "AQ_DRM_DEVICES is a ':'-separated device list…" comment block (the paragraphs between the `# HDMI-A-1…` gaming-history comment and `xdg.configFile."uwsm/env-hyprland"`) with:

```nix
  # The session is ALWAYS iGPU-primary. Gaming lives on Windows; on Linux the
  # dGPU is nothing but a power-managed peripheral for the panel backlight
  # (its WMI) and the HDMI port. AQ_DRM_DEVICES is a ':'-separated device
  # list; the FIRST entry becomes the primary GPU (aquamarine
  # src/backend/drm/DRM.cpp). When the dGPU is powered at login (we were
  # charging) it is listed SECOND — a scanout-only head for the desk monitor,
  # fed by an iGPU→dGPU blit (trivial for desktop work). When it's absent
  # (battery boot) only the iGPU is listed, so nothing in the session ever
  # touches the nvidia stack and the chip can be hard powered off.
  #
  # Keyed on device PRESENCE, not the power source — it cannot disagree with
  # reality. The set is frozen at aquamarine init; the only situations that
  # want a different set mid-session go through the consent popup
  # (gpu-relog-prompt below), never an automatic relog.
  #
  # GPUs are resolved through the stable by-path PCI symlinks (DRM card
  # numbers can reorder across boots).
```

Replace the entire `xdg.configFile."uwsm/env-hyprland".text = ''...'';` value with:

```nix
  xdg.configFile."uwsm/env-hyprland".text = ''
    # Resolve the two GPUs ONCE per login; uwsm sources this before launching
    # Hyprland. iGPU primary always — see the comment in hyprland.nix.
    dgpu=$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null)
    igpu=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card 2>/dev/null)

    mode=igpu
    if [ -n "$igpu" ] && [ -n "$dgpu" ]; then
      export AQ_DRM_DEVICES="$igpu:$dgpu"
      # Cross-GPU scanout must survive suspend: after s2idle the dGPU side can
      # re-export buffers with a tiling modifier the peer can't import
      # (EGL_BAD_MATCH → permanently stuck pageflip). A LINEAR intermediate
      # buffer for the multi-GPU blit is modifier-independent, so the
      # iGPU→dGPU HDMI copy keeps working across resume.
      export AQ_FORCE_LINEAR_BLIT=1
      mode="igpu+dgpu"
    elif [ -n "$igpu" ]; then
      # dGPU powered off (battery boot): name ONLY the iGPU so aquamarine
      # never probes the nvidia card even if it reappears later; gpu-relog-
      # prompt offers a relog if a monitor shows up wanting it.
      export AQ_DRM_DEVICES="$igpu"
    fi
    if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
      printf '%s\n' "$mode" > "$XDG_RUNTIME_DIR/session-gpu-mode" 2>/dev/null || true
    fi

    # VA-API video decode on the iGPU, always — no app should wake the dGPU
    # for video. Offloaded apps (pkgs.nvidiaOffloadEnv) still force nvidia
    # themselves when explicitly asked.
    export LIBVA_DRIVER_NAME=iHD
    # Keep Chromium/Electron (and any other GL/Vulkan client) off the dGPU:
    # their GPU processes enumerate EGL/Vulkan vendors independently and would
    # otherwise open the nvidia render node, pinning it at D0. Mesa-only EGL +
    # Intel-only Vulkan ICD makes them use the iGPU; offloaded apps re-expand
    # the vendor list themselves.
    export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
    export VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json
    export VK_ICD_FILENAMES="$VK_DRIVER_FILES"
  '';
```

- [ ] **Step 2: Verify parse**

Run: `nix-instantiate --parse users/kyandesutter/mixins/hyprland.nix >/dev/null`
Expected: exit 0. (Full eval happens in Task 8; this file is deep in home-manager, whose eval paths trigger IFD — parse only here.)

- [ ] **Step 3: Do NOT commit yet** — `dockRelog` (still defined above) now references a stale model but still parses; Task 6 removes it. Commit lands at the end of Task 6.

### Task 6: `gpu-relog-prompt` + `power-tune` rewrite + keybind

**Files:**
- Modify: `users/kyandesutter/mixins/hyprland.nix` — replace the `dockRelog` binding (~246-337) with `gpuRelogPrompt`; rewrite `powerTune` (~1-101); update the keybind at ~594; update stale comments at ~3-33, ~103-116, ~439, ~526, and the `power-tune` unit description (~833-849).

**Interfaces:**
- Consumes: `session-gpu-mode` marker (`igpu`/`igpu+dgpu`, Task 5), `/run/power/state`, `${sessionSnapshot}/bin/session-snapshot` (existing, unchanged), `systemctl start dgpu-reconcile.service` (polkit rule, Task 3).
- Produces: `gpu-relog-prompt` (no args = evaluate+prompt; `confirm` = keybind fallback), runtime files `gpu-relog.lock`, `gpu-relog.confirm`, `gpu-relog.dismissed`, `gpu-relog.action`.

- [ ] **Step 1: Replace the `dockRelog` binding with `gpuRelogPrompt`**

Delete the entire `dockRelog = pkgs.writeShellApplication { ... };` binding and its lead comment; insert:

```nix
  # Consent-gated relog prompt — the ONLY path to a GPU-topology relog. No
  # countdown, no default action: a persistent notification with [Relog now]/
  # [Not now] buttons (Noctalia's daemon supports actions via notify-send -A;
  # Super+Shift+BackSpace is a belt-and-braces confirm for a daemon that
  # doesn't). Exactly two situations qualify (spec 2026-07-11):
  #   monitor — a monitor is connected on the powered dGPU but this session
  #             booted without the dGPU (marker `igpu`), so it can't light it
  #             up. (If aquamarine hot-adds the card by itself, hyprctl shows
  #             the output and this never fires — self-adapting.)
  #   battery — on battery with no external monitor, but the session still
  #             holds the dGPU (marker `igpu+dgpu`), so it can't power off.
  # A dismissal is remembered per-situation and never re-prompted until the
  # situation changes (the `dismissed` file is cleared whenever evaluate()
  # says `none`). Confirming re-checks the situation, snapshots the windows
  # and `uwsm stop`s; session-restore relaunches them on the next login.
  gpuRelogPrompt = pkgs.writeShellApplication {
    name = "gpu-relog-prompt";
    runtimeInputs = with pkgs; [ libnotify coreutils util-linux jq uwsm hyprland ];
    text = ''
      rt="''${XDG_RUNTIME_DIR:-/tmp}"
      confirm="$rt/gpu-relog.confirm"
      dismissed="$rt/gpu-relog.dismissed"
      outfile="$rt/gpu-relog.action"
      marker="$rt/session-gpu-mode"

      # Keybind fallback: Super+Shift+BackSpace drops the confirm flag.
      if [ "''${1:-}" = confirm ]; then : > "$confirm"; exit 0; fi

      # Which relog (if any) does the current situation want?
      evaluate() {
        cur=igpu
        [ -r "$marker" ] && cur=$(cat "$marker")
        src=battery
        [ -r /run/power/state ] && src=$(cat /run/power/state)
        card="$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card 2>/dev/null || true)"
        kern_conn=
        if [ -n "$card" ]; then
          for s in "/sys/class/drm/''${card##*/}"-*/status; do
            [ -e "$s" ] || continue
            if [ "$(cat "$s" 2>/dev/null)" = connected ]; then kern_conn=1; break; fi
          done
        fi
        # Does the session already drive any external output?
        sess_ext=
        if hyprctl monitors -j 2>/dev/null | jq -e 'map(select(.name != "eDP-1")) | length > 0' >/dev/null 2>&1; then
          sess_ext=1
        fi
        if [ "$cur" = igpu ] && [ -n "$kern_conn" ] && [ -z "$sess_ext" ]; then
          echo monitor
        elif [ "$cur" = "igpu+dgpu" ] && [ "$src" = battery ] && [ -z "$kern_conn" ]; then
          echo battery
        else
          echo none
        fi
      }

      need=$(evaluate)
      if [ "$need" = none ]; then
        rm -f "$dismissed"
        exit 0
      fi
      # Already dismissed for this exact situation → stay quiet.
      [ "$(cat "$dismissed" 2>/dev/null || true)" = "$need" ] && exit 0

      # One prompt at a time.
      exec 9>"$rt/gpu-relog.lock"
      flock -n 9 || exit 0

      case "$need" in
        monitor)
          title="External monitor detected"
          body="This session can't drive the dGPU's outputs. Relog to enable the monitor?" ;;
        *)
          title="On battery"
          body="This session holds the dGPU (~10W). Relog to power it off?" ;;
      esac

      rm -f "$confirm" "$outfile"
      notify-send -t 0 -u critical \
        -A relog="Relog now" -A dismiss="Not now" \
        "$title" "$body (Super+Shift+BackSpace also confirms)" \
        > "$outfile" 2>/dev/null &
      np=$!

      act=dismiss
      while :; do
        if [ -e "$confirm" ]; then act=relog; break; fi
        if ! kill -0 "$np" 2>/dev/null; then
          # Button clicked (stdout has the action) or notification closed.
          act="$(cat "$outfile" 2>/dev/null || true)"
          [ -n "$act" ] || act=dismiss
          break
        fi
        if [ "$(evaluate)" != "$need" ]; then act=stale; break; fi
        sleep 2
      done
      kill "$np" 2>/dev/null || true
      rm -f "$confirm" "$outfile"

      case "$act" in
        relog) ;;
        stale) exit 0 ;;
        *) printf '%s\n' "$need" > "$dismissed"; exit 0 ;;
      esac

      # Re-check right before acting — the situation may have evaporated
      # between click and here.
      [ "$(evaluate)" = "$need" ] || exit 0
      ${sessionSnapshot}/bin/session-snapshot || true
      notify-send -t 2000 "GPU mode" "Relogging…" || true
      uwsm stop
    '';
  };
```

- [ ] **Step 2: Rewrite `powerTune`**

Replace the `powerTune = pkgs.writeShellApplication { ... };` binding (and update its lead comment at lines 3-33 to describe: aura repaint on source change, refresh follows profile, relog prompting via gpu-relog-prompt, dgpu-reconcile login kick):

```nix
  powerTune = pkgs.writeShellApplication {
    name = "power-tune";
    runtimeInputs = with pkgs; [
      hyprland # hyprctl
      power-profiles-daemon # powerprofilesctl
      inotify-tools # inotifywait
      dbus # dbus-monitor
      coreutils
    ];
    text = ''
      source_now() { cat /run/power/state 2>/dev/null || echo battery; }

      profile() {
        powerprofilesctl get 2>/dev/null
      }

      set_refresh() {
        if [ "$1" = "$last_rate" ]; then return 0; fi
        hyprctl eval \
          "hl.monitor({ output = \"eDP-1\", mode = \"2560x1600@$1\", position = \"2560x0\", scale = 1.25 })" \
          >/dev/null 2>&1 || true
        last_rate="$1"
      }

      reconcile() {
        src="$(source_now)"
        if [ "$src" != "$last_src" ]; then
          # Repaint the keyboard for the new source via the shared setter (in the
          # home profile — user services have a limited PATH, so reference it
          # absolutely), using the cached wallpaper accent (fall back to the seed).
          colour="$(cat "$HOME/.cache/noctalia/aura-color" 2>/dev/null || echo b15bf5)"
          ${config.home.profileDirectory}/bin/aura-repaint "$colour" || true
          last_src="$src"
        fi
        case "$(profile)" in
          power-saver) set_refresh 60 ;;
          *)           set_refresh 240 ;;
        esac
        # Consent popup (self-guarding: single instance, remembers dismissals,
        # no-ops when the session already fits the situation). Backgrounded so
        # this loop stays responsive; on a confirmed relog it ends in
        # `uwsm stop`, which tears this unit down with the session.
        ${gpuRelogPrompt}/bin/gpu-relog-prompt &
      }

      # Converge dGPU power for THIS login: a popup-confirmed relog happens
      # long after the battery event that wanted the dGPU off, so the fresh
      # session kicks the (start-only, serialized) system reconciler once.
      # Passwordless via a polkit rule scoped to exactly this unit+verb
      # (modules/nixos/mixins/power.nix).
      /run/current-system/sw/bin/systemctl start dgpu-reconcile.service 2>/dev/null || true

      last_src=""
      last_rate=""
      reconcile
      while read -r line; do
        case "$line" in
          *state*|*PropertiesChanged*|*member=Changed*|*drm*|*DRM*) reconcile ;;
        esac
      done < <( {
        inotifywait -m -q -e close_write,moved_to,create /run/power 2>/dev/null &
        dbus-monitor --system \
          "type='signal',interface='org.freedesktop.DBus.Properties',path='/org/freedesktop/UPower/PowerProfiles'" \
          2>/dev/null &
        # Monitor hotplug on the dGPU (its connectors are invisible to a
        # session that doesn't list it, so Hyprland IPC can't see them).
        /run/current-system/sw/bin/udevadm monitor --udev --subsystem-match=drm 2>/dev/null &
        wait
      } )
    '';
  };
```

- [ ] **Step 3: Update the keybind** at line ~594:

```nix
    hl.bind(mod .. " + SHIFT + BackSpace", hl.dsp.exec_cmd("${gpuRelogPrompt}/bin/gpu-relog-prompt confirm"))
```

- [ ] **Step 4: Sweep stale comments in this file** — the snapshot/restore block comment (~103-116: replace "AC-dock auto-relog" story with "relog machinery is consent-only; session-restore also runs on manual relogs"), hyprland.lua comments at ~439 and ~526 that mention "AC-keyed GPU choice"/"gaming on AC" (reword to "iGPU-primary always; dGPU is a display head while charging"), and the `power-tune` unit `Description` (~839) → `"Refresh rate + keyboard aura + relog consent prompt follow the power source"`.

- [ ] **Step 5: Verify parse, stale-reference scan, commit Tasks 5–6**

```bash
nix-instantiate --parse users/kyandesutter/mixins/hyprland.nix >/dev/null
rg -n "dockRelog|dock-relog|on-quiet|session-gpu-mode" users/ modules/  # expect: only gpu-relog-prompt/env-hyprland hits, no dockRelog
git add users/kyandesutter/mixins/hyprland.nix
git commit -m "feat(hyprland): igpu-primary always, consent-only gpu relog prompt"
```

### Task 7: Decouple Steam from the charger

**Files:**
- Modify: `users/kyandesutter/mixins/autostart.nix:57-70` (the `systemd.user.services.steam` unit)

**Interfaces:** none.

- [ ] **Step 1: Remove the AC gate**

Delete the `ExecCondition` line (autostart.nix:67):

```nix
      ExecCondition = "${pkgs.bash}/bin/bash -c '[ \"$(cat /run/power/state 2>/dev/null || echo ac)\" = ac ]'";
```

Steam becomes a plain always-autostart tray app. If a nearby comment explains the AC gate, delete that too.

- [ ] **Step 2: Verify + commit**

```bash
nix-instantiate --parse users/kyandesutter/mixins/autostart.nix >/dev/null
git add users/kyandesutter/mixins/autostart.nix
git commit -m "refactor(autostart): steam no longer follows the charger"
```

### Task 8: Docs + memory sync

**Files:**
- Modify: `CLAUDE.md` (repo root — the "Power management — DO NOT BREAK" section)
- Modify: memory files `~/.claude/projects/-home-kyandesutter--config-nix/memory/nix-power-and-theming.md` and `MEMORY.md` (index hook text if needed)

**Interfaces:** none.

- [ ] **Step 1: Update CLAUDE.md's power section** — keep the DO-NOT-BREAK framing and the dgpu-power invariants; replace the description of power-tune (now: aura + refresh + consent prompt + login kick; no auto relog) and add: session is always iGPU-primary; dGPU on while charging, off on battery unless a monitor is connected or the session holds it; relogs only ever happen via gpu-relog-prompt consent. Do NOT commit CLAUDE.md if the repo convention excludes it — this repo tracks its CLAUDE.md in git (it's the project instructions file), so committing it IS correct here; only `~/.claude/CLAUDE.md` (global) is off-limits.
- [ ] **Step 2: Update the memory file** with the new model (same content, condensed) and refresh `gaming-moved-to-windows.md` if it mentions the AC-relog/dGPU-primary behavior.
- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update power management model in CLAUDE.md"
```

### Task 9: Full eval + rebuild + host sync

**Files:** none new.

- [ ] **Step 1: Full eval of both hosts**

```bash
nix eval '.#nixosConfigurations.g815.config.system.stateVersion'
nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'
```
Expected: both print a version string. (All changes are Linux-gated; macbook eval proves no cross-platform breakage.)

- [ ] **Step 2: Rebuild g815** — run the repo's rebuild recipe (`just r` or `sudo nixos-rebuild switch --flake .#g815`). This prompts for sudo, which can't be answered non-interactively: if it blocks, STOP and hand the step to the owner (`! just r`).

- [ ] **Step 3: Push + macbook sync** — `git push`, then `ssh macbook 'cd ~/.config/nix && git pull'` and rebuild there (same sudo caveat; hand to owner if auth blocks).

### Task 10: Live verification (owner-in-the-loop)

No files. Run through after the rebuild, on g815:

- [ ] `systemctl status power-reconcile dgpu-reconcile power-resume-reconcile` — all loaded, none failed.
- [ ] Unplug/replug AC (no monitor): `/run/power/state` + `powerprofilesctl get` + `cat /sys/devices/platform/asus-nb-wmi/dgpu_disable` follow (battery→1 after the ~60s grace if session was battery-booted; charging→0). **No relog, no popup** unless the session holds the dGPU on battery — then the battery popup, and ONLY then.
- [ ] Same for a USB-C PD charger (`powerbank` path: balanced profile, dGPU powered).
- [ ] Battery boot → plug charger: brightness keys work again within seconds, no relog, no popup (no monitor connected).
- [ ] **Hot-add experiment:** battery boot → plug charger + HDMI monitor. Watch `hyprctl monitors -j`: if the HDMI output appears by itself, aquamarine hot-adds — note it (the monitor popup will simply never fire). If not, the monitor popup must appear; confirm → relog → monitor lights up; windows restored.
- [ ] Popup dismissal: dismiss it, verify no re-prompt until the situation actually changes.
- [ ] Battery + monitor connected: dGPU stays powered, monitor stays up, no popup.
- [ ] Suspend, change charger state while asleep, resume: state correct at wake, HDMI/USB alive, no grey session.
- [ ] Desk-monitor feel test (acceptance gate): normal work on HDMI via the iGPU→dGPU blit — must not feel laggy. If it does, escalate back to design (Approach 2 escape hatch).

## Self-review notes

- Spec coverage: §1→Tasks 1–3, §2→Task 5, §3→Task 6, §4→Task 3, §5(cleanup)→Tasks 4/6/7, docs→Task 8, verification→Tasks 9–10. The hot-add experiment is folded into Task 10 (the `monitor` popup condition is self-adapting via the `hyprctl monitors` check, so no conditional build is needed).
- Type consistency: marker strings `igpu`/`igpu+dgpu` (Tasks 5, 6); `dgpu-power on|off` only (Tasks 1, 2); unit names `dgpu-reconcile.service` (Tasks 2, 3, 6), `power-reconcile.service` (Task 3).
- `sessionSnapshot` and `session-restore` are pre-existing bindings in hyprland.nix and are unchanged; `gpuRelogPrompt` references `${sessionSnapshot}` exactly as `dockRelog` did.
