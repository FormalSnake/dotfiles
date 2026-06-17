{ inputs, ... }:
{
  # areofyl/fetch — terminal fetch tool that renders the distro logo as a
  # spinning 3D object alongside live system info. Not in nixpkgs; installed
  # from the upstream flake's home-manager module (nixpkgs follows ours).
  imports = [ inputs.fetch.homeManagerModules.default ];

  programs.fetch = {
    enable = true;
    spin = "y"; # rotate the logo about the vertical axis
  };
}
