{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/ghostty";
in
{
  xdg.configFile."ghostty".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
