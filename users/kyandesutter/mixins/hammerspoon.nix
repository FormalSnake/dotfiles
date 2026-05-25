{ config, ... }:
let
  src = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/hammerspoon";
in
{
  home.file.".hammerspoon".source =
    config.lib.file.mkOutOfStoreSymlink src;
}
