{ inputs, self, ... }:
{
  imports = [
    # PLACEHOLDER until the real one is generated at install — see the file.
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
  # (enable kyan.flatpak if a Flatpak-only app is ever needed).

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

  # Set once at install and never change. Confirm this matches the release
  # actually installed from.
  system.stateVersion = "26.11";
}
