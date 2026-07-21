{ pkgs, ... }:
{
  # areofyl/fetch — terminal fetch tool that renders the distro logo as a
  # spinning 3D object alongside live system info. Now in nixpkgs, so install
  # the package straight from pkgs instead of pinning the upstream flake.
  home.packages = [ pkgs.fetch ];

  # The flake's home-manager module is gone with the input; fetch reads a plain
  # key=value file at ~/.config/fetch/config, so write it directly.
  xdg.configFile."fetch/config".text = ''
    spin=y
  '';
}
