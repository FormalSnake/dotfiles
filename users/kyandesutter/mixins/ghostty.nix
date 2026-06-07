{ config, lib, ... }:
{
  programs.ghostty = {
    enable = true;
    # ghostty is not packaged on darwin in nixpkgs; the binary comes from the
    # `ghostty` homebrew cask. We still use programs.ghostty for the declarative
    # ~/.config/ghostty/config file. The catppuccin home-module installs the
    # dark theme file and a single-flavor `theme` line; we override that line
    # below so the dark variant tracks catppuccin.flavor and light stays latte.
    package = null;
    enableFishIntegration = false;

    settings = {
      font-family = "BlexMono Nerd Font";
      font-size = 12;

      cursor-style = "block";
      cursor-style-blink = false;
      # Original file set this twice (`no-cursor` then `true`); preserve the
      # last-wins behaviour with a single value.
      shell-integration = "fish";
      shell-integration-features = true;

      background-opacity = 0.9;
      background-blur-radius = 32;

      mouse-hide-while-typing = true;
      macos-titlebar-style = "tabs";

      window-padding-x = 14;
      window-padding-y = 14;
      window-padding-balance = true;
      window-colorspace = "display-p3";
      confirm-close-surface = false;
      resize-overlay = "never";

      clipboard-read = "allow";
      clipboard-write = "allow";

      keybind = [
        "global:cmd+shift+space=toggle_quick_terminal"
        "shift+enter=text:\\x1b\\r"
      ];

      # Follow the macOS appearance: latte in Light, catppuccin.flavor in Dark.
      # mkForce overrides the catppuccin module's "light:<flavor>,dark:<flavor>".
      theme = lib.mkForce "light:catppuccin-latte,dark:catppuccin-${config.catppuccin.flavor}";
    };
  };

  # The catppuccin module only installs the active (dark) flavor's theme file;
  # ghostty also needs the latte file for the Light side. Guarded so it doesn't
  # collide with the module's own install if flavor is ever set to latte.
  xdg.configFile = lib.mkIf (config.catppuccin.flavor != "latte") {
    "ghostty/themes/catppuccin-latte".source =
      "${config.catppuccin.sources.ghostty}/catppuccin-latte.conf";
  };
}
