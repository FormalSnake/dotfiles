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
  # Both the system reconciler (below) and the user session (hyprland.nix) key
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
  # self-suspends, so it idles at D0 (~10W) on battery no matter how little uses
  # it. The only way to actually reclaim that power is to power the chip OFF, which
  # supergfxd's Integrated mode does — but only across a logout, and logout
  # black-screens on this machine. So we do the same teardown LIVE here, no logout:
  #   off: stop the nvidia clients (nvidia-powerd holds an NVML handle; Steam is
  #        offload-wrapped onto the dGPU), wait for every handle on the device to
  #        be released, unload the driver stack, remove the GPU from PCI, then
  #        flip the ASUS WMI kill switch (asus-nb-wmi/dgpu_disable → ACPI _PR3)
  #        to cut power. Safe once the desktop is iGPU-primary (the normal
  #        battery case via hyprland.nix env-hyprland; for a session that booted
  #        dGPU-primary on AC, the AC→battery dock-relog switches it to iGPU
  #        first — the wait-for-free loop below covers that teardown window).
  #   on:  un-flip the kill switch, rescan PCI, reload the driver, restart Steam.
  #   on-quiet: same bring-up as `on` but WITHOUT launching Steam — used on USB-C,
  #        where the dGPU must stay powered for the panel backlight (see below) but
  #        we are not gaming.
  #
  # SAFETY (learned the hard way — 2026-07-03 journal): `modprobe -r nvidia` can
  # DEADLOCK inside the kernel when a module load races the unload (e.g. an
  # offload-wrapped app starting during a login storm modprobes nvidia_uvm while
  # we tear the stack down). The stuck modprobe sits in uninterruptible D-state
  # forever: it can't be killed, every later module op piles up behind the same
  # mutex, and suspend fails from then on ("Device or resource busy" — a D-state
  # task can't be frozen), which is exactly the lid-close-then-freeze symptom.
  # Three guards address this:
  #   1. flock — never run two dGPU transitions concurrently.
  #   2. circuit breaker — if an earlier nvidia modprobe is still running, a
  #      wedge is likely already in progress: do NOT pile on, leave the dGPU be.
  #   3. wait-for-free — don't even start the unload until nothing holds a
  #      /dev/nvidia* or dGPU DRM handle (a busy modprobe -r fails cleanly, but
  #      minimising the load/unload overlap window is what avoids the deadlock).
  # Steam lives in the user session, so we reach its unit through the user's
  # systemd via runuser; absent (e.g. pre-login at boot) it's a harmless no-op.
  # modprobe is the NixOS-wrapped one (knows the module tree) via absolute path.
  dgpuPower = pkgs.writeShellApplication {
    name = "dgpu-power";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux # runuser, flock
      pkgs.psmisc # fuser
      pkgs.procps # pgrep
      config.systemd.package # systemctl
    ];
    text = ''
      knob=/sys/devices/platform/asus-nb-wmi/dgpu_disable
      dev=0000:02:00.0
      user=${config.users.users.kyandesutter.name}
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

      uid="$(id -u "$user" 2>/dev/null || true)"
      user_systemctl() {
        [ -n "$uid" ] && [ -d "/run/user/$uid" ] || return 0
        runuser -u "$user" -- env \
          XDG_RUNTIME_DIR="/run/user/$uid" \
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
          systemctl --user "$@" 2>/dev/null || true
      }

      case "''${1:-}" in
        off)
          # Already off? (knob=1 and driver gone) — nothing to do.
          if [ "$(cat "$knob")" = 1 ] && [ ! -e /sys/module/nvidia ]; then exit 0; fi

          systemctl stop nvidia-powerd.service 2>/dev/null || true
          user_systemctl stop steam.service

          # Guard 3: wait (up to ~60s) for every handle on the dGPU to be
          # released before unloading. Covers the dock-relog session teardown
          # (which releases the dGPU when the compositor exits) that the old
          # fixed 25s systemd-run retry used to guess at.
          free=
          for _ in $(seq 20); do
            if ! fuser -s /dev/nvidia* "/dev/dri/by-path/pci-$dev-card" "/dev/dri/by-path/pci-$dev-render"* 2>/dev/null; then
              free=1; break
            fi
            sleep 3
          done
          if [ -z "$free" ]; then
            echo "dgpu-power: dGPU still in use after 60s — leaving it powered on" >&2
            exit 1
          fi

          ok=
          for _ in 1 2 3; do
            if "$modprobe" -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null; then ok=1; break; fi
            sleep 2
          done
          if [ -z "$ok" ]; then
            echo "dgpu-power: nvidia still in use — leaving dGPU powered on" >&2
            exit 1
          fi
          [ -e "/sys/bus/pci/devices/$dev/remove" ] && echo 1 > "/sys/bus/pci/devices/$dev/remove" || true
          echo 1 > "$knob"
          ;;
        on|on-quiet)
          # Only touch the PCI/module stack when actually off — a no-op `on`
          # (already powered + driver loaded) must not rescan/reload anything.
          if [ "$(cat "$knob")" != 0 ] || [ ! -e /sys/module/nvidia ]; then
            echo 0 > "$knob"
            echo 1 > /sys/bus/pci/rescan
            sleep 1
            "$modprobe" nvidia nvidia_modeset nvidia_uvm nvidia_drm 2>/dev/null || true
          fi
          # `on` is the AC/gaming bring-up and also (re)starts Steam; `on-quiet`
          # only powers the chip + driver (USB-C: keep the backlight alive without
          # launching the gaming stack). steam.service's ExecCondition also gates
          # it on AC, so this start is a no-op on any other source.
          [ "''${1:-}" = on ] && user_systemctl start steam.service
          ;;
        *)
          echo "usage: dgpu-power off|on|on-quiet" >&2; exit 2 ;;
      esac
    '';
  };

  # "Make the dGPU power (and its dependent services) match the current source."
  # Runs as the payload of dgpu-reconcile.service (below) — NEVER inline in
  # power-reconcile, whose udev-triggered restarts would SIGTERM a mid-flight
  # module transition. Re-reads the source each pass and loops until the action
  # taken still matches (a re-plug mid-transition changes the answer; systemd
  # merges `start` jobs on an active unit, so without the loop that late event
  # would be lost).
  dgpuReconcile = pkgs.writeShellApplication {
    name = "dgpu-reconcile";
    runtimeInputs = [ powerSource dgpuPower config.systemd.package ];
    text = ''
      for _ in 1 2 3; do
        src="$(power-source)"
        case "$src" in
          ac)
            # Bring the dGPU back (reload driver + power on) for offload/gaming,
            # then start nvidia-powerd (Dynamic Boost) — it needs the driver
            # loaded, so it must follow dgpu-power on. RTD3 being broken, the
            # dGPU just idles at D0 while on AC, which is fine: battery drain is
            # moot when plugged in.
            dgpu-power on || true
            systemctl start nvidia-powerd.service 2>/dev/null || true
            ;;
          powerbank)
            # Keep the dGPU POWERED on USB-C — its WMI carries the panel
            # backlight, so powering it off would kill brightness control. Drop
            # Dynamic Boost to stay low-power; `on-quiet` brings the chip back if
            # we just arrived from the battery branch, without launching Steam.
            systemctl stop nvidia-powerd.service 2>/dev/null || true
            dgpu-power on-quiet || true
            ;;
          *)
            # Hard power-off (see dgpu-power above): the only real battery win,
            # since RTD3 can't suspend it. dgpu-power stops nvidia-powerd + Steam
            # first and waits for the device to be free (relog teardown window).
            systemctl stop nvidia-powerd.service 2>/dev/null || true
            dgpu-power off || true
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
      #   ac        — performance + dGPU on + Dynamic Boost (the barrel sustains it).
      #   powerbank — balanced + dGPU ON, no Dynamic Boost. USB-C is plugged in, and
      #               the panel backlight (nvidia_wmi_ec_backlight) is wired through
      #               the dGPU's WMI, so the chip MUST stay powered or brightness
      #               control dies (panel drops to a dim hardware default). So we keep
      #               it up and just hold balanced instead of performance.
      #   battery   — power-saver + dGPU OFF. Nothing plugged: stretch the battery,
      #               accepting that the backlight (dGPU-wired) goes to its dim
      #               default while unplugged.
      case "$src" in
        ac)        powerprofilesctl set performance 2>/dev/null || powerprofilesctl set balanced || true ;;
        powerbank) powerprofilesctl set balanced || true ;;
        *)         powerprofilesctl set power-saver 2>/dev/null || powerprofilesctl set balanced || true ;;
      esac
      # The dGPU side (power on/off, nvidia-powerd, Steam) lives in its own
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
    # writes. The bare Hyprland session doesn't pull it in (no desktop manager
    # does), so without it the bar is stuck showing a static "Balanced" it
    # can't change. Coexists with asusd, which keeps Aura/fan/charge-limit
    # duties; PPD owns the platform profile (the kernel asus-wmi interface).
    services.power-profiles-daemon.enable = true;

    # Publish /run/power/state for the user session to subscribe to.
    systemd.tmpfiles.rules = [ "d /run/power 0755 root root -" ];

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
    # session (env-hyprland, power-tune) can call it via /run/current-system.
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
