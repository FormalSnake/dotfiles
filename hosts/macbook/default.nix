{
  config,
  pkgs,
  lib,
  ...
}: {
  # Host-specific dock settings
  system.defaults.dock.persistent-apps = [
    "/Applications/Brave Browser.app"
    "/System/Applications/Calendar.app"
    "/Applications/Equibop.app"
    "/Applications/Ghostty.app"
  ];

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
