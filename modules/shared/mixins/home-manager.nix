{ inputs, ... }:
{
  # Home Manager wiring shared by both nix-darwin and NixOS. The platform
  # module import lives in the per-platform home-manager.nix mixin.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "before-hm";
  };
}
