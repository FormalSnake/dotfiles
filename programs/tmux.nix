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
      continuum
      vim-tmux-navigator
    ];
    extraConfig = ''
      set-option -g status-position top
      set-option -g status-right ""
      set-option -g @continuum-restore 'on'
      set -g mouse on
    '';
  };
}
