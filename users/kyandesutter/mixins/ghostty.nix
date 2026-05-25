{ ... }:
{
  programs.ghostty = {
    enable = true;
    # ghostty is not packaged on darwin in nixpkgs; the binary comes from the
    # `ghostty` homebrew cask. We still use programs.ghostty for the declarative
    # ~/.config/ghostty/config file. Theme is set globally by the catppuccin
    # home-module (see users/kyandesutter/mixins/catppuccin.nix).
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
    };
  };
}
