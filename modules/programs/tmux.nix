{
  config,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    keyMode = "vi";
    shortcut = "b";
    terminal = "screen-256color";
    mouse = true;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 50000;
    
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-vim 'session'
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-boot 'on'
          set -g @continuum-save-interval '10'
        '';
      }
      sensible
      yank
      vim-tmux-navigator
    ];

    extraConfig = ''
      # Shell and session management
      set -g default-command /bin/zsh
      if-shell '[ -z "$(tmux ls 2>/dev/null)" ]' 'new-session'

      # Terminal capabilities
      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g set-titles on
      set-option -g set-titles-string "#S / #W"
      set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'
      set -ga update-environment TERM
      set -ga update-environment TERM_PROGRAM
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'
      set -p allow-passthrough on

      # Session management
      set-option -g detach-on-destroy off

      # Status bar configuration
      set-option -g status-position top
      set -g status-style "bg=#1e1e2e,fg=#eeeeee"
      set -g status-interval 1
      set -g status-left-length 200
      set -g status-left "#[fg=cyan] | #[fg=green] #S#[fg=yellow]  #(basename #{pane_current_path})"
      set -g status-right "#[fg=red] %H:%M #[fg=blue] %D"
      set -g status-justify "absolute-centre"
      set -g window-status-current-format "#[fg=green]#[bg=green,fg=#000000] #(bash ~/lq/iconify.bash #W) (#(basename #{pane_current_path})) #[bg=#11111b,fg=green]"
      set -g window-status-format "#[fg=#1e1e2e]#[bg=#1e1e2e,fg=grey] #(bash ~/lq/iconify.bash #W) (#(basename #{pane_current_path})) #[bg=#1e1e2e,fg=#1e1e2e]"

      # Pane and window styling
      set -g pane-active-border-style "fg=white"
      set -g pane-border-style "fg=white"
      set -g message-style "bg=#1e1e2e,fg=blue"
      set -g mode-style "bg=#b5befe,fg=#1e1e2e"
    '';
  };
}