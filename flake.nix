{
  description = "Kyan's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    plugin-auto-dark-mode.url = "github:f-person/auto-dark-mode.nvim";
    plugin-auto-dark-mode.flake = false;
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nix-homebrew,
    nixpkgs,
    home-manager,
    ...
  }: let
    username = "kyandesutter";
    configuration = {
      pkgs,
      config,
      ...
    }: let
      # Integrate spicetify packages for flakes.
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
    in {
      users = {
        users.${username} = {
          home = "/Users/${username}";
          name = "${username}";
        };
      };

      nixpkgs.config.allowUnfree = true;

      # System packages, homebrew settings, activation scripts, etc.
      environment.systemPackages = [
        # Navigation and Search
        pkgs.zoxide # Smarter 'cd' command for quick navigation
        pkgs.fzf # Command-line fuzzy finder for interactive search
        pkgs.ripgrep # Fast search tool for searching text within files
        pkgs.fd # Simple, fast, user-friendly alternative to 'find'

        # Development Tools
        pkgs.nodejs # JavaScript runtime built on Chrome's V8 engine
        pkgs.bun # All-in-one JavaScript runtime
        pkgs.lazygit # Simple terminal UI for git commands
        pkgs.gh # GitHub CLI tool
        pkgs.cargo # Rust package manager and build system
        pkgs.devenv # Development environment manager
        pkgs.go # Go programming language
        pkgs.zig # Zig programming language
        pkgs.nixd # Nix development tool
        pkgs.lua # Lightweight, embeddable scripting language

        # System Utilities
        pkgs.bat # Enhanced 'cat' command with syntax highlighting
        pkgs.chafa # Terminal image viewer and converter
        pkgs.btop # Resource monitor for system performance
        # pkgs.blueutil # Bluetooth utility for macOS
        # pkgs.switchaudio-osx # macOS utility to switch audio sources
        # pkgs.nowplaying-cli # Command-line tool to display currently playing media
      ];

      homebrew = {
        enable = true;
        casks = [
          "ghostty"
          "firefox"
          "notion"
          "notion-calendar"
          "clop"
          "figma"
          "ubersicht"
          "darkmodebuddy"
          "dockey"
          "zerotier-one"
          "httpie"
          "balenaetcher"
          "flux"
          "legcord"
        ];
        brews = [
          "geometry"
          "romkatv/gitstatus/gitstatus"
          "jnsahaj/lumen/lumen"
          "imagemagick"
        ];
        onActivation.cleanup = "zap";
        onActivation.autoUpdate = true;
        onActivation.upgrade = true;
      };

      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read -r src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';

      system.defaults = {
        dock.autohide = true;
        dock.orientation = "right";
        dock.show-recents = false;
        dock.showhidden = true;
        dock.mru-spaces = false;
        dock.persistent-apps = [
          # "/Applications/Google Chrome.app"
          "${pkgs.google-chrome}/Applications/Google Chrome.app"
          "/Applications/Ghostty.app"
          "/System/Applications/Calendar.app"
          "/Applications/Notion.app"
          "/Applications/Notion Mail.app"
          "/Applications/Legcord.app"
          "${config.programs.spicetify.spicedSpotify}/Applications/Spotify.app"
        ];
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled = false;
        screencapture.location = "~/Pictures/screenshots";
        screensaver.askForPasswordDelay = 10;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
      };

      # Enable flakes and necessary daemon settings.
      nix.settings.experimental-features = "nix-command flakes";
      # services.nix-daemon.enable = true;
      # nix.configureBuildUsers = true;
      # nix.useDaemon = true;

      programs.zsh.enable = true;
      # security.pam.enableSudoTouchIdAuth = true;
      security.pam.services.sudo_local.touchIdAuth = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 5;
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Spicetify integration.
      programs.spicetify = {
        enable = true;
        enabledExtensions = with spicePkgs.extensions; [
          # beautifulLyrics
          # hidePodcasts
          shuffle
        ];
        enabledCustomApps = with spicePkgs.apps; [
          newReleases
        ];
        enabledSnippets = with spicePkgs.snippets; [
          # smooth-progress-bar
          smoothProgressBar
          autoHideFriends
          # roundedNowPlayingBar
          roundedImages
          roundedButtons
        ];
        # theme = spicePkgs.themes.starryNight;
        # colorScheme = "macchiato";
      };
    };
  in {
    darwinConfigurations."FormalBook" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            # useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${username} = import ./home.nix;
            extraSpecialArgs = {inherit inputs;};
          };
          # home-manager.useGlobalPkgs = true;
          # home-manager.useUserPackages = true;
          # home-manager.users.kyandesutter = import ./home.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
        }
        nix-homebrew.darwinModules.nix-homebrew
        # Import the spicetify module from spicetify-nix:
        inputs.spicetify-nix.nixosModules.spicetify
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = username;
            autoMigrate = true;
          };
        }
      ];
    };
  };
}
