{ inputs, ... }:
{
  flake.nixosModules.default = {
    imports = [
      # CachyOS kernel overlay + binary cache + git scx schedulers.
      inputs.chaotic.nixosModules.default
      # Declarative Flatpak (base service in ./mixins/flatpak.nix).
      inputs.nix-flatpak.nixosModules.nix-flatpak
      ../shared
      ./mixins/nix.nix
      ./mixins/users.nix
      ./mixins/home-manager.nix
      ./mixins/locale.nix
      ./mixins/networking.nix
      ./mixins/agenix.nix
      ./mixins/boot.nix
      ./mixins/systemd-tuning.nix
      ./mixins/scx.nix
      ./mixins/graphics.nix
      ./mixins/nvidia.nix
      ./mixins/nvidia-resume-recovery.nix
      ./mixins/audio.nix
      ./mixins/bluetooth.nix
      ./mixins/niri.nix
      ./mixins/gaming.nix
      ./mixins/asus.nix
      ./mixins/power.nix
      ./mixins/phone-integration.nix
      ./mixins/airplay.nix
      ./mixins/flatpak.nix
      ./mixins/sober.nix
      ./mixins/nordvpn.nix
      ./mixins/onepassword.nix
      ./profiles
    ];
  };
}
