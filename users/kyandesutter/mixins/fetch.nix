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
  };
}
