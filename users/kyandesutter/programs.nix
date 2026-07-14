{ lib, pkgs, ... }:
{
  # CLI tools without a programs.* module (or where we just want the binary).
  home.packages =
    with pkgs;
    [
      just
      zulu21

      # — migrated from homebrew formulae —
      assimp
      chafa
      cloudflared
      cmake
      coreutils
      deno
      dipc
      ffmpeg
      file
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
      # python3 on PATH for Claude Code's security-guidance plugin and the herdr
      # agent-state hook (both `exec python3`; without it they fail loudly).
      python3
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
      tinyxxd # provides the `xxd` binary (no standalone `xxd` package in nixpkgs)
      zig
    ]
    # macOS-only dev toolchain (Swift/Xcode/CocoaPods, Mac App Store CLI).
    # These packages are Darwin-only in nixpkgs, so guard them off on Linux.
    ++ lib.optionals stdenv.isDarwin [
      _1password-cli
      cocoapods
      mas
      swiftformat
      swiftlint
      xcbeautify
      xcodegen
    ]
    ++ lib.optionals stdenv.isLinux [
      # BlueBubbles desktop client (iMessage). Flutter app; Linux-only in
      # nixpkgs. The Mac runs the BlueBubbles *Server* instead (homebrew cask in
      # systems/macbook/homebrew.nix) — the server is macOS-only.
      bluebubbles
      # VNC client for the Mac's built-in Screen Sharing (reached over Tailscale)
      # — for seeing/clicking GUI & permission dialogs on the remote work
      # server. See docs/remote-server.md.
      remmina
      # TUI for managing bluetooth (bluez) — Linux-only.
      bluetui
    ];

  programs = {
    man.generateCaches = false;

    bat.enable = true;
    btop = {
      enable = true;
      # Follow Noctalia's wallpaper-derived palette: its `btop` builtin template
      # writes ~/.config/btop/themes/noctalia.theme (see mixins/noctalia.nix);
      # point btop at it. Picks up colours on next launch (no live reload).
      settings.color_theme = "noctalia";
    };
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
    ripgrep.enable = true;
    yazi.enable = true;
    zoxide.enable = true;
  };
}
