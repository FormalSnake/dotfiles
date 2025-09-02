{
  config,
  pkgs,
  ...
}: let
in {
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    prefix = "C-b";
    escapeTime = 0;
    historyLimit = 50000;
    mouse = true;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      # {
      #   plugin = tmux-sessionx;
      #   extraConfig = ''
      #     set -g @sessionx-bind 's'
      #     set -g @sessionx-auto-accept 'off'
      #     set -g @sessionx-filter-current 'false'
      #   '';
      # }
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
      {
        plugin = tmux-fzf;
        extraConfig = ''
          set-environment -g TMUX_FZF_LAUNCH_KEY "C-f"
          set-environment -g TMUX_FZF_ORDER "session|window|pane|command|keybinding|clipboard|process"
          set-environment -g TMUX_FZF_ACTION_ORDER "switch|attach|rename|kill"
        '';
      }
    ];

    extraConfig = ''
      # Image protocol support (kitty/ghostty)
      set -gq allow-passthrough on
      set -g visual-activity off
      
      # Ensure passthrough for nested sessions
      set -g allow-passthrough all

      # Terminal capabilities and true color
      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -sa terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[2 q'
      set-option -ga terminal-overrides '*:Tc'
      set-option -ga terminal-overrides '*:sitm=\E[3m'
      set-option -sa terminal-features ',xterm-ghostty:RGB'
      
      # Ghostty image protocol support
      set-option -ga terminal-overrides ',xterm-ghostty:Ms=\\E]52;%p1%s;%p2%s\\007'
      set-option -ga terminal-overrides ',xterm-ghostty:Sync'
      set-option -g focus-events on

      # Window title support
      set-option -g set-titles on
      set-option -g set-titles-string "#T"

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

      # Load current theme if symlink exists
      if-shell '[ -L ~/.config/tmux/current-theme.conf ]' 'source ~/.config/tmux/current-theme.conf'
      
      # Status bar configuration (after theme loading)
      set -g status on
      set -g status-position bottom
      set -g status-justify left

      # Shortcuts
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
    '';
  };
}
