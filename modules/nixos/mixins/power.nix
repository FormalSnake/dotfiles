{ config, lib, pkgs, ... }:
let
  # Single source of truth for the power source. Prints exactly one of:
  #   ac        — the barrel charger (up to ~300W): ADP0 online and no USB-C PD
  #               source negotiated.
  #   powerbank — a USB-C / Thunderbolt PD source is online (a ucsi-source-psy-*
  #               entry). The EC reports a power bank as ADP0 online *too*, so the
  #               only signal that tells a ~40-50W power bank apart from the barrel
  #               is a lit UCSI source — the barrel never lights one. A power bank
  #               can't sustain Performance, so it must be treated as battery
  #               (low power) even though it charges.
  #   battery   — nothing plugged.
  # Both the system reconciler (below) and the user session (hyprland.nix) key
  # every power decision off this one classifier.
  powerSource = pkgs.writeShellApplication {
    name = "power-source";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      for f in /sys/class/power_supply/ucsi-source-psy-*/online; do
        [ -e "$f" ] || continue
        if [ "$(cat "$f" 2>/dev/null)" = 1 ]; then echo powerbank; exit 0; fi
      done
      if [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 1)" = 1 ]; then
        echo ac
      else
        echo battery
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
  #        offload-wrapped onto the dGPU), unload the driver stack, remove the GPU
  #        from PCI, then flip the ASUS WMI kill switch (asus-nb-wmi/dgpu_disable →
  #        ACPI _PR3) to cut power. Safe because the desktop is iGPU-primary on
  #        battery (hyprland.nix env-hyprland) so nothing on-screen uses the dGPU.
  #   on:  un-flip the kill switch, rescan PCI, reload the driver, restart Steam.
  # The modprobe -r is retried because a client may take a moment to release. If it
  # never releases we bail and leave the dGPU on rather than wedge anything. Steam
  # lives in the user session, so we reach its unit through the user's systemd via
  # runuser; absent (e.g. pre-login at boot) it's a harmless no-op. modprobe is the
  # NixOS-wrapped one (knows the module tree) via its absolute path.
  dgpuPower = pkgs.writeShellApplication {
    name = "dgpu-power";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux # runuser
      config.systemd.package # systemctl
    ];
    text = ''
      knob=/sys/devices/platform/asus-nb-wmi/dgpu_disable
      dev=0000:02:00.0
      user=kyandesutter
      modprobe=/run/current-system/sw/bin/modprobe

      # No ASUS dGPU kill switch on this host → nothing to do.
      [ -e "$knob" ] || exit 0

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
          systemctl stop nvidia-powerd.service 2>/dev/null || true
          user_systemctl stop steam.service
          ok=
          for _ in 1 2 3 4 5; do
            if "$modprobe" -r nvidia_drm nvidia_uvm nvidia_modeset nvidia 2>/dev/null; then ok=1; break; fi
            sleep 1
          done
          if [ -z "$ok" ]; then
            echo "dgpu-power: nvidia still in use — leaving dGPU powered on" >&2
            exit 1
          fi
          [ -e "/sys/bus/pci/devices/$dev/remove" ] && echo 1 > "/sys/bus/pci/devices/$dev/remove" || true
          echo 1 > "$knob"
          ;;
        on)
          echo 0 > "$knob"
          echo 1 > /sys/bus/pci/rescan
          sleep 1
          "$modprobe" nvidia nvidia_modeset nvidia_uvm nvidia_drm 2>/dev/null || true
          user_systemctl start steam.service
          ;;
        *)
          echo "usage: dgpu-power off|on" >&2; exit 2 ;;
      esac
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
      dgpuPower
      config.services.power-profiles-daemon.package
      config.systemd.package
    ];
    text = ''
      sleep 1.5
      src="$(power-source)"
      printf '%s\n' "$src" > /run/power/state
      if [ "$src" = ac ]; then
        powerprofilesctl set performance 2>/dev/null || powerprofilesctl set balanced || true
        # Bring the dGPU back (reload driver + power on) for offload/gaming, then
        # start nvidia-powerd (Dynamic Boost) — it needs the driver loaded, so it
        # must follow dgpu-power on. RTD3 being broken, the dGPU just idles at D0
        # while on AC, which is fine: battery drain is moot when plugged in.
        dgpu-power on || true
        systemctl start nvidia-powerd.service 2>/dev/null || true
      else
        powerprofilesctl set power-saver 2>/dev/null || powerprofilesctl set balanced || true
        # Hard power-off the dGPU (see dgpu-power above): the only real battery win,
        # since RTD3 can't suspend it. dgpu-power stops nvidia-powerd + Steam first.
        dgpu-power off || true
      fi
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
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${powerReconcile}/bin/power-reconcile";
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
