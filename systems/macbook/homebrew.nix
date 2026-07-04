{
  homebrew = {
    taps = [
      "barutsrb/tap"
      "jnsahaj/lumen"
      "pluk-inc/tap"
    ];

    # CLI tools that genuinely need brew (no Nix equivalent on darwin or version-pinned).
    # Everything else moved to nix/home-manager — see users/kyandesutter/programs.nix.
    brews = [
      "watchman" # nixpkgs build pulls folly, which fails to compile on darwin
      "wireguard-tools"
    ];

    casks = [
      # — previously-declared casks —
      "alcove"
      "audacity"
      "balenaetcher"
      "betterdisplay"
      "bluebubbles" # BlueBubbles Server (iMessage bridge) — macOS-only, this Mac is the host
      "claude"
      "clop"
      "docker-desktop"
      "epic-games"
      "equibop"
      "figma"
      "firefox"
      "ghostty"
      "github"
      "gstreamer-runtime"
      "karabiner-elements"
      "linearmouse"
      "music-presence"
      "nordvpn"
      "obs"
      "obsidian"
      "orbstack"
      "qmk-toolbox"
      "stats"
      "steam"
      "thaw"
      "the-unarchiver"
      "vlc"

      # — newly imported from /Applications (previously imperative) —
      "1password"
      "affinity"
      "aldente"
      "android-studio"
      "antigravity"
      "bambu-studio"
      "beeper"
      "codex"
      "eqmac"
      "google-chrome"
      "jump-desktop-connect"
      "markdown-preview"  # pluk-inc/tap
      "microsoft-teams"
      "modrinth"
      "moonlight"
      "mos"
      "notion"
      "qbittorrent"
      "roblox"
      "robloxstudio"
      "spotify"
      "syncthing-app"
      "t3-code"
      "wispr-flow"
    ];

    # Mac App Store auto-install disabled — `mas install` is broken at the OS level (https://github.com/orgs/Homebrew/discussions/6550); apps remain installed manually.
    masApps = { };
  };
}
