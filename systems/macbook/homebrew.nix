{
  homebrew = {
    taps = [
      "barutsrb/tap"
      "jnsahaj/lumen"
      "nikitabobko/tap"
    ];

    # CLI tools that genuinely need brew (no Nix equivalent on darwin or version-pinned).
    # Everything else moved to nix/home-manager — see users/kyandesutter/programs.nix.
    brews = [
      "tree-sitter@0.25" # version pin; nixpkgs only ships current
      "watchman"         # nixpkgs build pulls folly, which fails to compile on darwin
    ];

    casks = [
      # — previously-declared casks —
      "1password-cli"
      "alcove"
      "audacity"
      "balenaetcher"
      "betterdisplay"
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
      "microsoft-teams"
      "modrinth"
      "moonlight"
      "notion"
      "qbittorrent"
      "roblox"
      "robloxstudio"
      "spotify"
      "syncthing-app"
      "t3-code"
      "wispr-flow"
    ];

    # Mac App Store apps — managed via `mas`. Add/remove IDs here to install/uninstall.
    masApps = {
      "CrystalFetch"         = 6454431289;
      "DaisyDisk"            =  411643860;
      "Flighty"              = 1358823008;
      "Klack"                = 6446206067;
      "Microsoft Excel"      =  462058435;
      "Microsoft PowerPoint" =  462062816;
      "Microsoft Word"       =  462054704;
      "Tailscale"            = 1475387142;
      "WhatsApp"             =  310633997;
      "Xcode"                =  497799835;
    };
  };
}
