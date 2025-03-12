{
  config,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    shortcut = "b";
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
      set -g default-command ${pkgs.zsh}/bin/zsh
      if-shell '[ -z "$(tmux ls 2>/dev/null)" ]' 'new-session'

      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g set-titles on
      set-option -g set-titles-string "#S / #W"
      set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'
      set -gg allow-passthrough all
      set -ga update-environment TERM
      set -ga update-environment TERM_PROGRAM
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'
      set-option -g detach-on-destroy off
      setw -g allow-passthrough on
      set-option -g status-position top
      set-option -g @continuum-restore 'on'
      set -g mouse on
    '';
  };
}
