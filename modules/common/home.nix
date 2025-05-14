{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  # Common state version (can be overridden per host if needed)
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # Common packages for all systems
  home.packages = with pkgs; [
    ripgrep
    fd
    fzf
    gh
    bat
    lazygit
  ];

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.git = {
    enable = true;
  };

  programs.lazygit.enable = true;

  programs.oh-my-posh = {
    enable = true;
    useTheme = "huvix";
  };

  # Common program imports
  imports = [
    ../programs/zsh.nix
    ../programs/neovim.nix
    ../programs/tmux.nix
    ../programs/zoxide.nix
    ../programs/fzf.nix
  ];
}