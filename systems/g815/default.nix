{ inputs, self, ... }:
{
  imports = [
    # Generated on first boot with `nixos-generate-config` — placeholder for now.
    ./hardware-configuration.nix

    # nixos-hardware: no profile exists for the G815 chassis, so compose generics.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    # common-gpu-nvidia == PRIME offload (despite the bare name).
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia

    # MT7925 Wi-Fi/BT fixes (ASPM, powersave, resume). Not a flake attr → by path.
    # If wpa_supplicant misbehaves, also import "${inputs.nixos-hardware}/common/wifi/mediatek/mt7925/iwd.nix".
    "${inputs.nixos-hardware}/common/wifi/mediatek/mt7925"
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "g815";

  # Intel Core Ultra 9 275HX (Arrow Lake-HX).
  hardware.cpu.intel.updateMicrocode = true;

  # PRIME offload bus IDs — the iGPU is usually PCI:0:2:0; the dGPU varies.
  # TODO (first boot): `lspci -D | grep -E "VGA|3D"`, convert the hex
  # domain:bus:dev.fn to NixOS's decimal PCI:bus:dev:fn, and replace these.
  hardware.nvidia.prime = {
    intelBusId = "PCI:0:2:0"; # TODO verify
    nvidiaBusId = "PCI:1:0:0"; # TODO verify
  };

  # Profiles (enable the desktop + gaming stacks for this host).
  kyan.profiles.desktop.enable = true;
  kyan.profiles.gaming.enable = true;

  home-manager.users.kyandesutter = {
    imports = [
      self.homeModules.kyandesutter
      self.homeModules.kyandesutter-linux
    ];
  };

  # Set once at install and never change (matches the macbook's pattern).
  system.stateVersion = "25.11";
}
