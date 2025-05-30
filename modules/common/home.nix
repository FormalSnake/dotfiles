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
    # Core utilities
    ripgrep
    fd
    fzf
    gh
    bat
    lazygit

    # Development tools (available on all platforms)
    nodejs
    bun
    cargo
    rustc
    go
    zig
    lua

    # Browsers (available on all platforms)
    firefox
    brave

    # Media
    # spotify
  ];

  # Global theming
  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  # Common programs
  programs.git = {
    enable = true;
  };

  programs.lazygit.enable = true;

  programs.oh-my-posh = {
    enable = true;
    useTheme = "catppuccin_mocha";
  };

  # Common program imports (available on all platforms)
  imports = [
    ../programs/zsh.nix
    ../programs/neovim.nix
    ../programs/tmux.nix
    ../programs/zoxide.nix
    ../programs/fzf.nix
    ../programs/kitty.nix
    ../programs/ghostty.nix
    ../programs/btop.nix
    ../programs/fastfetch.nix
  ];
}
