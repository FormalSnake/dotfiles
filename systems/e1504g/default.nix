{
  inputs,
  self,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # Generated on the machine with `nixos-generate-config` (2026-07-21).
    ./hardware-configuration.nix

    # nixos-hardware: no profile exists for the E1504G chassis, so compose
    # generics (same approach as the g815).
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];

  networking.hostName = "e1504g";

  # ASUS Vivobook E1504G, Intel-only (iGPU). The stock MediaTek Wi-Fi card was
  # swapped for an Intel one (iwlwifi — firmware comes from the global
  # hardware.enableRedistributableFirmware in mixins/graphics.nix).
  hardware.cpu.intel.updateMicrocode = true;

  # FormalShell's power panel samples CPU package watts from RAPL (M20). The
  # kernel ships energy_uj root-only (PLATYPUS side-channel mitigation);
  # relax the package-0 zone to world-readable for the user shell. The shell
  # degrades to charge-rate-only wherever this rule is absent.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", RUN+="${pkgs.coreutils}/bin/chmod 0444 /sys%p/energy_uj"
  '';

  # Full Hyprland desktop. Everything hardware-specific stays off:
  # kyan.nvidia (no dGPU) and kyan.asus — the latter deliberately, even though
  # this is an ASUS chassis, because kyan.asus also gates the g815's dGPU power
  # machinery (modules/nixos/mixins/power.nix). Decouple that gate first if
  # asusd (battery charge limit) turns out to be wanted here.
  kyan.profiles.desktop.enable = true;

  # FormalShell daily-drive trial (the spec's own gate: e1504g first, g815
  # follows). Swaps the session shell, lock-before-sleep hook, and the
  # shell-facing Hyprland binds; DMS stays installed but dormant, and rollback is
  # deleting this one line. M12/M13 closed the launch trade-offs (GOA/EDS
  # calendar after a one-time `XDG_CURRENT_DESKTOP=GNOME gnome-control-center
  # online-accounts` sign-in, emoji picker, shell screenshots). SDDM stays
  # the greeter either way.
  kyan.desktop.shell = "formalshell";

  # Syncthing mesh: wallpapers + Zen profile, macbook as hub
  # (modules/nixos/mixins/syncthing.nix; spec 2026-07-22).
  kyan.syncthing.enable = true;

  # This machine is NixOS-only: no Windows dual-boot, no Steam, no NordVPN
  # (kyan.nordvpn — the account login lives on the g815). Flatpak comes in
  # via the desktop profile (shared base, carries Spotify).

  # Offload builds to the g815 (Core Ultra 9 275HX, 32 GB) — this CPU is far
  # slower and the first local build of the desktop closure took all night.
  # ssh-ng as root using the dedicated /root/.ssh/nix-builder key, whose public
  # half is force-commanded to `nix-daemon --stdio` on the g815
  # (systems/g815/default.nix). Reached via the g815's stable Tailscale IP —
  # same /etc/hosts-over-MagicDNS reasoning as the macbook pin in
  # modules/nixos/mixins/networking.nix, minus the need for a name at all.
  # When the g815 is off/asleep the connection fails and nix falls back to
  # building locally, so this degrades gracefully.
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true; # builders pull caches themselves
  nix.buildMachines =
    let
      g815 = addr: {
        hostName = addr;
        system = "x86_64-linux";
        protocol = "ssh-ng";
        sshUser = "kyandesutter";
        sshKey = "/root/.ssh/nix-builder";
        maxJobs = 8;
        speedFactor = 4;
        supportedFeatures = [
          "big-parallel"
          "kvm"
          "nixos-test"
          "benchmark"
        ];
      };
    in
    [
      (g815 "100.114.32.78") # Tailscale (works away from home)
      (g815 "192.168.86.95") # home-LAN fallback when tailscale is down

      # Second builder for when the g815 is off: the Rosetta Linux VM on the
      # macbook (modules/darwin/mixins/rosetta-builder.nix). The macbook itself
      # is aarch64-darwin and can't build for this host at all — the VM is what
      # answers, so this points at the ssh alias below, not at the Mac.
      # speedFactor 4 vs 3 keeps the g815 preferred whenever it is up.
      #
      # No kvm/nixos-test: x86_64 there is Rosetta on an aarch64 guest, so
      # nested VMs can't run and advertising them would only draw in builds
      # that then fail.
      {
        hostName = "macbook-rosetta";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        sshUser = "builder";
        sshKey = "/root/.ssh/nix-builder";
        maxJobs = 6;
        speedFactor = 3;
        supportedFeatures = [
          "big-parallel"
          "benchmark"
        ];
      }
    ];
  # Pin the g815's host key so root's first builder connection doesn't stall
  # on an unverifiable host.
  programs.ssh.knownHosts.g815 = {
    hostNames = [
      "100.114.32.78"
      "192.168.86.95"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKgCmAa/QcQhtHNoES8iHx0uYAT+Ze+4lNuHuJ2Rb7Ku";
  };
  programs.ssh.knownHosts.macbook = {
    hostNames = [ "100.75.60.102" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGfYr6TMA9v8C93Lgl2qQUAXwb13vu/fZe2HeHpjgD0Q";
  };

  # Route for the macbook builder. The VM's sshd is published on the Mac's
  # loopback only, so the hop has to originate there: `macbook-nixjump` is the
  # authenticated outer connection (its key is restricted on the Mac to exactly
  # this one permitopen), and ProxyJump makes the inner TCP connect happen on
  # the Mac. Port must match `port` in the rosetta-builder mixin.
  #
  # The VM's host key is generated on the Mac and regenerated whenever the VM
  # is recreated, so there is nothing stable to pin. Not checking it costs
  # nothing here: the endpoint is 127.0.0.1 on a host we just authenticated by
  # its pinned key, so reaching it already means the Mac is compromised.
  programs.ssh.extraConfig = ''
    Host macbook-nixjump
      HostName 100.75.60.102
      User kyandesutter
      IdentityFile /root/.ssh/nix-builder
      IdentitiesOnly yes

    Host macbook-rosetta
      HostName 127.0.0.1
      Port 31122
      User builder
      ProxyJump macbook-nixjump
      IdentityFile /root/.ssh/nix-builder
      IdentitiesOnly yes
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
  '';

  # Reachable over the home LAN even when tailscale is down (the shared
  # agenix mixin only opens sshd on tailscale0 via trustedInterfaces).
  services.openssh.openFirewall = true;

  # This machine is administered remotely (Claude on the g815 drives it over
  # SSH, where a sudo password prompt can't be answered). Root is still gated
  # on holding an authorized SSH key or the local login password.
  security.sudo.wheelNeedsPassword = false;

  # PPD instead of TLP (nixos-hardware's common-pc-laptop enables TLP only
  # when PPD is off, so this cleanly displaces it). PPD is what DMS's battery
  # popout speaks, making its profile switcher functional — power-saver maps
  # to EPP `power` plus the firmware's `quiet` platform profile — and it
  # matches the g815's PPD-based stack. No thermald: it exists to hold turbo
  # near the thermal limit, which is the opposite of the quiet-fans policy
  # below (and on engaging it would restore the firmware's absurd RAPL
  # defaults over our caps).
  services.power-profiles-daemon.enable = true;

  # Quiet fans (owner ask, 2026-07-23): this machine only ever runs a browser,
  # a terminal and a few apps, so trade peak CPU for noise. The firmware ships
  # run-flat-out package limits (MSR PL1 200 W; MMIO PL1 15 W / PL2 35 W on a
  # 15 W-class i3-N305) and the EC fan curve — not directly controllable on
  # this chassis, pwm1_enable is auto-only — reacts to the resulting temps, so
  # the fan never spins down. Lower power is the only fan lever: cap RAPL per
  # PPD profile, on BOTH domains (the enforced limit is the lower of MSR and
  # MMIO). Tiers: performance merely audible, balanced near-silent,
  # power-saver minimal. Same PPD-watching shape as power-saver-dim below,
  # but a system service (sysfs writes need root), and wantedBy PPD rather
  # than multi-user.target for the ordering reason documented in
  # modules/nixos/mixins/power.nix.
  systemd.services.power-cap = {
    description = "Per-profile RAPL package power caps (quiet fans)";
    after = [ "power-profiles-daemon.service" ];
    wants = [ "power-profiles-daemon.service" ];
    wantedBy = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 2;
    };
    script =
      let
        gdbus = "${lib.getBin pkgs.glib}/bin/gdbus";
        ppd = "--system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles";
      in
      ''
        apply() {
          case $1 in
            performance) pl1=12 pl2=18 ;;
            balanced)    pl1=8  pl2=14 ;;
            power-saver) pl1=5  pl2=8  ;;
            *) return 0 ;;
          esac
          for d in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
            [ -d "$d" ] || continue
            echo $((pl1 * 1000000)) >"$d/constraint_0_power_limit_uw"
            echo $((pl2 * 1000000)) >"$d/constraint_1_power_limit_uw"
          done
        }

        apply "$(${gdbus} call ${ppd} \
          --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile \
          | ${pkgs.gnused}/bin/sed -nE "s/.*'([a-z-]+)'.*/\1/p")"

        ${gdbus} monitor ${ppd} | while IFS= read -r line; do
          p=$(printf '%s\n' "$line" \
            | ${pkgs.gnused}/bin/sed -nE "s/.*'ActiveProfile': <'([a-z-]+)'>.*/\1/p")
          [ -n "$p" ] && apply "$p"
        done
      '';
  };
  # RAPL limits don't reliably survive suspend; re-apply on the way up.
  powerManagement.resumeCommands = "/run/current-system/systemd/bin/systemctl try-restart power-cap.service";

  # The ASUS firmware's UCSI implementation can't answer GET_CABLE_PROPERTY:
  # with a USB-C charger attached, ucsi_acpi logs
  #   ucsi_acpi USBC000:00: GET_CABLE_PROPERTY failed (-22)
  # at KERN_ERR every ~2.6 s — flooding the journal and every TTY console.
  # The driver is purely informational on this machine (PD negotiation happens
  # in the EC; AC/charging state comes from the independent ACPI AC0 supply,
  # battery from ACPI BAT0), so drop it. Costs only /sys/class/typec and the
  # two ucsi-source-psy power_supply entries, which nothing here reads.
  boot.blacklistedKernelModules = [
    "ucsi_acpi"

    # The Integrated Sensor Hub never starts on this chassis: intel_ish_ipc logs
    #   intel_ish_ipc 0000:00:12.0: Timed out waiting for HW ready
    #   intel_ish_ipc 0000:00:12.0: ISH: hw start failed
    # at every boot and leaves 00:12.0 unbound. No lid/tablet/ambient-light
    # sensor here reads through it, so skip the probe. (This buys log
    # cleanliness only: the device sits in D0 either way, see the note below.)
    "intel_ish_ipc"
  ];

  # No PCI runtime-PM overrides here, deliberately. Measured on the hardware:
  #   - NVMe (02:00.0) is quirked by the platform ("setting simple suspend",
  #     "D3 entry latency set to 10 seconds"), so runtime D3 would never pay off.
  #     APST already parks the drive's own idle states.
  #   - Wi-Fi (01:00.0) is left at power/control=on by iwlwifi itself, and
  #     802.11 power save is already enabled, and overriding the driver here is
  #     how you get idle disconnects.
  #   - The dead ISH device accepts power/control=auto but stays in D0, so it
  #     saves nothing.
  # The usual powertop --auto-tune sweep therefore has nothing left to win.

  # Disable CPU speculative-execution mitigations, matching the g815 (see
  # systems/g815/default.nix): ~5-15% on syscall-heavy work, and this 8 GB
  # Intel machine feels it most. Same SECURITY TRADE-OFF, same verdict —
  # single-user personal laptop, no untrusted code.
  boot.kernelParams = [ "mitigations=off" ];

  # 8 GB RAM: hand zram all of it. Compressed pages only cost what they compress
  # to, and zstd gets ~3.7:1 on this workload (3.4 GB of swapped pages held in
  # 445 MB of RAM), so the 50% default in mixins/boot.nix just fills up and
  # spills the rest onto the swapfile below at NVMe speed instead of RAM speed.
  zramSwap.memoryPercent = 100;

  # 8 GB RAM (vs the g815's 32): halve the overflow swapfile to 2× RAM so a
  # spike has real spill room on a small machine (zram above stays the first,
  # RAM-speed tier).
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # MiB → 16 GiB
      priority = 1;
    }
  ];

  home-manager.users.kyandesutter =
    { pkgs, lib, ... }:
    {
      imports = [
        self.homeModules.kyandesutter
        self.homeModules.kyandesutter-linux
      ];

      # 8 GB: the three chat clients that mixins/autostart.nix pulls in at login
      # hold ~1.06 GB resident between them (measured on this host: equibop
      # 563 MB, beeper 385 MB, bluebubbles 115 MB), which is most of what drives
      # this machine into swap while it does nothing but terminals and a browser.
      # Drop them from the login set. The units themselves stay, so
      # `systemctl --user start beeper` still works when they're actually wanted,
      # and the g815 (32 GB) keeps launching all three automatically.
      systemd.user.services = {
        equibop.Install.WantedBy = lib.mkForce [ ];
        beeper.Install.WantedBy = lib.mkForce [ ];
        bluebubbles.Install.WantedBy = lib.mkForce [ ];
      };

      # Suspend after 10 minutes idle (lid close already suspends via logind's
      # default HandleLidSwitch; DMS's own idle timeouts stay 0 — see the seed
      # in mixins/dms.nix). swayidle listens on Hyprland's ext-idle-notify. The
      # lock-before-sleep hook (modules/nixos/mixins/hyprland.nix) locks on the way
      # down. Deferred while an SSH connection is established: this machine is
      # administered remotely (Claude on the g815), and "no local input for 10
      # minutes" is the NORMAL state of a remote-driven session — suspending
      # then would cut rebuilds mid-flight. swayidle only fires once per idle
      # edge, so the timeout starts a transient wait-loop (suspends the moment
      # the last SSH connection closes) and local activity kills it.
      services.swayidle = {
        enable = true;
        timeouts = [
          {
            timeout = 600;
            command = toString (pkgs.writeShellScript "idle-suspend" ''
              exec systemd-run --user --unit=idle-suspend-pending --collect \
                ${pkgs.writeShellScript "idle-suspend-wait" ''
                  while ${pkgs.iproute2}/bin/ss -Htn state established sport = :22 \
                      | ${pkgs.gnugrep}/bin/grep -q .; do
                    ${pkgs.coreutils}/bin/sleep 60
                  done
                  /run/current-system/sw/bin/systemctl suspend
                ''}
            '');
            resumeCommand = "systemctl --user stop idle-suspend-pending.service";
          }
        ];
      };

      # Give the budget 1080p panel (~45% NTSC, washed-out) a bit more punch.
      # True per-output saturation needs a CTM/ICC path this panel isn't worth
      # building; the system-wide lever is wlr-gamma-control, and a mild gamma
      # pull (mids down → deeper, richer-looking colors) is the honest
      # approximation. wl-gammarelay-rs holds the gamma ramp and
      # exposes it on DBus; Type=dbus makes systemd wait for the name so the
      # ExecStartPost that applies our value can't race it. Its ramp is
      # f(x) = x^gamma (color.rs), so values ABOVE 1.0 darken the mids. Tune:
      #   busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Gamma d 1.15
      # (1.0 = stock; higher = punchier/darker mids). MUTUALLY EXCLUSIVE with
      # DMS night mode — both grab the same gamma protocol; night mode is off
      # on this host, stop this service before enabling it.
      systemd.user.services.panel-gamma = {
        Unit = {
          Description = "Punchier panel gamma via wl-gammarelay-rs";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          Type = "dbus";
          BusName = "rs.wl-gammarelay";
          ExecStart = "${pkgs.wl-gammarelay-rs}/bin/wl-gammarelay-rs run";
          ExecStartPost = "${pkgs.systemd}/bin/busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Gamma d 1.1";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      # Dim the backlight to 40% while PPD's power-saver profile is active
      # (toggled from DMS's battery popout) and restore the previous level on
      # leaving it — the backlight is by far this machine's biggest battery
      # consumer (~10.6 W total draw at 100%). The restore is skipped if
      # brightness was adjusted manually while dimmed, so the service never
      # fights the user.
      systemd.user.services.power-saver-dim = {
        Unit = {
          Description = "Dim backlight while the power-saver profile is active";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          Type = "simple";
          ExecStart =
            let
              brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
              gdbus = "${lib.getBin pkgs.glib}/bin/gdbus";
              ppd = "--system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles";
            in
            pkgs.writeShellScript "power-saver-dim" ''
              dim=40
              state=$XDG_RUNTIME_DIR/power-saver-dim.brightness
              cur() { ${brightnessctl} -m | cut -d, -f4 | tr -d '%'; }

              apply() {
                if [ "$1" = power-saver ]; then
                  [ -e "$state" ] && return
                  now=$(cur)
                  if [ "$now" -gt "$dim" ]; then
                    echo "$now" >"$state"
                    ${brightnessctl} -q set "$dim%"
                  fi
                elif [ -e "$state" ]; then
                  [ "$(cur)" = "$dim" ] && ${brightnessctl} -q set "$(cat "$state")%"
                  rm -f "$state"
                fi
              }

              apply "$(${gdbus} call ${ppd} \
                --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile \
                | sed -nE "s/.*'([a-z-]+)'.*/\1/p")"

              ${gdbus} monitor ${ppd} | while IFS= read -r line; do
                case $line in
                  *"'ActiveProfile': <'power-saver'>"*) apply power-saver ;;
                  *"'ActiveProfile': <'"*"'>"*) apply other ;;
                esac
              done
            '';
          # gdbus monitor exits cleanly if PPD restarts; come back either way.
          Restart = "always";
          RestartSec = 2;
        };
      };
    };

  # Set once at install and never change.
  system.stateVersion = "26.11";
}
