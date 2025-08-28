{pkgs, ...}: {
  name = "Omarchy Osaka Jade";
  
  colors = {
    # Base colors from the Omarchy theme
    background = "#11221C";
    foreground = "#e6d8ba";
    surface0 = "#252623";
    surface1 = "#2f312c";
    surface2 = "#383b35";
    overlay0 = "#5b5e5a";
    overlay1 = "#838781";
    overlay2 = "#a8ab7c";
    text = "#f1e9d2";
    subtext0 = "#e6d8ba";
    subtext1 = "#dbb651";
    
    # Accent colors combining bamboo multiplex with jade theme
    red = "#e75a7c";
    green = "#71CEAD";      # Jade accent from hyprland.conf
    blue = "#57a5e5";
    yellow = "#dbb651";
    orange = "#ff9966";
    pink = "#f08080";
    purple = "#aaaaff";
    teal = "#71CEAD";       # Primary jade color
    sky = "#96c7ef";
    sapphire = "#70c2be";
    lavender = "#df73ff";
    mauve = "#aaaaff";
  };

  neovim = {
    plugin = pkgs.vimPlugins.bamboo-nvim;
    colorscheme = "bamboo";
  };

  ghostty = {
    theme = "Bamboo";
  };

  btop = {
    theme = ''
      theme[main_bg]="#11221C"
      theme[main_fg]="#e6d8ba"
      theme[title]="#f1e9d2"
      theme[hi_fg]="#71CEAD"
      theme[selected_bg]="#252623"
      theme[selected_fg]="#71CEAD"
      theme[inactive_fg]="#5b5e5a"
      theme[graph_text]="#e6d8ba"
      theme[meter_bg]="#252623"
      theme[proc_misc]="#e6d8ba"
      theme[cpu_box]="#aaaaff"
      theme[mem_box]="#71CEAD"
      theme[net_box]="#e75a7c"
      theme[proc_box]="#57a5e5"
      theme[div_line]="#383b35"
      theme[temp_start]="#71CEAD"
      theme[temp_mid]="#dbb651"
      theme[temp_end]="#e75a7c"
      theme[cpu_start]="#70c2be"
      theme[cpu_mid]="#96c7ef"
      theme[cpu_end]="#df73ff"
    '';
  };

  tmux = {
    config = ''
      # Omarchy Osaka Jade tmux theme
      set -g status-bg "#11221C"
      set -g status-fg "#e6d8ba"
      set -g status-left-style "fg=#11221C,bg=#71CEAD"
      set -g status-right-style "fg=#f1e9d2,bg=#252623"
      set -g window-status-current-style "fg=#11221C,bg=#71CEAD"
      set -g window-status-style "fg=#5b5e5a,bg=#252623"
      set -g pane-border-style "fg=#252623"
      set -g pane-active-border-style "fg=#71CEAD"
      set -g message-style "fg=#11221C,bg=#dbb651"
      set -g message-command-style "fg=#11221C,bg=#71CEAD"
    '';
  };
}