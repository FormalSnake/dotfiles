{
  flake.homeModules = {
    # Cross-platform base.
    kyandesutter = {
      imports = [ ./kyandesutter ];
    };
    # Platform overlays, wired per-host.
    kyandesutter-darwin = {
      imports = [ ./kyandesutter/darwin.nix ];
    };
    kyandesutter-linux = {
      imports = [ ./kyandesutter/linux.nix ];
    };
  };
}
