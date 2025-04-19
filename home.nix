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
          };
      })
    ];
  };

  home.username = "kyandesutter";
  home.homeDirectory = "/Users/kyandesutter";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = [
    pkgs.raycast # Launcher for macOS
    pkgs.aider-chat # AI-assisted code editing tool
    pkgs.claude-code # AI-assisted code editing tool
    pkgs.pyenv
    pkgs.ice-bar # Status bar utility
    pkgs.mousecape # Custom cursors for macOS
    pkgs.the-unarchiver # Archive extraction utility
    pkgs.google-chrome # Web browser
    pkgs.brave
    pkgs.repomix
    pkgs.firefox
    pkgs.spotify-player
    pkgs.prismlauncher
  ];

  # home.activation.setDefaultBrowser = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   if command -v defaultbrowser &>/dev/null; then
  #     defaultbrowser chrome
  #   fi
  # '';

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  programs.git = {
    enable = true;
  };

  programs.lazygit.enable = true;

  programs.oh-my-posh = {
    enable = true;
    useTheme = "catppuccin_mocha";
    enableNushellIntegration = true;
  };

  imports = [
    ./programs/zsh.nix
    ./programs/neovim.nix
    ./programs/tmux.nix
    ./programs/aerospace.nix
    ./programs/ghostty.nix
    ./programs/btop.nix
    ./programs/zoxide.nix
    ./programs/fastfetch.nix
    ./programs/matugen.nix
    ./programs/fzf.nix
  ];
}
