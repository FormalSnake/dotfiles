{pkgs, ...}: {
  name = "Everforest Dark";
  
  colors = {
    background = "#2d353b";
    foreground = "#d3c6aa";
    surface0 = "#343f44";
    surface1 = "#3d484d";
    surface2 = "#475258";
    overlay0 = "#543a48";
    overlay1 = "#5d4037";
    overlay2 = "#68422e";
    text = "#d3c6aa";
    subtext0 = "#859289";
    subtext1 = "#9da9a0";
    red = "#e67e80";
    green = "#a7c080";
    blue = "#7fbbb3";
    yellow = "#dbbc7f";
    orange = "#e69875";
    pink = "#d699b6";
    purple = "#d699b6";
    teal = "#83c092";
    sky = "#7fbbb3";
    sapphire = "#7fbbb3";
    lavender = "#d699b6";
    mauve = "#d699b6";
  };

  neovim = {
    plugin = pkgs.vimPlugins.everforest;
    colorscheme = "everforest";
  };

  ghostty = {
    theme = "everforest-dark";
  };
}