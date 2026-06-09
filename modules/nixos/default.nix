{ inputs, ... }:
{
  flake.nixosModules.default = {
    imports = [
      # CachyOS kernel overlay + binary cache + git scx schedulers.
      inputs.chaotic.nixosModules.default
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
      ./mixins/hyprland.nix
      ./mixins/gaming.nix
      ./mixins/asus.nix
      ./profiles
    ];
  };
}
