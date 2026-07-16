{
  flake.darwinModules.default = {
    imports = [
      ../shared
      ./mixins/determinate.nix
      ./mixins/homebrew.nix
      ./mixins/home-manager.nix
      ./mixins/mac-app-util.nix
      ./mixins/system-defaults.nix
      ./mixins/dock-pins.nix
      ./mixins/login-items.nix
      ./mixins/auto-update.nix
      ./mixins/agenix.nix
      ./mixins/remote-access.nix
      ./mixins/obsidian-scan-watcher.nix
      ./mixins/obsidian-note-watcher.nix
      ./mixins/obsidian-livesync-daemon.nix
      ./profiles
    ];
  };
}
