{
  config,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
    shortcut = "b";
    mouse = true;
    escapeTime = 0;
    historyLimit = 5000;
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      yank
      resurrect
      continuum
    ];
    extraConfig = ''
      set -g default-command ${pkgs.zsh}/bin/zsh
      if-shell '[ -z "$(tmux ls 2>/dev/null)" ]' 'new-session'

      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g set-titles on
      set-option -g set-titles-string "#S / #W"

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      set -g base-index 1
      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on
      setw -g allow-passthrough on

      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      bind -n S-Left previous-window
      bind -n S-Right next-window

      bind -n M-H previous-window
      bind -n M-L next-window

      set -g visual-activity off
      set -g visual-bell off
      set -g visual-silence off
      setw -g monitor-activity off
      set -g bell-action none

      set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'
      set -g status-position bottom

      set -gg allow-passthrough all
      set -ga update-environment TERM
      set -ga update-environment TERM_PROGRAM

      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      set-option -g detach-on-destroy off

      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"

      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
    '';
  };
}
