{
  description = "Kyan's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nix-homebrew,
    nixpkgs,
  }: let
    configuration = {
      pkgs,
      config,
      ...
    }: {
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [
        # Text Editors
        pkgs.neovim # Advanced text editor based on Vim

        # Shell Utilities
        pkgs.mkalias # Create shell aliases
        pkgs.tmux # Terminal multiplexer
        pkgs.zoxide # Fast directory jumper
        pkgs.bat # A cat clone with syntax highlighting
        pkgs.fzf # Command-line fuzzy finder
        pkgs.stow # Symlink farm manager
        pkgs.ripgrep # Fast search tool like grep
        pkgs.fd # Simple, fast, and user-friendly alternative to find
        pkgs.direnv # Environment switcher for shell
        pkgs.aider-chat # Chat-like interface for terminal
        pkgs.chafa # Terminal graphics generator
        pkgs.btop # Resource monitor
        pkgs.blueutil # Bluetooth utility

        # Development Tools
        pkgs.nodejs # JavaScript runtime
        pkgs.bun # All-in-one JavaScript runtime
        pkgs.lazygit # Simple terminal UI for git commands
        pkgs.lazydocker # Simple terminal UI for Docker
        pkgs.gh # GitHub CLI
        pkgs.cargo # Rust package manager
        pkgs.devenv # Developer environment manager
        pkgs.go # Go programming language
        pkgs.zig # Zig programming language
        pkgs.esbuild # JavaScript bundler
        pkgs.vercel-pkg # pkg

        # Formatting and Code Style
        pkgs.nixfmt-rfc-style # Nix code formatter
        pkgs.alejandra # Nix code formatter

        # Productivity Tools
        pkgs.obsidian # Note-taking and knowledge management
        pkgs.raycast # Launcher for productivity
        pkgs.yazi # File manager
        pkgs.ice-bar # Menu bar enhancement

        # Media and Entertainment
        pkgs.youtube-music # YouTube Music client

        # Miscellaneous
        pkgs.uv # A package manager for python 
        pkgs.aerospace # i3 like window manager for mac
        pkgs.arrpc # Discord RPC client
      ];

      homebrew = {
        enable = true;
        casks = [
          "ghostty"
          # "hammerspoon"
          "firefox"
          "google-chrome"
          "the-unarchiver"
          "notion"
          "notion-calendar"
          "clop"
          "figma"
        ];
        brews = [
          "geometry"
          "romkatv/gitstatus/gitstatus"
          "jnsahaj/lumen/lumen"
          "imagemagick"
          "FelixKratz/formulae/borders"
          "chase/tap/awrit"
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
          # Set up applications.
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
        dock.orientation = "left";
        dock.show-recents = false;
        dock.showhidden = true;
        dock.mru-spaces = false;
        dock.persistent-apps = [
          "/Applications/Formalsurf.app"
          "/Applications/Zen Browser.app"
          "/Applications/Ghostty.app"
          "/Applications/Vesktop.app"
          "${pkgs.obsidian}/Applications/Obsidian.app"
          "${pkgs.youtube-music}/Applications/YouTube Music.app"
        ];
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled = false;
        screencapture.location = "~/Pictures/screenshots";
        screensaver.askForPasswordDelay = 10;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
      };

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";
      services.nix-daemon.enable = true;

      nix.configureBuildUsers = true;
      nix.useDaemon = true;

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;
      programs.zsh.enable = true;
      security.pam.enableSudoTouchIdAuth = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#Kyan
    darwinConfigurations."Kyan" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;

            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = true;

            # User owning the Homebrew prefix
            user = "kyandesutter";

            # Automatically migrate existing Homebrew installations
            autoMigrate = true;
          };
        }
      ];
    };
  };
}
