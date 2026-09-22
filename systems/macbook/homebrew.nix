{
  homebrew = {
    # Homebrew 6 tap trust: `brew bundle` REPLACES ~/.homebrew/trust.json with
    # exactly the Brewfile's `trusted:` entries on every run, so a manual
    # `brew trust` never survives an activation. Trust must be declared here.
    taps = [
      { name = "abue-ammar/tinycast"; trusted = true; }
      { name = "barutsrb/tap"; trusted = true; }
      { name = "felixkratz/formulae"; trusted = true; } # sketchybar
      { name = "jnsahaj/lumen"; trusted = true; }
      { name = "pluk-inc/tap"; trusted = true; }
    ];

    # CLI tools that genuinely need brew (no Nix equivalent on darwin or version-pinned).
    # Everything else moved to nix/home-manager: see users/kyandesutter/programs.nix.
    brews = [
      "libadwaita" # NativeDesktop's GTK-on-macOS dev loop links brew GTK; cleanup="uninstall" kept wiping the imperative install
      "sketchybar" # felixkratz/formulae: nixpkgs' build crashes the cctools linker; drives the OmniWM bar (users/kyandesutter/mixins/sketchybar.nix)
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
      "alcove"
      "balenaetcher"
      "betterdisplay"
      "bluebubbles" # BlueBubbles Server (iMessage bridge): macOS-only, this Mac is the host
      "clop"
      "docker-desktop"
      "firefox"
      "ghostty"
      "gstreamer-runtime"
      "nordvpn"
      "orbstack"
      "stats"
      "terminal-browser" # zenbu-labs: chromium in the terminal over the kitty graphics protocol; the Linux hosts take the release tarball (users/kyandesutter/mixins/terminal-browser.nix)
      "thaw"
      "the-unarchiver"

      # (newly imported from /Applications; previously imperative)
      "1password"
      "aldente"
      "android-studio"
      "codex"
      "google-chrome"
      "jump-desktop-connect"
      "markdown-preview"  # pluk-inc/tap
      "syncthing-app"

      # (remote desktop)
      # Also installed on both NixOS hosts (users/kyandesutter/mixins/parsec.nix).
      # This Mac is the only one of the three that can act as a Parsec *host*:
      # Parsec has no Linux hosting support, so the laptops are clients.
      "parsec"

      # (fonts)
      # SF Pro Display Black, hardcoded as /Library/Fonts/SF-Pro-Display-Black.otf
      # by the aso-appstore-screenshots skill's compose.py. Not in nixpkgs; the
      # cask is a pkg artifact, so it lands system-wide rather than in
      # ~/Library/Fonts where font casks normally go.
      "font-sf-pro"

      # (tiling WM; mirrors the g815 niri setup)
      "omniwm"             # barutsrb/tap: niri-style tiler (tap trusted automatically, see modules/darwin/mixins/homebrew.nix)
      "karabiner-elements" # remaps Right Command → the OmniWM "Super" chord (Ctrl+Opt+Cmd)

      # (launcher)
      # Replaced Raycast Beta, which was a manual /Applications install. The
      # arm64 cask needs macOS 26+; it strips the quarantine flag itself since
      # the app is self-signed. Started at login by modules/darwin/mixins/login-items.nix.
      "tinycast"           # abue-ammar/tinycast
    ];

    # Mac App Store auto-install disabled: `mas install` is broken at the OS level (https://github.com/orgs/Homebrew/discussions/6550). Apps remain installed manually.
    masApps = { };
  };
}
