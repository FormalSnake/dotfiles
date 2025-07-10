{
  pkgs,
  lib,
  ...
}: {
  # Host-specific homebrew packages
  homebrew = {
    enable = true;

    # Auto-update and cleanup configuration
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    casks = [
      "notion"
      "ghostty"
      "clop"
      "figma"
      "claude"
      "zerotier-one"
      "balenaetcher"
      "betterdisplay"
      "steam"
      "brave-browser"
      "google-drive"
      "github"
      "logi-options+"
      "nordvpn"
      "alcove"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "couchdb"
      "imagemagick"
      "mas"
    ];
    masApps = {
      Xcode = 497799835;
      Daisydisk = 411643860;
    };
  };
}
