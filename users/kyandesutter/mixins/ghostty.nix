{ ... }:
let
  catppuccinDark = {
    palette = [
      "0=43465A"  "1=F38BA8"  "2=A6E3A1"  "3=F9E2AF"
      "4=87B0F9"  "5=F5C2E7"  "6=94E2D5"  "7=CDD6F4"
      "8=43465A"  "9=F38BA8"  "10=A6E3A1" "11=F9E2AF"
      "12=87B0F9" "13=F5C2E7" "14=94E2D5" "15=A1A8C9"
    ];
    background = "1E1E2E";
    foreground = "CDD6F4";
    cursor-color = "F5E0DC";
    selection-background = "F5E0DC";
    selection-foreground = "1E1E2E";
  };

  catppuccinLight = {
    palette = [
      "0=4C4F69"  "1=D20F39"  "2=40A02B"  "3=DF8E1D"
      "4=1E66F5"  "5=EA76CB"  "6=179299"  "7=ACB0BE"
      "8=6C6F85"  "9=D20F39"  "10=40A02B" "11=DF8E1D"
      "12=1E66F5" "13=EA76CB" "14=179299" "15=ACB0BE"
    ];
    background = "EFF1F5";
    foreground = "4C4F69";
    cursor-color = "DC8A78";
    selection-background = "DC8A78";
    selection-foreground = "EFF1F5";
  };
in
{
  programs.ghostty = {
    enable = true;
    # ghostty is not packaged on darwin in nixpkgs; the binary comes from the
    # `ghostty` homebrew cask. We still use programs.ghostty for declarative
    # ~/.config/ghostty/{config,themes/*} files.
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

    themes = {
      formalconf-dark = catppuccinDark;
      formalconf-light = catppuccinLight;
    };
  };
}
