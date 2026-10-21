{ pkgs, ... }:
{
  # Cross-platform base only. Platform-specific mixins live in ./darwin.nix and
  # ./linux.nix, wired per-host (self.homeModules.kyandesutter-{darwin,linux}):
  # imports must not depend on `pkgs`/`config` (that causes infinite recursion).
  imports = [
    ./programs.nix
    ./shell.nix
    ./mixins/cli/fish.nix
    ./mixins/dev/git.nix
    ./mixins/dev/gh.nix
    ./mixins/cli/ssh.nix
    ./mixins/cli/clipssh.nix
    ./mixins/dev/claude-code.nix
    ./mixins/dev/pi.nix
    ./mixins/dev/fspec.nix
    ./mixins/cli/ghostty.nix
    ./mixins/cli/tmux.nix
    ./mixins/dev/neovim.nix
    ./mixins/flexoki
    ./mixins/cli/fastfetch
    ./mixins/cli/fetch.nix
    ./mixins/cli/herdr.nix
    ./mixins/cli/meshtop.nix
    ./mixins/dev/t3code.nix
    ./mixins/cli/fast.nix
    ./mixins/cli/fut.nix
    ./mixins/cli/nh.nix
    ./mixins/cli/nix-index.nix
    ./mixins/cli/unfree.nix
    ./mixins/apps/kopuz.nix
    ./mixins/apps/messages.nix
    ./mixins/apps/formalmusic.nix
    ./mixins/dev/android.nix
  ];

  home = {
    username = "kyandesutter";
    stateVersion = "26.05";
    # nixpkgs tracks unstable; home-manager master still reports 26.05.
    # The mismatch is transient: silence until HM master bumps to 26.11.
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;
}
