{
  description = "Kyan's Nix Configuration";

  inputs = {
    # Core
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # System management
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Themes & Integrations
    catppuccin.url = "github:catppuccin/nix";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    nixcord.url = "github:kaylorben/nixcord";

    # Neovim plugins
    plugin-auto-dark-mode = {
      url = "github:f-person/auto-dark-mode.nvim";
      flake = false;
    };
    plugin-visual-whitespace = {
      url = "github:mcauley-penney/visual-whitespace.nvim";
      flake = false;
    };
    plugin-tidy = {
      url = "github:mcauley-penney/tidy.nvim";
      flake = false;
    };
    plugin-base16 = {
      url = "github:RRethy/base16-nvim";
      flake = false;
    };
    plugin-aider = {
      url = "github:GeorgesAlkhouri/nvim-aider";
      flake = false;
    };
    plugin-bg = {
      url = "github:typicode/bg.nvim";
      flake = false;
    };
    plugin-transparent = {
      url = "github:tribela/transparent.nvim";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nix-darwin,
    nix-homebrew,
    home-manager,
    catppuccin,
    ...
  }: let
    # System configuration
    supportedSystems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Import overlays
    overlays = import ./overlays {inherit inputs;};

    # Common nixpkgs configuration
    nixpkgsConfig = {
      overlays = overlays;
      config = {
        allowUnfree = true;
        allowBroken = true;
      };
    };

    # Common Nix settings
    nixSettings = {
      experimental-features = ["nix-command" "flakes"];
    };

    # NixOS system configuration
    mkNixosConfig = {
      username,
      hostname,
      system,
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules = [
          {
            nixpkgs = nixpkgsConfig;
            nix.settings = nixSettings;
            nix.optimise.automatic = true;
          }
          ./hosts/${hostname}

          home-manager.nixosModules.home-manager
          {
            networking.hostName = hostname;
            users.users.${username} = {
              isNormalUser = true;
              extraGroups = ["wheel" "networkmanager" "video" "audio"];
              shell = nixpkgs.legacyPackages.${system}.fish;
              home = "/home/${username}";
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {inherit inputs;};
              users.${username} = {
                imports = [
                  ./modules/home-manager/common
                  ./home/${username}/${hostname}
                  catppuccin.homeModules.catppuccin
                  inputs.spicetify-nix.homeManagerModules.default
                  inputs.nixcord.homeModules.nixcord
                ];
              };
            };
          }
        ];
      };

    # macOS system configuration
    mkDarwinConfig = {
      username,
      hostname,
      system,
    }:
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules = [
          {
            nixpkgs = nixpkgsConfig;
            nix.settings = nixSettings;
            nix.optimise.automatic = true;
          }
          ./hosts/${hostname}

          home-manager.darwinModules.home-manager
          {
            networking.hostName = hostname;
            users.users.${username} = {
              name = username;
              home = "/Users/${username}";
            };

            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {inherit inputs;};
              users.${username} = {
                imports = [
                  ./modules/home-manager/common
                  ./home/${username}/${hostname}
                  catppuccin.homeModules.catppuccin
                  inputs.spicetify-nix.homeManagerModules.default
                  inputs.nixcord.homeModules.nixcord
                ];
              };
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
  in {
    # System configurations
    nixosConfigurations = {
      homelab = mkNixosConfig {
        username = "kyandesutter";
        hostname = "homelab";
        system = "x86_64-linux";
      };
    };

    darwinConfigurations = {
      macbook = mkDarwinConfig {
        username = "kyandesutter";
        hostname = "macbook";
        system = "aarch64-darwin";
      };
    };

    # Development environments
    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          git
          nixfmt-classic
          nixpkgs-fmt
          alejandra
        ];
        shellHook = ''
          echo "🚀 Nix development environment loaded!"
          echo "Available formatters: nixfmt-classic, nixpkgs-fmt, alejandra"
        '';
      };
    });

    # Code formatting
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
