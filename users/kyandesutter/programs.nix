{ lib, pkgs, ... }:
{
  # CLI tools without a programs.* module (or where we just want the binary).
  home.packages =
    with pkgs;
    [
      just
      zulu17
      _1password-cli

      # — migrated from homebrew formulae —
      assimp
      chafa
      cloudflared
      cmake
      coreutils
      deno
      dipc
      ffmpeg
      git-filter-repo
      imagemagick
      libcaca
      libpq
      lua
      mosh
      ninja
      nodejs_24
      pi-coding-agent
      poppler
      pyenv
      raylib
      # rclone 1.74.2 in nixpkgs unconditionally requires fuse3, which has no
      # working Darwin path (the postConfigure that patches fuse.h is gated on
      # !isDarwin). Disabling cmount skips cgofuse; rclone mount on macOS needs
      # macFUSE (kernel ext, not in nixpkgs) anyway, so nothing useful is lost.
      (rclone.override { enableCmount = false; })
      stow
      tmux
      tree-sitter
      uv
      wget
      zig
    ]
    # macOS-only dev toolchain (Swift/Xcode/CocoaPods, Mac App Store CLI).
    # These packages are Darwin-only in nixpkgs, so guard them off on Linux.
    ++ lib.optionals stdenv.isDarwin [
      cocoapods
      mas
      swiftformat
      swiftlint
      terminal-notifier
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
