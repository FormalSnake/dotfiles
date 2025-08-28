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

  btop = {
    theme = ''
      theme[main_bg]="#2e3440"
      theme[main_fg]="#d8dee9"
      theme[title]="#eceff4"
      theme[hi_fg]="#5e81ac"
      theme[selected_bg]="#3b4252"
      theme[selected_fg]="#88c0d0"
      theme[inactive_fg]="#4c566a"
      theme[graph_text]="#e5e9f0"
      theme[meter_bg]="#3b4252"
      theme[proc_misc]="#e5e9f0"
      theme[cpu_box]="#5e81ac"
      theme[mem_box]="#a3be8c"
      theme[net_box]="#bf616a"
      theme[proc_box]="#81a1c1"
      theme[div_line]="#434c5e"
      theme[temp_start]="#a3be8c"
      theme[temp_mid]="#ebcb8b"
      theme[temp_end]="#bf616a"
      theme[cpu_start]="#88c0d0"
      theme[cpu_mid]="#8fbcbb"
      theme[cpu_end]="#b48ead"
    '';
  };

  tmux = {
    config = ''
      # Nord tmux theme
      set -g status-bg "#2e3440"
      set -g status-fg "#d8dee9"
      set -g status-left-style "fg=#2e3440,bg=#88c0d0"
      set -g status-right-style "fg=#eceff4,bg=#3b4252"
      set -g window-status-current-style "fg=#2e3440,bg=#bf616a"
      set -g window-status-style "fg=#4c566a,bg=#3b4252"
      set -g pane-border-style "fg=#3b4252"
      set -g pane-active-border-style "fg=#88c0d0"
      set -g message-style "fg=#2e3440,bg=#ebcb8b"
      set -g message-command-style "fg=#2e3440,bg=#a3be8c"
    '';
  };
}