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
      # "ghostty"
      "clop"
      "figma"
      "claude"
      "zerotier-one"
      "balenaetcher"
      "jordanbaird-ice"
      "betterdisplay"
      "steam"
      "latest"
      "brave-browser"
      "google-drive"
      "leader-key"
      "github"
      "cloudflare-warp"
      "spotify"
      "flux"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "couchdb"
      "imagemagick"
    ];
  };
}
