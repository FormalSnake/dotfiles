{pkgs, ...}: {
  name = "Nord";
  
  colors = {
    background = "#2e3440";
    foreground = "#d8dee9";
    surface0 = "#3b4252";
    surface1 = "#434c5e";
    surface2 = "#4c566a";
    overlay0 = "#5e81ac";
    overlay1 = "#81a1c1";
    overlay2 = "#88c0d0";
    text = "#eceff4";
    subtext0 = "#e5e9f0";
    subtext1 = "#d8dee9";
    red = "#bf616a";
    green = "#a3be8c";
    blue = "#5e81ac";
    yellow = "#ebcb8b";
    orange = "#d08770";
    pink = "#b48ead";
    purple = "#b48ead";
    teal = "#88c0d0";
    sky = "#8fbcbb";
    sapphire = "#88c0d0";
    lavender = "#b48ead";
    mauve = "#b48ead";
  };

  neovim = {
    plugin = pkgs.vimPlugins.nord-nvim;
    colorscheme = "nord";
  };

  ghostty = {
    theme = "nord";
  };
}