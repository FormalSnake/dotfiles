{ inputs, ... }:
{
  flake.nixosModules.default = {
    imports = [
      # CachyOS kernel overlay + binary cache + git scx schedulers.
      inputs.chaotic.nixosModules.default
      # Declarative Flatpak (Sober / Roblox) — see ./mixins/sober.nix.
      inputs.nix-flatpak.nixosModules.nix-flatpak
      ../shared
      ./mixins/nix.nix
      ./mixins/users.nix
      ./mixins/home-manager.nix
      ./mixins/locale.nix
      ./mixins/networking.nix
      ./mixins/agenix.nix
      ./mixins/boot.nix
      ./mixins/scx.nix
      ./mixins/graphics.nix
      ./mixins/nvidia.nix
      ./mixins/audio.nix
      ./mixins/bluetooth.nix
      ./mixins/hyprland.nix
      ./mixins/gaming.nix
      ./mixins/asus.nix
      ./mixins/power.nix
      ./mixins/phone-integration.nix
      ./mixins/sober.nix
      ./mixins/nordvpn.nix
      ./mixins/onepassword.nix
      ./profiles
    ];
  };
}
