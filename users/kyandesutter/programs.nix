{ lib, pkgs, ... }:
{
  # CLI tools without a programs.* module (or where we just want the binary).
  home.packages =
    with pkgs;
    [
      cliamp
      just
      zulu21

      # migrated from homebrew formulae
      assimp
      chafa
      cloudflared
      cmake
      coreutils
      deno
      dipc
      fastlane
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
      # Pillow rides along for the aso-appstore-screenshots skill, whose
      # compose.py/showcase.py/generate_frame.py call `python3` directly.
      (python3.withPackages (ps: [ ps.pillow ]))
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
    # Dev toolchain that only earns its place on the mac: the Swift/Xcode and
    # CocoaPods bits are Darwin-only in nixpkgs, the rest is here because the
    # mac is the development host.
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      _1password-cli
      cocoapods
      mas
      stripe-cli
      swiftformat
      swiftlint
      xcbeautify
      xcodegen
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      # TUI for managing bluetooth (bluez), Linux-only.
      bluetui
      # ifconfig/route/netstat. Linux-only because macOS ships them in /sbin.
      nettools
    ];

  programs = {
    man.generateCaches = false;

    bat.enable = true;
    btop = {
      enable = true;
      # Follow DMS's wallpaper-derived palette via a matugen user template that
      # writes ~/.config/btop/themes/dank.theme; point btop at it. Picks up
      # colours on next launch (no live reload).
      settings.color_theme = "dank";
    };
    bun.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    lsd = {
      enable = true;
      settings.display = "almost-all";
    };
    fastfetch.enable = true;
    fd.enable = true;
    fzf.enable = true;
    go.enable = true;
    lazydocker.enable = true;
    lazygit.enable = true;
    opencode.enable = true;
    ripgrep.enable = true;
    yazi = {
      enable = true;
      # Follow DMS's wallpaper-derived palette via a matugen user template that
      # writes ~/.config/yazi/flavors/dank.yazi/flavor.toml; point yazi's
      # top-level theme.toml at it for both modes (the flavor itself is
      # re-rendered on every light/dark flip, so one name covers both). Picks
      # up colours on next launch (no live reload).
      theme.flavor = {
        dark = "dank";
        light = "dank";
      };
    };
    zoxide.enable = true;
  };
}
