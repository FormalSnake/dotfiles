{nix-homebrew, ...}: {
  homebrew = {
    enable = true;
    casks = [
      "notion"
      "ghostty"
      "clop"
      "figma"
      "claude"
      "zerotier-one"
      "balenaetcher"
      "flux"
      "cloudflare-warp"
      "whatsapp"
      "slack"
      "jordanbaird-ice"
      "betterdisplay"
      "steam"
      "brave-browser"
      "loop"
      "latest"
      "raycast"
      "spotify"
      "leader-key"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "imagemagick"
      "couchdb"
    ];
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };
}
