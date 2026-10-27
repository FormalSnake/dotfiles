{
  homebrew = {
    # Homebrew 6 tap trust: `brew bundle` REPLACES ~/.homebrew/trust.json with
    # exactly the Brewfile's `trusted:` entries on every run, so a manual
    # `brew trust` never survives an activation. Trust must be declared here.
    taps = [
      { name = "jnsahaj/lumen"; trusted = true; }
      { name = "pluk-inc/tap"; trusted = true; }
    ];

    # CLI tools that genuinely need brew (no Nix equivalent on darwin or version-pinned).
    # Everything else moved to nix/home-manager: see users/kyandesutter/programs.nix.
    brews = [
      "libadwaita" # NativeDesktop's GTK-on-macOS dev loop links brew GTK; cleanup="uninstall" kept wiping the imperative install
      "terminal-notifier" # nixpkgs 26.11 crashes in the Darwin linker (SIGTRAP)
      "watchman" # nixpkgs build pulls folly, which fails to compile on darwin
      "wireguard-tools"
      {
        # Obsidian LiveSync backend. Binds 127.0.0.1:5984 (CouchDB default);
        # exposed to the tailnet on 443 by modules/darwin/mixins/
        # obsidian-livesync-serve.nix. Config/init:
        # scripts/couchdb-livesync-init.sh (one-time).
        name = "couchdb";
        start_service = true;
        restart_service = "changed";
      }
    ];

    casks = [
      # (previously-declared casks)
      "betterdisplay"
      "bluebubbles" # BlueBubbles Server (iMessage bridge): macOS-only, this Mac is the host
      "clop"
      "codex" # agents call it over SSH; undeclared, cleanup="uninstall" would remove it
      "ghostty"
      "gstreamer-runtime"
      "nordvpn"
      "orbstack"
      "terminal-browser" # zenbu-labs: chromium in the terminal over the kitty graphics protocol; the Linux hosts take the release tarball (users/kyandesutter/mixins/cli/terminal-browser.nix)
      "the-unarchiver"

      # (newly imported from /Applications; previously imperative)
      "1password"
      "aldente"
      "android-studio"
      "google-chrome"
      "jump-desktop-connect"
      "markdown-preview"  # pluk-inc/tap
      "syncthing-app"

      # (remote desktop)
      # Also installed on both NixOS hosts (users/kyandesutter/mixins/apps/parsec.nix).
      # This Mac is the only one of the three that can act as a Parsec *host*:
      # Parsec has no Linux hosting support, so the laptops are clients.
      "parsec"

      # (fonts)
      # SF Pro Display Black, hardcoded as /Library/Fonts/SF-Pro-Display-Black.otf
      # by the aso-appstore-screenshots skill's compose.py. Not in nixpkgs; the
      # cask is a pkg artifact, so it lands system-wide rather than in
      # ~/Library/Fonts where font casks normally go.
      "font-sf-pro"

    ];

    # Mac App Store auto-install disabled: `mas install` is broken at the OS level (https://github.com/orgs/Homebrew/discussions/6550). Apps remain installed manually.
    masApps = { };
  };
}
