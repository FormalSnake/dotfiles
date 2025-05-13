{nix-homebrew, ...}: {
  homebrew = {
    enable = true;
    casks = [
      "notion"
      "ghostty"
      "clop"
      "figma"
      "claude"
      "ubersicht"
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
      "visual-studio-code"
    ];
    brews = [
      "jnsahaj/lumen/lumen"
      "imagemagick"
      "docker"
      "lazydocker"
      "docker-compose"
      "docker-credential-helper"
      "couchdb"
      "leader-key"
    ];
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };
}
