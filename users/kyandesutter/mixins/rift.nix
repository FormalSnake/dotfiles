{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/rift";
in
{
  xdg.configFile."rift".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
