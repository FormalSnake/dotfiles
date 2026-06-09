# ⚠️ PLACEHOLDER — replace with real output on first boot.
#
# This file MUST be regenerated on the actual laptop:
#   sudo nixos-generate-config --root /mnt        # during install
#   # then copy /mnt/etc/nixos/hardware-configuration.nix over this file
#   git -C ~/.config/nix add systems/g815/hardware-configuration.nix
#
# The generator fills in: boot.initrd.availableKernelModules, fileSystems."/"
# and the ESP, swapDevices, and the detected CPU count. The flake will NOT
# evaluate for `.#g815` until this is replaced (fileSystems is required).
#
# Expected for this machine (Arrow Lake-HX + NVMe): kvm-intel kernel module,
# initrd modules roughly: xhci_pci thunderbolt nvme usb_storage sd_mod sdhci_pci.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # TODO: real UUIDs from `nixos-generate-config`.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
}
