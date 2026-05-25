{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/karabiner";
in
{
  xdg.configFile."karabiner".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
