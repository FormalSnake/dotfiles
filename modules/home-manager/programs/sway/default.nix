{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.light.enable = true;

  wayland.windowManager.sway = {
    enable = true;
    config = rec {
      modifier = "Mod4";
      # Use kitty as default terminal
      terminal = "kitty";
      startup = [
        # Launch Firefox on start
        {command = "firefox";}
      ];
    };
  };
}
