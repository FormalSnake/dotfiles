{
  config,
  pkgs,
  lib,
  ...
}: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;

    # Common brews for all macOS machines
    brews = [
      "docker"
      "docker-compose"
      "docker-credential-helper"
      "imagemagick"
    ];

    # Common casks for all macOS machines
    casks = [
      "brave-browser"
      "cloudflare-warp"
      "flux"
      "raycast"
      "whatsapp"
      "leader-key"
      "google-drive"
      "spotify"
    ];
  };
}
