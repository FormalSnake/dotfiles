{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/nvim";
in
{
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
