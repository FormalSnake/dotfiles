{
  flake.darwinModules.default = {
    imports = [
      ../shared
      ./mixins/homebrew.nix
      ./mixins/system-defaults.nix
      ./profiles
    ];
  };
}
