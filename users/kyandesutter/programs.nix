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
      # systems/macbook/homebrew.nix): the server is macOS-only.
      # The nixpkgs wrapper misses glib-networking, so the Google-login webview
      # (WebKitGTK/libsoup) has no TLS backend ("TLS support is not available").
      # Re-wrap with its GIO module instead of rebuilding the Flutter app.
      # Flutter apps have no single-instance lock (unlike Electron), so every
      # launcher click spawns another copy, and the workspace-4 window rule
      # hides that it's already running. Hold a flock for the app's lifetime
      # (fd 9 survives the exec). Later launches focus the live window instead.
      # Wrap the package's own entrypoint under a fresh name instead of
      # wrapProgram-ing the symlinkJoin copy in place (the moved-aside file's
      # basename becomes argv0; upstream's inner wrapper re-execs with -a "$0")
      # and GTK derives the Wayland app-id from it. A ".bluebubbles-wrapped_"
      # app-id breaks the Hyprland workspace-4/tiling rules and the focus
      # fallback below, which all match ^[Bb]lue[Bb]ubbles$.
      (symlinkJoin {
        name = "bluebubbles-wrapped";
        paths = [ bluebubbles ];
        nativeBuildInputs = [ makeWrapper ];
        postBuild = ''
          rm $out/bin/bluebubbles
          makeWrapper ${bluebubbles}/bin/bluebubbles $out/bin/bluebubbles \
            --prefix GIO_EXTRA_MODULES : ${glib-networking}/lib/gio/modules \
            --run ${lib.escapeShellArg ''
              exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/bluebubbles.lock"
              if ! ${util-linux}/bin/flock -n 9; then
                if command -v hyprctl >/dev/null 2>&1; then
                  hyprctl dispatch 'hl.dsp.focus({ window = "class:^[Bb]lue[Bb]ubbles$" })' >/dev/null 2>&1 || true
                fi
                exit 0
              fi
            ''}
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
