{pkgs, ...}: {
  name = "Catppuccin Mocha";
  
  colors = {
    background = "#1e1e2e";
    foreground = "#cdd6f4";
    surface0 = "#313244";
    surface1 = "#45475a";
    surface2 = "#585b70";
    overlay0 = "#6c7086";
    overlay1 = "#7f849c";
    overlay2 = "#9399b2";
    text = "#cdd6f4";
    subtext0 = "#a6adc8";
    subtext1 = "#bac2de";
    red = "#f38ba8";
    green = "#a6e3a1";
    blue = "#89b4fa";
    yellow = "#f9e2af";
    orange = "#fab387";
    pink = "#f5c2e7";
    purple = "#cba6f7";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    lavender = "#b4befe";
    mauve = "#cba6f7";
  };

  neovim = {
    plugin = pkgs.vimPlugins.catppuccin-nvim;
    colorscheme = "catppuccin-mocha";
  };

  ghostty = {
    theme = "catppuccin-mocha";
  };
}