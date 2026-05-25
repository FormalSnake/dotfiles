{
  imports = [
    ./programs.nix
    ./shell.nix
    ./mixins/fish.nix
    ./mixins/git.nix
    ./mixins/gh.nix
    ./mixins/ssh.nix
    ./mixins/claude-code.nix
    ./mixins/ghostty.nix
    ./mixins/tmux.nix
    ./mixins/aerospace.nix
    ./mixins/karabiner.nix
    ./mixins/hammerspoon.nix
    ./mixins/neovim.nix
    ./mixins/catppuccin.nix
    ./mixins/fastfetch.nix
    ./mixins/rift.nix
    ./mixins/lynk-browser.nix
  ];

  home = {
    username = "kyandesutter";
    homeDirectory = "/Users/kyandesutter";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
