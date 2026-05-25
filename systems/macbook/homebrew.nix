{
  homebrew = {
    taps = [
      "barutsrb/tap"
      "gcenx/wine"
      "jnsahaj/lumen"
      "nikitabobko/tap"
    ];

    # CLI tools that genuinely need brew (no Nix equivalent on darwin or version-pinned).
    # Everything else moved to nix/home-manager — see users/kyandesutter/programs.nix.
    brews = [
      "couchdb"          # not packaged for darwin in nixpkgs
      "tree-sitter@0.25" # version pin; nixpkgs only ships current
      "watchman"         # nixpkgs build pulls folly, which fails to compile on darwin
    ];

    casks = [
      # — previously-declared casks —
      "1password-cli"
      "aerospace"
      "alcove"
      "appcleaner"
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
      "utm"
      "vesktop"
      "vlc"
      "warp"
      "zerotier-one"

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
      "Keynote"              =  409183694;
      "Klack"                = 6446206067;
      "Microsoft Excel"      =  462058435;
      "Microsoft PowerPoint" =  462062816;
      "Microsoft Word"       =  462054704;
      "Perplexity"           = 6714467650;
      "Steam Link"           = 1246969117;
      "Tailscale"            = 1475387142;
      "wBlock"               = 6746388723;
      "WhatsApp"             =  310633997;
      "WireGuard"            = 1451685025;
      "Xcode"                =  497799835;
    };
  };
}
