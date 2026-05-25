{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/lynk-browser";
in
{
  xdg.configFile."lynk-browser".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
