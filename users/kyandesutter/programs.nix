{ pkgs, ... }:
{
  # CLI tools without a programs.* module (or where we just want the binary).
  home.packages = with pkgs; [
    just
    zulu17
    _1password-cli

    # — migrated from homebrew formulae —
    assimp
    chafa
    cloudflared
    cmake
    cocoapods
    coreutils
    deno
    dipc
    ffmpeg
    git-filter-repo
    imagemagick
    libcaca
    libpq
    lua
    mas
    mosh
    neovim
    ninja
    nodejs_24
    poppler
    pyenv
    raylib
    rclone
    stow
    swiftformat
    swiftlint
    terminal-notifier
    tmux
    tree-sitter
    uv
    wget
    xcbeautify
    xcodegen
  ];

  programs = {
    man.generateCaches = false;

    bat.enable = true;
    btop.enable = true;
    bun.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    eza = {
      enable = true;
      icons = "auto";
    };
    fastfetch.enable = true;
    fd.enable = true;
    fzf.enable = true;
    go.enable = true;
    lazydocker.enable = true;
    lazygit.enable = true;
    opencode.enable = true;
    prismlauncher = {
      enable = true;
      # Bundle only zulu17 (matches what was on brew). The default jdk21/17/8
      # triple would pull a lot of extra JDKs we don't need.
      package = pkgs.prismlauncher.override { jdks = [ pkgs.zulu17 ]; };
    };
    ripgrep.enable = true;
    yazi.enable = true;
    zoxide.enable = true;
  };
}
