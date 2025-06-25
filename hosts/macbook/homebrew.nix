{
  pkgs,
  lib,
  ...
}: {
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
      "latest"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "lazydocker"
      "couchdb"
    ];
  };
}

