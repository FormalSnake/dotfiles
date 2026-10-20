{
  flake.darwinModules.default = {
    imports = [
      ../shared
      ./mixins/core/determinate.nix
      ./mixins/core/homebrew.nix
      ./mixins/core/home-manager.nix
      ./mixins/core/mac-app-util.nix
      ./mixins/core/system-defaults.nix
      ./mixins/core/dock-pins.nix
      ./mixins/core/login-items.nix
      ./mixins/core/caffeinate.nix
      ./mixins/core/auto-update.nix
      ./mixins/core/storage-gc.nix
      ./mixins/core/dev-vm-reaper.nix
      ./mixins/core/agenix.nix
      ./mixins/remote/remote-access.nix
      ./mixins/remote/usbflux.nix
      ./mixins/remote/rosetta-builder.nix
      ./mixins/obsidian/obsidian-scan-watcher.nix
      ./mixins/obsidian/obsidian-note-watcher.nix
      ./mixins/obsidian/obsidian-livesync-daemon.nix
      ./mixins/obsidian/obsidian-livesync-serve.nix
      ./mixins/remote/portless-proxy.nix
      ./profiles
    ];
  };
}
