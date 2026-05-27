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
      "watchman" # nixpkgs build pulls folly, which fails to compile on darwin
    ];

    casks = [
      # — previously-declared casks —
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

    # Mac App Store apps — declaration disabled.
    #
    # Upstream brew bundle uses `mas install` which was broken at the OS level
    # in macOS 26.1 / 15.7.2 / 14.8.2 (Apple-only entitlement now required to
    # talk to installd):
    #   https://github.com/orgs/Homebrew/discussions/6550
    # And separately tracked by:
    #   https://github.com/Homebrew/brew/issues/21559 (mas install → mas get)
    #   https://github.com/Homebrew/homebrew-bundle/issues/370
    #
    # Apps are still installed at the OS level — re-enable once upstream lands
    # the `mas get` switch.
    masApps = { };
    # masApps = {
    #   "CrystalFetch"         = 6454431289;
    #   "DaisyDisk"            =  411643860;
    #   "Flighty"              = 1358823008;
    #   "Klack"                = 6446206067;
    #   "Microsoft Excel"      =  462058435;
    #   "Microsoft PowerPoint" =  462062816;
    #   "Microsoft Word"       =  462054704;
    #   "Tailscale"            = 1475387142;
    #   "WhatsApp"             =  310633997;
    #   "Xcode"                =  497799835;
    # };
  };
}
