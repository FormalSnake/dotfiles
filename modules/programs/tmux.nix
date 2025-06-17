{
  config,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    prefix = "C-b";
    escapeTime = 0;
    historyLimit = 50000;
    mouse = true;
    terminal = "tmux-256color";
    
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = tmux-sessionx;
        extraConfig = ''
          set -g @sessionx-bind 's'
          set -g @sessionx-auto-accept 'off'
          set -g @sessionx-custom-paths '~/Documents,~/Projects'
          set -g @sessionx-filter-current 'false'
        '';
      }
      vim-tmux-navigator
      catppuccin
    ];

    extraConfig = ''
      # Kitty image protocol support
      set -gq allow-passthrough on
      set -g visual-activity off
      
      # Terminal capabilities and true color
      set-option -sa terminal-overrides ",xterm*:Tc"
      set -ga terminal-overrides ",*:Ss=\E[%p1%d q:Se=\E[2 q"
      set-option -g focus-events on
      
      # Window title support
      set-option -g set-titles on
      set-option -g set-titles-string "#T"
      
      # Catppuccin theme customization for system integration
      set -g @catppuccin_flavour 'macchiato'
      set -g @catppuccin_window_left_separator ""
      set -g @catppuccin_window_right_separator " "
      set -g @catppuccin_window_middle_separator " █"
      set -g @catppuccin_window_number_position "right"
      set -g @catppuccin_window_default_fill "number"
      set -g @catppuccin_window_default_text "#W"
      set -g @catppuccin_window_current_fill "number"
      set -g @catppuccin_window_current_text "#W"
      set -g @catppuccin_status_modules_right "date_time"
      set -g @catppuccin_status_left_separator  " "
      set -g @catppuccin_status_right_separator ""
      set -g @catppuccin_status_fill "icon"
      set -g @catppuccin_status_connect_separator "no"
      set -g @catppuccin_date_time_text "%H:%M"
      
      # Performance optimizations
      set -s escape-time 0
      set -g display-time 1000
      set -g status-interval 5
      set -g automatic-rename on
      set -g automatic-rename-format '#{b:pane_current_path}'
      
      # Window and pane indexing
      set -g base-index 1
      setw -g pane-base-index 1
      set -g renumber-windows on
    '';
  };
}