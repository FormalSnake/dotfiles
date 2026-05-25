{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/config/tmux";
in
{
  xdg.configFile."tmux".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
