{ config, ... }:
let
  dir = "${config.home.homeDirectory}/.config/nix/users/kyandesutter/omniwm";
in
{
  # OmniWM live-reloads settings.toml and rewrites it from its own settings UI;
  # Karabiner rewrites karabiner.json from its GUI. Both are out-of-store
  # symlinks to the git-tracked source so in-app edits persist and stay tracked
  # without a rebuild. OmniWM is launched at login via login-items.nix.
  xdg.configFile."omniwm/settings.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dir}/settings.toml";
  xdg.configFile."karabiner/karabiner.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dir}/karabiner.json";
}
