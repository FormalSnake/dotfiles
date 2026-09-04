{ lib, pkgs, ... }:
{
  # CLI tools without a programs.* module (or where we just want the binary).
  home.packages =
    with pkgs;
    [
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
      # Messages (~/Developer/messages), the gpuix iMessage client that replaced
      # the BlueBubbles desktop app; the Mac still runs the BlueBubbles *Server*
      # (homebrew cask in systems/macbook/homebrew.nix). It runs straight from
      # the checkout so `git pull` is the whole upgrade, with `bun install` once
      # when node_modules is missing. The prebuilt renderer dlopens wayland,
      # vulkan and friends at runtime and nix's bun never reads
      # NIX_LD_LIBRARY_PATH, so they go on LD_LIBRARY_PATH (same list as the
      # repo's flake.nix dev shell). One window per session: a second launch
      # focuses the live one. GPUI sets no Wayland app-id, so that fallback and
      # the hyprland rules match the window title.
      (writeShellApplication {
        name = "messages";
        runtimeInputs = [ bun util-linux ];
        text = ''
          repo="''${MESSAGES_REPO:-$HOME/Developer/messages}"
          exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/messages.lock"
          if ! flock -n 9; then
            if command -v hyprctl >/dev/null 2>&1; then
              hyprctl dispatch 'hl.dsp.focus({ window = "title:^(Messages)$" })' >/dev/null 2>&1 || true
            fi
            exit 0
          fi
          [ -d "$repo/node_modules" ] || bun install --cwd "$repo"
          export LD_LIBRARY_PATH="/run/opengl-driver/lib:${
            lib.makeLibraryPath [
              libxkbcommon
              wayland
              vulkan-loader
              fontconfig.lib
              freetype
              libxcb
              libx11
              libglvnd
            ]
          }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          cd "$repo/apps/desktop"
          exec bun app.tsx "$@"
        '';
      })
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
