{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/aerospace";
in
{
  xdg.configFile."aerospace".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
