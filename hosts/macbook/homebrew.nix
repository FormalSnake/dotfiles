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