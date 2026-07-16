{ config, lib, pkgs, ... }:
let
  # Single source of truth for the power source. Prints exactly one of:
  #   ac        — the barrel charger (up to ~300W), the only source that can
  #               sustain Performance + the dGPU. ASUS charge_mode reports 1
  #               (barrel) or 3 (barrel + USB-C both plugged).
  #   powerbank — any USB-C PD source: a power bank OR a plain USB-C wall charger.
  #               Two signals, because the EC surfaces them differently: a power
  #               bank lights a ucsi-source-psy-* `online`, while a USB-C charger
  #               often does NOT — it lights ADP0=online with every UCSI source
  #               online=0, making it indistinguishable from the barrel by ADP0
  #               alone. The reliable discriminator is the ASUS EC charge_mode
  #               (asus-nb-wmi): 2 == USB-C PD. None of these can feed Performance,
  #               so they all take the balanced / dGPU-off / no-relog path.
  #   battery   — nothing plugged.
  # Both the system reconciler (below) and the user session (niri.nix) key
  # every power decision off this one classifier.
  powerSource = pkgs.writeShellApplication {
    name = "power-source";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # A power bank lights an online UCSI source; the barrel never does.
      for f in /sys/class/power_supply/ucsi-source-psy-*/online; do
        [ -e "$f" ] || continue
        if [ "$(cat "$f" 2>/dev/null)" = 1 ]; then echo powerbank; exit 0; fi
      done
      # Nothing on ADP0 → running on battery.
      if [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 1)" != 1 ]; then
        echo battery; exit 0
      fi
      # Charging via ADP0. The EC's charge_mode tells the source apart even when a
      # USB-C charger leaves every UCSI source online=0: 2 == USB-C PD (treat like
      # a power bank), 1/3/unknown == barrel (can sustain Performance) → ac.
      if [ "$(cat /sys/devices/platform/asus-nb-wmi/charge_mode 2>/dev/null || echo 1)" = 2 ]; then
        echo powerbank
      else
        echo ac
      fi
    '';
  };

  # Hard dGPU power switch. RTD3/D3cold is broken on this Blackwell RTX 5070 +
  # open-kernel-module 610 (NVIDIA open-gpu-kernel-modules #882): the dGPU never
  # self-suspends, so it idles at D0 (~10W) no matter how little uses it. The
  # only way to actually reclaim that power is to power the chip OFF:
  #   off: wait for every handle on the device to be released, unload the
  #        driver stack, remove the GPU from PCI, then flip the ASUS WMI kill
  #        switch (asus-nb-wmi/dgpu_disable → ACPI _PR3) to cut power. If the
  #        device stays held (a charging-booted session lists it as a secondary
  #        head), give up QUIETLY — the consent popup (gpu-relog-prompt,
  #        users/kyandesutter/mixins/niri.nix) is the only path that frees
  #        it, and the next dgpu-reconcile run (login kick / power event /
  #        resume) retries.
  #   on:  un-flip the kill switch, rescan PCI, reload the driver.
  #
  # SAFETY (learned the hard way — 2026-07-03 journal): `modprobe -r nvidia` can
  # DEADLOCK inside the kernel when a module load races the unload (e.g. an
  # offload-wrapped app starting during a login storm modprobes nvidia_uvm while
  # we tear the stack down). The stuck modprobe sits in uninterruptible D-state
  # forever: it can't be killed, every later module op piles up behind the same
  # mutex, and suspend fails from then on ("Device or resource busy" — a D-state
  # task can't be frozen), which is exactly the lid-close-then-freeze symptom.
  # Five guards address this:
  #   1. flock — never run two dGPU transitions concurrently.
  #   2. circuit breaker — if an earlier nvidia modprobe is still running, a
  #      wedge is likely already in progress: do NOT pile on, leave the dGPU be.
  #   3. udev settle + initstate — udev inserts nvidia_drm/nvidia_modeset via
  #      built-in kmod (no modprobe process, so guard 2 can't see it; observed
  #      taking 3s+ at boot). Flush the udev queue, then require every loaded
  #      nvidia module to be fully initialized (`live`) before unloading —
  #      unloading against an in-flight load IS the deadlock.
  #   4. wait-for-free — don't even start the unload until nothing holds a
  #      /dev/nvidia* or dGPU DRM handle (a busy modprobe -r fails cleanly, but
  #      minimising the load/unload overlap window is what avoids the deadlock).
  #   5. fail SAFE — every bail-out leaves the dGPU fully powered with the whole
  #      stack loaded; never a half-off state, never a blind retry into a wedge.
  # modprobe is the NixOS-wrapped one (knows the module tree) via absolute path.
  dgpuPower = pkgs.writeShellApplication {
    name = "dgpu-power";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux # flock
      pkgs.psmisc # fuser
      pkgs.procps # pgrep
      config.systemd.package # udevadm settle
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
      # Also matches nvidia-modprobe, the setuid helper the nvidia EGL userspace
      # runs on GL init (the load half of the 2026-07-16 boot wedge).
      if pgrep -f 'modprobe.*nvidia|nvidia-modprobe' >/dev/null 2>&1; then
        echo "dgpu-power: an earlier nvidia modprobe is still running (kernel wedge?) — leaving the dGPU alone" >&2
        exit 0
      fi

      case "''${1:-}" in
        off)
          # Already off? (knob=1 and driver gone) — nothing to do.
          if [ "$(cat "$knob")" = 1 ] && [ ! -e /sys/module/nvidia ]; then exit 0; fi

          # Guard 3: no unload while a load may be in flight. udev's kmod
          # builtin loads nvidia_drm invisibly to guard 2, so first drain the
          # udev queue (strict: a busy queue means bail), then require every
          # nvidia module that exists to be past init (`live`, not `coming`).
          if ! udevadm settle --timeout=15; then
            echo "dgpu-power: udev queue still busy — leaving the dGPU alone" >&2
            exit 0
          fi
          for m in /sys/module/nvidia*; do
            [ -e "$m/initstate" ] || continue
            if [ "$(cat "$m/initstate" 2>/dev/null)" != live ]; then
              echo "dgpu-power: ''${m##*/} still initializing — leaving the dGPU alone" >&2
              exit 0
            fi
          done

          # Guard 4: wait (up to ~60s) for every handle on the dGPU to be
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

          # The EC backlight module ties the panel backlight to the dGPU's WMI
          # path; drop it first so nothing can issue a backlight call into a
          # GPU mid-teardown. Refcount-independent of nvidia.ko (verified
          # holders/refcnt=0 live), so a refusal here is unexpected → bail.
          if ! "$modprobe" -r nvidia_wmi_ec_backlight 2>/dev/null; then
            echo "dgpu-power: nvidia_wmi_ec_backlight held — leaving dGPU powered" >&2
            exit 0
          fi

          ok=
          for _ in 1 2 3; do
            if "$modprobe" -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null; then ok=1; break; fi
            sleep 2
          done
          if [ -z "$ok" ]; then
            # Guard 5: fail SAFE — restore the backlight module so the give-up
            # state is fully powered with the whole stack loaded.
            "$modprobe" nvidia_wmi_ec_backlight 2>/dev/null || true
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
            # nvidia_wmi_ec_backlight last: the off path unloaded it, and
            # re-registering /sys/class/backlight/nvidia_0 is what brings
            # brightness control back on re-plug.
            "$modprobe" nvidia nvidia_modeset nvidia_uvm nvidia_drm nvidia_wmi_ec_backlight 2>/dev/null || true
          fi
          ;;
        *)
          echo "usage: dgpu-power off|on" >&2; exit 2 ;;
      esac
    '';
  };

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
  #
  # The battery off is decided ONCE, EARLY: the unit below is ordered
  # Before=display-manager.service, so the boot-time unload runs while nothing
  # can hold — or, worse, concurrently LOAD — the nvidia stack. Kicking it at
  # graphical.target time raced SDDM's greeter (nvidia-drm registered 90ms
  # before the greeter starts its nvidia EGL init) and deadlocked the kernel on
  # three straight boots, 2026-07-16. Later runs (power events, resume, login
  # kick) still take the off path, but by then a live session holds the device
  # and wait-for-free gives up quietly — the consent relog stays the release path.
  dgpuReconcile = pkgs.writeShellApplication {
    name = "dgpu-reconcile";
    runtimeInputs = [ pkgs.coreutils powerSource dgpuPower config.systemd.package ];
    text = ''
      # At boot this runs before the display manager, possibly while udev
      # coldplug is still registering power_supply/WMI devices — settle first
      # so power-source classifies from real state, not a UCSI source or
      # charge_mode that hasn't appeared yet. Lenient (|| true): on a timeout
      # the classifier's defaults err toward `ac` → powered on → safe, and
      # dgpu-power's own strict settle still gates the unload.
      udevadm settle --timeout=15 || true
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

  # System power reconciler — the single automatic owner of the power profile,
  # and the authority that publishes the current power source to the user session
  # via /run/power/state. Triggered by udev on any ADP0 or ucsi-source-psy change
  # (and at boot via the service's wantedBy PPD). PPD is the backend the noctalia
  # bar reads/writes (UPower → net.hadess.PowerProfiles), so this is what makes the
  # shell show the right profile without manual toggling.
  #
  # The 1.5s settle is essential: plugging a power bank lands ADP0=online *before*
  # the USB-C PD contract negotiates, so an immediate read would misclassify it as
  # `ac`. Waiting lets the UCSI source come up (the UCSI udev event also
  # re-triggers this, so it always converges). Because the canonical state is only
  # written post-settle, every downstream consumer can trust it without its own
  # debounce.
  #
  # `performance` can be unavailable when the daemon reports degradation, so we
  # fall back to balanced rather than fail.
  powerReconcile = pkgs.writeShellApplication {
    name = "power-reconcile";
    runtimeInputs = [
      pkgs.coreutils
      powerSource
      config.services.power-profiles-daemon.package
      config.systemd.package
    ];
    text = ''
      sleep 1.5
      src="$(power-source)"
      printf '%s\n' "$src" > /run/power/state
      # Three-way profile policy keyed off the classifier:
      #   ac        — performance + dGPU powered (backlight + HDMI; the barrel
      #               sustains it).
      #   powerbank — balanced + dGPU powered. USB-C is plugged in, and the panel
      #               backlight (nvidia_wmi_ec_backlight) is wired through the
      #               dGPU's WMI, so the chip MUST stay powered or brightness
      #               control dies (panel drops to a dim hardware default).
      #   battery   — power-saver + dGPU OFF (unless a monitor is connected or the
      #               session holds it — see dgpu-reconcile). Stretch the battery,
      #               accepting that the backlight (dGPU-wired) goes to its dim
      #               default while unplugged.
      case "$src" in
        ac)        powerprofilesctl set performance 2>/dev/null || powerprofilesctl set balanced || true ;;
        powerbank) powerprofilesctl set balanced || true ;;
        *)         powerprofilesctl set power-saver 2>/dev/null || powerprofilesctl set balanced || true ;;
      esac
      # The dGPU side (power on/off) lives in its own
      # service so a udev-triggered restart of THIS unit can never SIGTERM a
      # module load/unload mid-flight (interrupted nvidia module transitions are
      # how the kernel wedges — see dgpu-power). `start` (not restart): a running
      # transition is left alone; its converge loop picks up the new source.
      systemctl start --no-block dgpu-reconcile.service || true
    '';
  };
