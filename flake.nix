{
  description = "Kyan's Nix Configuration";

  inputs = {
    # Core
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # NixOS and Darwin
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    # NixOS Spicetify
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Themes & Plugins
    catppuccin.url = "github:catppuccin/nix";
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
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nix-darwin,
    nix-homebrew,
    nixos-generators,
    home-manager,
    catppuccin,
    ...
  }: let
    # System types to support
    supportedSystems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];

    # Helper function to generate an attrset by mapping a function onto supportedSystems
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Define custom overlays
    overlays = [
      (final: prev: {
        vimPlugins =
          prev.vimPlugins
          // {
            own-auto-dark-mode = prev.vimUtils.buildVimPlugin {
              name = "auto-dark-mode.nvim";
              src = inputs.plugin-auto-dark-mode;
            };
            own-visual-whitespace = prev.vimUtils.buildVimPlugin {
              name = "visual-whitespace.nvim";
              src = inputs.plugin-visual-whitespace;
            };
            own-tidy = prev.vimUtils.buildVimPlugin {
              name = "tidy.nvim";
              src = inputs.plugin-tidy;
            };
            own-base16 = prev.vimUtils.buildVimPlugin {
              name = "base16.nvim";
              src = inputs.plugin-base16;
            };
            own-aider = prev.vimUtils.buildVimPlugin {
              name = "aider.nvim";
              src = inputs.plugin-aider;
            };
            own-bg = prev.vimUtils.buildVimPlugin {
              name = "bg.nvim";
              src = inputs.plugin-bg;
            };
          };
      })
    ];

    # Nixpkgs instantiated for supported systems with overlays
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = overlays;
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
      });

    # Common configuration shared across all systems
    mkCommonConfig = {
      username,
      hostname,
      system,
      ...
    }: {
      nixpkgs = {
        overlays = overlays;
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
      };
    };

    # Configuration for nixOS
    mkNixosConfig = {
      username,
      hostname,
      system,
      extraModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules =
          [
            # Add common Nixpkgs config
            {
              nixpkgs.overlays = overlays;
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.allowBroken = true;
            }
            ./hosts/${hostname}
            ./modules/nixos/default.nix
            home-manager.nixosModules.home-manager
            {
              networking.hostName = hostname;
              users.users.${username} = {
                isNormalUser = true;
                extraGroups = ["wheel" "networkmanager" "video" "audio"];
                shell = nixpkgs.legacyPackages.${system}.zsh;
                home = "/home/${username}";
              };

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = {inherit inputs;};
                users.${username} = {
                  imports = [
                    ./modules/common/home.nix
                    ./modules/nixos/home.nix
                    ./hosts/${hostname}/home.nix
                    catppuccin.homeModules.catppuccin
                  ];
                };
              };
            }
          ]
          ++ extraModules;
        specialArgs = {inherit inputs;};
      };

    # Configuration for macOS
    mkDarwinConfig = {
      username,
      hostname,
      system,
      extraModules ? [],
    }:
      nix-darwin.lib.darwinSystem {
        inherit system;
        modules =
          [
            # Add common Nixpkgs config
            {
              nixpkgs.overlays = overlays;
              nixpkgs.config.allowUnfree = true;
              nixpkgs.config.allowBroken = true;
            }
            ./hosts/${hostname}
            ./modules/darwin/default.nix
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
                    ./modules/common/home.nix
                    ./modules/darwin/home.nix
                    ./hosts/${hostname}/home.nix
                    catppuccin.homeModules.catppuccin
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
          ]
          ++ extraModules;
        specialArgs = {inherit inputs;};
      };
  in {
    darwinConfigurations = {
      # Your current macOS machine with both names for backward compatibility
      "FormalBook" = mkDarwinConfig {
        username = "kyandesutter";
        hostname = "macbook";
        system = "aarch64-darwin";
      };

      "macbook" = mkDarwinConfig {
        username = "kyandesutter";
        hostname = "macbook";
        system = "aarch64-darwin";
      };
    };

    nixosConfigurations = {
      # NixOS homelab
      "homelab" = mkNixosConfig {
        username = "kyandesutter";
        hostname = "homelab";
        system = "x86_64-linux";
      };
    };

    # Development shells for each platform
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            nixfmt
            nixpkgs-fmt
          ];
        };
      }
    );

    # Formatter for nix files
    formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);
  };
}
