{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  nixpkgs = {
    overlays = [
      (final: prev: {
        vimPlugins =
          prev.vimPlugins
          // {
            own-auto-dark-mode = prev.vimUtils.buildVimPlugin {
              name = "auto-dark-mode.nvim";
              src = inputs.plugin-auto-dark-mode;
            };
          };
      })
    ];
  };

  home.username = "kyandesutter";
  home.homeDirectory = "/Users/kyandesutter";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = [
    pkgs.cowsay
  ];

  programs.git = {
    enable = true;
    userName = "FormalSnake";
    userEmail = "kyaniserni@gmail.com";
  };

  # Import Neovim config
  imports = [
    ./programs/zsh.nix
    ./programs/neovim.nix
    ./programs/tmux.nix
    ./programs/aerospace.nix
  ];
}
