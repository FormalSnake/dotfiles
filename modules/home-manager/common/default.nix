{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
in {
  # Common state version (can be overridden per host if needed)
  home.stateVersion = "25.05";

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
    zoxide

    # Development tools (available on all platforms)
    nodejs
    bun
    cargo
    rustc
    go
    zig
    lua
    claude-code
    # zed-editor
    aider-chat
    pyenv
    nixd
    devenv
    chafa
    repomix
    lazydocker
    opencode
    codex
    gemini-cli
    wrangler

    # Browsers (available on all platforms)
    firefox
  ];

  # Global theming
  # catppuccin.flavor = "mocha";
  # catppuccin.enable = true;
  catppuccin = {
    enable = true;
    flavor = "mocha"; # Options: latte, frappe, macchiato, mocha
  };

  # Common programs
  programs.git = {
    enable = true;
  };

  programs.lazygit.enable = true;

  # Common program imports (available on all platforms)
  imports = [
    ../programs/fish
    ../programs/neovim
    ../programs/tmux
    ../programs/zoxide
    ../programs/fzf
    ../programs/kitty
    ../programs/ghostty
    ../programs/btop
    ../programs/fastfetch
    ../programs/spotify
    ../programs/discord
  ];
}
