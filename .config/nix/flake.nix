{
  description = "Kyan's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
  };

  outputs = inputs @ { self, nix-darwin, nix-homebrew, nixpkgs, ... }: let
    configuration = { pkgs, config, ... }: let
      # Integrate spicetify packages for flakes.
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
    in {
      nixpkgs.config.allowUnfree = true;

      # System packages, homebrew settings, activation scripts, etc.
      environment.systemPackages = [
        pkgs.neovim
        pkgs.tmux
        pkgs.zoxide
        pkgs.bat
        pkgs.fzf
        pkgs.stow
        pkgs.aider-chat
        pkgs.chafa
        pkgs.btop
        pkgs.blueutil
        pkgs.nodejs
        pkgs.bun
        pkgs.lazygit
        pkgs.gh
        pkgs.cargo
        pkgs.devenv
        pkgs.go
        pkgs.zig
        pkgs.nixfmt-rfc-style
        pkgs.alejandra
        pkgs.raycast
        pkgs.yazi
        pkgs.ice-bar
        pkgs.aerospace
        pkgs.arrpc
        pkgs.nixd
        pkgs.ripgrep
        pkgs.lua
        pkgs.switchaudio-osx
        pkgs.nowplaying-cli
        pkgs.the-unarchiver
        pkgs.google-chrome
        pkgs.supabase-cli
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
          "bleunlock"
          "darkmodebuddy"
          "dockey"
          "zerotier-one"
          "httpie"
          "balenaetcher"
          "flux"
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
      in pkgs.lib.mkForce ''
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
        dock.orientation = "bottom";
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
          adblockify
          hidePodcasts
          shuffle
        ];
        theme = spicePkgs.themes.hazy;
      };
    };
  in {
    darwinConfigurations."FormalBook" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        # Import the spicetify module from spicetify-nix:
        inputs.spicetify-nix.nixosModules.spicetify
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "kyandesutter";
            autoMigrate = true;
          };
        }
      ];
    };
  };
}
