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
        pkgs.neovim
        pkgs.mkalias
        pkgs.tmux
        pkgs.obsidian
        pkgs.nixfmt-rfc-style
        pkgs.nodejs
        pkgs.bun
        pkgs.ice-bar
        pkgs.zoxide
        pkgs.bat
        pkgs.fzf
        pkgs.raycast
        pkgs.stow
        pkgs.yazi
        pkgs.youtube-music
        pkgs.fastfetch
        pkgs.lazygit
        pkgs.lazydocker
        pkgs.gh
        pkgs.alejandra
        pkgs.cargo
        pkgs.devenv
        pkgs.direnv
        pkgs.go
        pkgs.ripgrep
        pkgs.fd
        pkgs.uv
        pkgs.aider-chat
      ];

      homebrew = {
        enable = true;
        casks = [
          "ghostty"
          "hammerspoon"
          "firefox"
          "google-chrome"
          "the-unarchiver"
          "aerospace"
          "notion"
          "notion-calendar"
          "clop"
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
