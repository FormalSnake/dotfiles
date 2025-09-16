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

  programs.home-manager = {
    enable = true;
  };

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
    nh
    libcaca

    # General utilities
    gimp
    yazi

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
    # aider-chat
    pyenv
    nixd
    devenv
    chafa
    repomix
    lazydocker
    opencode
    codex
    gemini-cli
    uv
    warp-terminal

    # Browsers (available on all platforms)
    firefox

    # Gaming
    prismlauncher

    # NUR packages - examples (uncomment and modify as needed)
    # nur.repos.mic92.hello-nur
    nur.repos.charmbracelet.crush
    # nur.repos.some-author.some-package
  ];

  # Global theming handled by theme engine

  # Common programs
  programs.git = {
    enable = true;
  };

  programs.lazygit.enable = true;

  # Common program imports (available on all platforms)
  imports = [
    ../themes/engine
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
    ../programs/vscode
  ];

  # Enable theme engine and configure available themes
  themes = {
    enable = true;
    current = "catppuccin"; # Fallback theme when no runtime theme is set
    available = import ../themes/definitions {inherit pkgs;};
  };
}
