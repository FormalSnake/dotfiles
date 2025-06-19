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
          set -g @sessionx-filter-current 'false'
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-save-bash-history 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
          set -g @continuum-boot 'on'
        '';
      }
      vim-tmux-navigator
    ];

    extraConfig = ''
      # Kitty image protocol support
      set -gq allow-passthrough on
      set -g visual-activity off

      # Terminal capabilities and true color
      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g focus-events on

      # Window title support
      set-option -g set-titles on
      set-option -g set-titles-string "#T"

      # Status bar configuration
      set -g status on
      set -g status-position bottom
      set -g status-justify left
      set -g status-style 'bg=default fg=default'

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

