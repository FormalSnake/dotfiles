{ inputs, ... }:
{
  # areofyl/fetch — terminal fetch tool that renders the distro logo as a
  # spinning 3D object alongside live system info. Installed from the upstream
  # flake's home-manager module: nixpkgs' fetch (2.1.0) is still linux-only,
  # while the flake builds 2.2.0 cross-platform with our nixpkgs. Fold back
  # into pkgs.fetch once nixpkgs catches up.
  imports = [ inputs.areofyl-fetch.homeManagerModules.default ];

  programs.fetch = {
    enable = true;
    spin = "y";
    # Sextant shading samples coverage 2x3 per cell instead of snapping the
    # silhouette to the character grid. No module option for it yet, so it goes
    # in raw. Needs a terminal that draws Symbols for Legacy Computing itself —
    # ghostty does, which is what we run everywhere.
    extraConfig = "shading_mode=sextants\n";
  };
}
