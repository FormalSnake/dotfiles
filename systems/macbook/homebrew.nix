{
  homebrew = {
    taps = [
      "barutsrb/tap"
      "felixkratz/formulae" # sketchybar
      "jnsahaj/lumen"
      "pluk-inc/tap"
    ];

    # CLI tools that genuinely need brew (no Nix equivalent on darwin or version-pinned).
    # Everything else moved to nix/home-manager — see users/kyandesutter/programs.nix.
    brews = [
      "sketchybar" # felixkratz/formulae — nixpkgs' build crashes the cctools linker; drives the OmniWM bar (users/kyandesutter/mixins/sketchybar.nix)
      "terminal-notifier" # nixpkgs 26.11 crashes in the Darwin linker (SIGTRAP)
      "watchman" # nixpkgs build pulls folly, which fails to compile on darwin
      "wireguard-tools"
      {
        # Obsidian LiveSync backend. Binds 127.0.0.1:5984 (CouchDB default);
        # exposed to the tailnet via `tailscale serve` only. Config/init:
        # scripts/couchdb-livesync-init.sh (one-time).
        name = "couchdb";
        start_service = true;
        restart_service = "changed";
      }
    ];

    casks = [
      # — previously-declared casks —
      "alcove"
      "balenaetcher"
      "betterdisplay"
      "bluebubbles" # BlueBubbles Server (iMessage bridge) — macOS-only, this Mac is the host
      "clop"
      "docker-desktop"
      "firefox"
      "ghostty"
      "gstreamer-runtime"
      "nordvpn"
      "orbstack"
      "stats"
      "thaw"
      "the-unarchiver"

      # — newly imported from /Applications (previously imperative) —
      "1password"
      "aldente"
      "android-studio"
      "codex"
      "google-chrome"
      "jump-desktop-connect"
      "markdown-preview"  # pluk-inc/tap
      "syncthing-app"

      # — tiling WM (mirrors the g815 niri setup) —
      "omniwm"             # barutsrb/tap — niri-style tiler (tap trusted automatically; see modules/darwin/mixins/homebrew.nix)
      "karabiner-elements" # remaps Right Command → the OmniWM "Super" chord (Ctrl+Opt+Cmd)
    ];

    # Mac App Store auto-install disabled — `mas install` is broken at the OS level (https://github.com/orgs/Homebrew/discussions/6550); apps remain installed manually.
    masApps = { };
  };
}
