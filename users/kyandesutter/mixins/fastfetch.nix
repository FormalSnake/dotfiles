{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/fastfetch";
in
{
  xdg.configFile."fastfetch".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
