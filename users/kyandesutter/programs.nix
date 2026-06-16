{ lib, pkgs, ... }:
{
  # CLI tools without a programs.* module (or where we just want the binary).
  home.packages =
    with pkgs;
    [
      just
      zulu21
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
      # Bundle zulu17 (older MC) and zulu21 (MC 1.20.5+/1.21 require Java 21).
      # Prism auto-selects the right JDK per instance. We skip the default
      # jdk21/17/8 triple to avoid pulling the extra Java 8 JDK we don't need.
      package =
        let
          prism = pkgs.prismlauncher.override { jdks = [ pkgs.zulu17 pkgs.zulu21 ]; };
        in
        # On the PRIME laptop, wrap so Minecraft (OpenGL — it can't grab the
        # dGPU opportunistically the way Vulkan games can) renders on the RTX
        # 5070. gpuOffloadWrap is provided by the nvidia mixin's overlay, so it
        # only exists on Linux/g815; on darwin fall through to the plain package.
        if pkgs ? gpuOffloadWrap then pkgs.gpuOffloadWrap prism else prism;
    };
    ripgrep.enable = true;
    yazi.enable = true;
    zoxide.enable = true;
  };
}
