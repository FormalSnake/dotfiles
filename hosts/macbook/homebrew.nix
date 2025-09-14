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
      "httpie-desktop"
      "stats"
      "utm"
      "wireshark-app"
      "hyperkey"
      "discord"
      "rstudio"
      "obsidian"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "couchdb"
      "imagemagick"
      "mas"
      "cloudflare-wrangler"
      "pam-reattach"
    ];
    masApps = {
      Xcode = 497799835;
      Daisydisk = 411643860;
      Perplexity = 6714467650;
      WireGuard = 1451685025;
      Crystalfetch = 6454431289;
      WhatsApp = 310633997;
    };
  };
}
