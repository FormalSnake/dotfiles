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

  # Less RAM and a smaller SSD than the 32 GB g815: halve the overflow
  # swapfile (zram in mixins/boot.nix stays the first tier). Revisit once the
  # machine's actual RAM is known.
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024; # MiB → 16 GiB
      priority = 1;
    }
  ];

  home-manager.users.kyandesutter = {
    imports = [
      self.homeModules.kyandesutter
      self.homeModules.kyandesutter-linux
    ];
  };

  # Set once at install and never change.
  system.stateVersion = "26.11";
}
