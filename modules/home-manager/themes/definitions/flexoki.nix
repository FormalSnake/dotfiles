{pkgs, ...}: {
  name = "Flexoki Dark";
  
  colors = {
    # Base colors
    background = "#1C1B1A";  # base-950
    foreground = "#878580";  # base-500
    
    # Surface levels
    surface0 = "#282726";    # base-900
    surface1 = "#343331";    # base-850
    surface2 = "#403E3C";    # base-800
    
    # Overlay/UI colors
    overlay0 = "#575653";    # base-700
    overlay1 = "#6F6E69";    # base-600
    overlay2 = "#878580";    # base-500
    
    # Text colors
    text = "#B7B5AC";        # base-300
    subtext0 = "#9F9D96";    # base-400
    subtext1 = "#878580";    # base-500
    
    # Accent colors (600 variants for dark theme)
    red = "#AF3029";         # red-600
    green = "#66800B";       # green-600
    blue = "#205EA6";        # blue-600
    yellow = "#AD8301";      # yellow-600
    orange = "#BC5215";      # orange-600
    pink = "#A02F6F";        # magenta-600
    purple = "#5E409D";      # purple-600
    teal = "#24837B";        # cyan-600
    cyan = "#24837B";        # cyan-600
    magenta = "#A02F6F";     # magenta-600
    
    # Additional colors
    black = "#100F0F";       # true black
    white = "#CECDC3";       # base-200
    
    # Bright variants (using lighter values)
    brightRed = "#D14D41";
    brightGreen = "#879A39";
    brightBlue = "#4385BE";
    brightYellow = "#D0A215";
    brightCyan = "#3AA99F";
    brightMagenta = "#CE5D97";
  };

  neovim = {
    plugin = pkgs.vimPlugins.flexoki-nvim;
    colorscheme = "flexoki-dark";
  };

  ghostty = {
    theme = "flexoki-dark";
  };

  btop = {
    theme = ''
      theme[main_bg]="#1C1B1A"
      theme[main_fg]="#B7B5AC"
      theme[title]="#B7B5AC"
      theme[hi_fg]="#205EA6"
      theme[selected_bg]="#343331"
      theme[selected_fg]="#205EA6"
      theme[inactive_fg]="#575653"
      theme[graph_text]="#878580"
      theme[meter_bg]="#282726"
      theme[proc_misc]="#878580"
      theme[cpu_box]="#5E409D"
      theme[mem_box]="#66800B"
      theme[net_box]="#AF3029"
      theme[proc_box]="#205EA6"
      theme[div_line]="#403E3C"
      theme[temp_start]="#66800B"
      theme[temp_mid]="#AD8301"
      theme[temp_end]="#AF3029"
      theme[cpu_start]="#24837B"
      theme[cpu_mid]="#205EA6"
      theme[cpu_end]="#5E409D"
    '';
  };

  tmux = {
    config = ''
      # Flexoki Dark tmux theme
      set -g status-bg "#1C1B1A"
      set -g status-fg "#B7B5AC"
      set -g status-left-style "fg=#1C1B1A,bg=#205EA6"
      set -g status-right-style "fg=#B7B5AC,bg=#282726"
      set -g window-status-current-style "fg=#1C1B1A,bg=#66800B"
      set -g window-status-style "fg=#575653,bg=#282726"
      set -g pane-border-style "fg=#343331"
      set -g pane-active-border-style "fg=#205EA6"
      set -g message-style "fg=#1C1B1A,bg=#AD8301"
      set -g message-command-style "fg=#1C1B1A,bg=#66800B"
    '';
  };
}