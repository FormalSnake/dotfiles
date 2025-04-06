{
  description = "Kyan's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix";
    plugin-auto-dark-mode.url = "github:f-person/auto-dark-mode.nvim";
    plugin-auto-dark-mode.flake = false;
    plugin-visual-whitespace.url = "github:mcauley-penney/visual-whitespace.nvim";
    plugin-visual-whitespace.flake = false;
    plugin-tidy.url = "github:mcauley-penney/tidy.nvim";
    plugin-tidy.flake = false;
    plugin-base16.url = "github:RRethy/base16-nvim";
    plugin-base16.flake = false;
    plugin-aider.url = "github:GeorgesAlkhouri/nvim-aider";
    plugin-aider.flake = false;
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nix-homebrew,
    nixpkgs,
    home-manager,
    catppuccin,
    ...
  }: let
    username = "kyandesutter";
    configuration = {
      pkgs,
      config,
      ...
    }: {
      users = {
        users.${username} = {
          home = "/Users/${username}";
          name = "${username}";
        };
      };

      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = [
        pkgs.fzf
        pkgs.ripgrep
        pkgs.fd
        pkgs.nodejs
        pkgs.bun
        pkgs.gh
        pkgs.cargo
        pkgs.rustc
        pkgs.devenv
        pkgs.go
        pkgs.zig
        pkgs.nixd
        pkgs.lua
        pkgs.bat
        pkgs.chafa
      ];

      homebrew = {
        enable = true;
        casks = [
          "ghostty"
          "notion"
          "notion-calendar"
          "clop"
          "figma"
          "ubersicht"
          "zerotier-one"
          "httpie"
          "balenaetcher"
          "flux"
          "legcord"
          "cloudflare-warp"
          "whatsapp"
          "slack"
          "jordanbaird-ice"
          "betterdisplay"
          "steam"
        ];
        brews = [
          "geometry"
          "jnsahaj/lumen/lumen"
          "imagemagick"
          "docker"
          "lazydocker"
          "defaultbrowser"
          "docker-compose"
          "docker-credential-helper"
          "couchdb"
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
          "${pkgs.brave}/Applications/Brave Browser.app"
          "/Applications/Ghostty.app"
          "/System/Applications/Calendar.app"
          "/Applications/Notion.app"
          "/Applications/Notion Mail.app"
          "/Applications/Legcord.app"
          "/Applications/Spotify.app"
        ];
        finder.FXPreferredViewStyle = "clmv";
        loginwindow.GuestEnabled = false;
        screencapture.location = "~/Pictures/screenshots";
        screensaver.askForPasswordDelay = 10;
        NSGlobalDomain.AppleICUForce24HourTime = true;
        NSGlobalDomain.AppleInterfaceStyle = "Dark";
      };

      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
      };

      nix.settings.experimental-features = "nix-command flakes";

      security.pam.services.sudo_local.touchIdAuth = true;

      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 5;
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in {
    darwinConfigurations."FormalBook" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${username} = {
              imports = [
                ./home.nix
                catppuccin.homeModules.catppuccin
              ];
            };
            extraSpecialArgs = {inherit inputs;};
          };
        }
        nix-homebrew.darwinModules.nix-homebrew
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
