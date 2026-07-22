{ inputs, self, ... }:
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

  # Full niri + DMS desktop. Everything hardware-specific stays off:
  # kyan.nvidia (no dGPU) and kyan.asus — the latter deliberately, even though
  # this is an ASUS chassis, because kyan.asus also gates the g815's dGPU power
  # machinery (modules/nixos/mixins/power.nix). Decouple that gate first if
  # asusd (battery charge limit) turns out to be wanted here.
  kyan.profiles.desktop.enable = true;

  # Syncthing mesh: wallpapers + Zen profile, macbook as hub
  # (modules/nixos/mixins/syncthing.nix; spec 2026-07-22).
  kyan.syncthing.enable = true;

  # This machine is NixOS-only: no Windows dual-boot, no Steam, no Flatpak
  # (enable kyan.flatpak if a Flatpak-only app is ever needed), no NordVPN
  # (kyan.nordvpn — the account login lives on the g815).

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
  nix.settings.builders-use-substitutes = true; # g815 pulls caches itself
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
  # matches the g815's PPD-based stack. thermald lets the 15 W i3-N305 hold
  # turbo longer under sustained load instead of tripping firmware throttling.
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  # The ASUS firmware's UCSI implementation can't answer GET_CABLE_PROPERTY:
  # with a USB-C charger attached, ucsi_acpi logs
  #   ucsi_acpi USBC000:00: GET_CABLE_PROPERTY failed (-22)
  # at KERN_ERR every ~2.6 s — flooding the journal and every TTY console.
  # The driver is purely informational on this machine (PD negotiation happens
  # in the EC; AC/charging state comes from the independent ACPI AC0 supply,
  # battery from ACPI BAT0), so drop it. Costs only /sys/class/typec and the
  # two ucsi-source-psy power_supply entries, which nothing here reads.
  boot.blacklistedKernelModules = [ "ucsi_acpi" ];

  # 8 GB RAM (vs the g815's 32): halve the overflow swapfile to 2× RAM so a
  # spike has real spill room on a small machine (zram in mixins/boot.nix
  # stays the first, RAM-speed tier).
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

      # 15.6" 1080p panel: render at native 1x (without an explicit block niri's
      # DPI heuristic picks a fractional scale). The shared niri mixin leaves
      # eDP-1 unset on iGPU-only hosts, so this is the only definition.
      programs.niri.settings.outputs."eDP-1".scale = 1.0;

      # Suspend after 10 minutes idle (lid close already suspends via logind's
      # default HandleLidSwitch; DMS's own idle timeouts stay 0 — see the seed
      # in mixins/dms.nix). swayidle listens on niri's ext-idle-notify. The
      # lock-before-sleep hook (modules/nixos/mixins/niri.nix) locks on the way
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
      # niri has NO output saturation/CTM/ICC support (maintainer has deferred
      # all color management, github.com/YaLTeR/niri#2458), so true vibrance is
      # impossible here; the one system-wide lever is niri's wlr-gamma-control,
      # and a mild gamma pull (mids down → deeper, richer-looking colors) is
      # the honest approximation. wl-gammarelay-rs holds the gamma ramp and
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
