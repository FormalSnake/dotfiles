{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
      allowBroken = true;
    };
    overlays = [
      (final: prev: {
        vimPlugins =
          prev.vimPlugins
          // {
            own-auto-dark-mode = prev.vimUtils.buildVimPlugin {
              name = "auto-dark-mode.nvim";
              src = inputs.plugin-auto-dark-mode;
            };
            own-visual-whitespace = prev.vimUtils.buildVimPlugin {
              name = "visual-whitespace.nvim";
              src = inputs.plugin-visual-whitespace;
            };
            own-tidy = prev.vimUtils.buildVimPlugin {
              name = "tidy.nvim";
              src = inputs.plugin-tidy;
            };
            own-base16 = prev.vimUtils.buildVimPlugin {
              name = "base16.nvim";
              src = inputs.plugin-base16;
            };
            own-aider = prev.vimUtils.buildVimPlugin {
              name = "aider.nvim";
              src = inputs.plugin-aider;
            };
            own-bg = prev.vimUtils.buildVimPlugin {
              name = "bg.nvim";
              src = inputs.plugin-bg;
            };
          };
      })
    ];
  };

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
  catppuccin.enable = false;

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