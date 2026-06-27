{ pkgs, ... }:
{
  # Cross-platform base only. Platform-specific mixins live in ./darwin.nix and
  # ./linux.nix, wired per-host (self.homeModules.kyandesutter-{darwin,linux}) —
  # imports must not depend on `pkgs`/`config` (that causes infinite recursion).
  imports = [
    ./programs.nix
    ./shell.nix
    ./mixins/fish.nix
    ./mixins/git.nix
    ./mixins/gh.nix
    ./mixins/ssh.nix
    ./mixins/claude-code.nix
    ./mixins/canarycode.nix
    ./mixins/pi.nix
    ./mixins/ghostty.nix
    ./mixins/tmux.nix
    ./mixins/neovim.nix
    ./mixins/catppuccin.nix
    ./mixins/fastfetch.nix
    ./mixins/herdr.nix
    ./mixins/godot.nix
  ];

  home = {
    username = "kyandesutter";
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/kyandesutter" else "/home/kyandesutter";
    stateVersion = "26.05";
    # nixpkgs tracks unstable; home-manager master still reports 26.05.
    # The mismatch is transient — silence until HM master bumps to 26.11.
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;
}
