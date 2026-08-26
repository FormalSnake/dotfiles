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
      ./mixins/caffeinate.nix
      ./mixins/auto-update.nix
      ./mixins/storage-gc.nix
      ./mixins/agenix.nix
      ./mixins/remote-access.nix
      ./mixins/rosetta-builder.nix
      ./mixins/obsidian-scan-watcher.nix
      ./mixins/obsidian-note-watcher.nix
      ./mixins/obsidian-livesync-daemon.nix
      ./mixins/portless-proxy.nix
      ./mixins/music.nix
      ./mixins/office-dc-bot.nix
      ./profiles
    ];
  };
}
