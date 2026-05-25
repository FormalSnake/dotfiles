{
  homebrew = {
    taps = [
      "barutsrb/tap"
      "gcenx/wine"
      "jnsahaj/lumen"
      "nikitabobko/tap"
      "oven-sh/bun"
    ];

    brews = [
      "assimp"
      "bat"
      "btop"
      "chafa"
      "cloudflared"
      "cmake"
      "cocoapods"
      "coreutils"
      "couchdb"
      "deno"
      "dipc"
      "fastfetch"
      "fd"
      "ffmpeg"
      "fish"
      "fzf"
      "gh"
      "git"
      "git-filter-repo"
      "go"
      "imagemagick"
      "lazydocker"
      "lazygit"
      "libcaca"
      "libpq"
      "lua"
      "mas"
      "mosh"
      "neovim"
      "ninja"
      "node@24"
      "opencode"
      "poppler"
      "pyenv"
      "raylib"
      "rclone"
      "stow"
      "swiftformat"
      "swiftlint"
      "terminal-notifier"
      "tmux"
      "tree-sitter-cli"
      "tree-sitter@0.25"
      "uv"
      "watchman"
      "wget"
      "xcbeautify"
      "xcodegen"
      "yazi"
      "zoxide"
      # tap-qualified formulae
      "oven-sh/bun/bun"
      # Intentionally dropped (rustup already provides these):
      #   "rust"
    ];

    casks = [
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
      "google-drive"
      "gstreamer-runtime"
      "jordanbaird-ice"
      "karabiner-elements"
      "linearmouse"
      "logi-options+"
      "music-presence"
      "nordvpn"
      "obs"
      "obsidian"
      "opencode-desktop"
      "orbstack"
      "prismlauncher"
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
      "zulu@17"
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
