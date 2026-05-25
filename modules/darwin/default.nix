{
  flake.darwinModules.default = {
    imports = [
      ../shared
      ./mixins/homebrew.nix
      ./mixins/home-manager.nix
      ./mixins/system-defaults.nix
      ./profiles
    ];
  };
}
