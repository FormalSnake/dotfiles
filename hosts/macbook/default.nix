{
  config,
  pkgs,
  lib,
  ...
}: {
  # Required Darwin system state version
  system.stateVersion = 6;

  # Host-specific dock settings
  system.defaults.dock.persistent-apps = [
    "/Applications/Brave Browser.app"
    "/System/Applications/Calendar.app"
    "/Applications/Equibop.app"
    "/Applications/Ghostty.app"
    # "${pkgs.spotify}/Applications/Spotify.app"
    "/Applications/Spotify.app"
  ];
  system.primaryUser = "kyandesutter";

  # Any host-specific overrides can be placed here
  networking.hostName = "macbook";

  # Host-specific homebrew packages
  homebrew = {
    casks = [
      "notion"
      "ghostty"
      "clop"
      "figma"
      "claude"
      "zerotier-one"
      "balenaetcher"
      "slack"
      "jordanbaird-ice"
      "betterdisplay"
      "steam"
      "loop"
      "latest"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "lazydocker"
      "couchdb"
    ];
  };
}
