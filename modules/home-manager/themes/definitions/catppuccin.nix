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

  btop = {
    theme = ''
      theme[main_bg]="#1e1e2e"
      theme[main_fg]="#cdd6f4"
      theme[title]="#cdd6f4"
      theme[hi_fg]="#89b4fa"
      theme[selected_bg]="#313244"
      theme[selected_fg]="#89b4fa"
      theme[inactive_fg]="#6c7086"
      theme[graph_text]="#f2d5cf"
      theme[meter_bg]="#313244"
      theme[proc_misc]="#f2d5cf"
      theme[cpu_box]="#cba6f7"
      theme[mem_box]="#a6e3a1"
      theme[net_box]="#eba0ac"
      theme[proc_box]="#89b4fa"
      theme[div_line]="#585b70"
      theme[temp_start]="#a6e3a1"
      theme[temp_mid]="#f9e2af"
      theme[temp_end]="#f38ba8"
      theme[cpu_start]="#94e2d5"
      theme[cpu_mid]="#89dceb"
      theme[cpu_end]="#b4befe"
    '';
  };

  tmux = {
    config = ''
      # Catppuccin Mocha tmux theme
      set -g status-bg "#1e1e2e"
      set -g status-fg "#cdd6f4"
      set -g status-left-style "fg=#1e1e2e,bg=#89b4fa"
      set -g status-right-style "fg=#cdd6f4,bg=#313244"
      set -g window-status-current-style "fg=#1e1e2e,bg=#f38ba8"
      set -g window-status-style "fg=#6c7086,bg=#313244"
      set -g pane-border-style "fg=#313244"
      set -g pane-active-border-style "fg=#89b4fa"
      set -g message-style "fg=#1e1e2e,bg=#f9e2af"
      set -g message-command-style "fg=#1e1e2e,bg=#a6e3a1"
    '';
  };
}