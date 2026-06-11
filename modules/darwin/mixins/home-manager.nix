{ inputs, ... }:
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    backupFileExtension = "before-hm";

    sharedModules = [
      {
        # Avoid building Home Manager's option documentation JSON during
        # activation. With this config, that derivation warns about a store path
        # in the generated options data losing its Nix string context.
        manual.manpages.enable = false;
      }
    ];
  };
}