in
{
  config = lib.mkIf config.kyan.asus.enable {
    # power-profiles-daemon: the profile backend the noctalia bar reads and
    # writes. The bare niri session doesn't pull it in (no desktop manager
    # does), so without it the bar is stuck showing a static "Balanced" it
    # can't change. Coexists with asusd, which keeps Aura/fan/charge-limit
    # duties; PPD owns the platform profile (the kernel asus-wmi interface).
    services.power-profiles-daemon.enable = true;

    # Publish /run/power/state for the user session to subscribe to.
    systemd.tmpfiles.rules = [ "d /run/power 0755 root root -" ];

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

    # Drive PPD + publish the power source. Bound to PPD itself (wantedBy
    # power-profiles-daemon), so it runs right after PPD comes up at boot, plus
    # on every ADP0 / ucsi-source-psy change (udev rules below).
    #
    # NOTE: do NOT use `wantedBy = multi-user.target` here. nixpkgs orders PPD
    # `After=multi-user.target` (it belongs to graphical.target), so pinning a
    # unit that is `After=power-profiles-daemon.service` to multi-user.target
    # closes an ordering loop (multi-user → power-reconcile → PPD →
    # multi-user). systemd can't break it and drops the whole transaction,
    # failing sysinit/basic/NetworkManager at switch/boot.
    systemd.services.power-reconcile = {
      description = "Power profile + /run/power/state follow the power source (AC / power bank / battery)";
      after = [ "power-profiles-daemon.service" ];
      wants = [ "power-profiles-daemon.service" ];
      wantedBy = [ "power-profiles-daemon.service" ];

      # Robustness: each power event restarts this unit via `systemctl restart`
      # (udev rules below), and a single plug/unplug fires TWO events (ADP0 +
      # the UCSI source) — plus a human re-plugging a few times stacks more. Each
      # restart SIGTERMs the in-flight instance (mid 1.5s-settle or mid
      # `dgpu-power off`) and starts a fresh one. With systemd's default limiter
      # (5 starts / 10s) that quickly trips `start-limit-hit`, after which systemd
      # REFUSES to run the unit at all — freezing /run/power/state and leaving the
      # dGPU stuck in whatever state it was in. These restarts are external
      # triggers, not a crash loop, so the rate limiter is the wrong safety here:
      # disable it. The reconciler re-reads the source after its settle, so the
      # last event always wins and state converges; an interrupted run is harmless
      # because the next one completes (dgpu-power is written to be re-runnable).
      startLimitIntervalSec = 0;

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${powerReconcile}/bin/power-reconcile";
      };
    };

    # The dGPU transition worker (see dgpuReconcile / dgpu-power above). A
    # separate unit from power-reconcile for two reasons:
    #   • power-reconcile is `systemctl restart`ed by udev on every power event —
    #     restarting SIGTERMs the in-flight run, which is fine for the fast
    #     profile/state work but must NEVER interrupt an nvidia module
    #     load/unload (that's the kernel-wedge path). This unit is only ever
    #     `start`ed, and systemd merges a `start` on an active unit into the
    #     running job — so a transition always runs to completion, and the
    #     converge loop inside re-reads the source to catch events that arrived
    #     mid-run.
    #   • systemd-inhibit holds a sleep + lid-switch inhibitor for the duration,
    #     so a lid close can't fire suspend into the middle of a module
    #     transition (another wedge aggravator) — the suspend simply waits the
    #     few seconds until the transition is done.
    systemd.services.dgpu-reconcile = {
      description = "dGPU power follows the power source (hard off on battery)";
      # Boot: make the dGPU decision ONCE, EARLY — before the display stack
      # exists. nvidia.ko loads at sysinit (modules-load via nvidia_uvm) and
      # nvidia_drm via udev coldplug; SDDM's greeter starts nvidia EGL within
      # ~100ms of nvidia-drm registering, so a battery unload first kicked at
      # graphical.target time (power-reconcile via PPD) raced it and wedged the
      # kernel. Ordered here, the unload runs before any userspace can hold or
      # load nvidia; on a charging boot it's a pure no-op. Later `start`s (power
      # events, resume, login kick) are unaffected — ordering only shapes the
      # boot transaction. No ordering cycle: this unit is only After=basic.target
      # (default deps) and never orders against PPD/multi-user.target, so the
      # loop documented on power-reconcile stays open.
      before = [ "display-manager.service" ];
      wantedBy = [ "display-manager.service" ];
      # External `start`s, not a crash loop — same rationale as power-reconcile.
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.systemd.package}/bin/systemd-inhibit --what=sleep:handle-lid-switch --who=dgpu-reconcile --why='dGPU power transition in progress' --mode=block ${dgpuReconcile}/bin/dgpu-reconcile";
        # Bounded, but generous enough for the worst case: wait-for-free (60s)
        # + module unload + up to three converge passes.
        TimeoutStartSec = 300;
      };
    };

    # power-source is the shared classifier; expose it on PATH so the user
    # session (power-tune) can call it via /run/current-system.
    environment.systemPackages = [ powerSource ];

    # Re-run the reconciler on any power-source change. We watch BOTH the ACPI
    # mains adapter (ADP0 — barrel) and the USB-C PD sources (ucsi-source-psy-*
    # — a power bank), since a power bank lands ADP0=online before its UCSI
    # source negotiates; the second (UCSI) event is what lets the reconciler's
    # post-settle read see the power bank for what it is. The keyboard LEDs are
    # no longer driven from here — the user session owns live AC/battery
    # following (power-tune / aura-repaint) so there is a single keyboard owner.
    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", KERNEL=="ADP0", RUN+="${config.systemd.package}/bin/systemctl --no-block restart power-reconcile.service"
      SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-*", RUN+="${config.systemd.package}/bin/systemctl --no-block restart power-reconcile.service"
    '';
  };
}
