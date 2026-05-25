{
  flake.darwinModules.default = {
    imports = [
      ../shared
      ./mixins/homebrew.nix
      ./mixins/home-manager.nix
      ./mixins/system-defaults.nix
      ./mixins/dock-pins.nix
      ./mixins/login-items.nix
      ./profiles
    ];
  };
}
