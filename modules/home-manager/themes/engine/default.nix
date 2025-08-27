{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.themes;
  inherit (lib) mkOption mkEnableOption mkIf types;

  # Function to get current theme at runtime, fallback to config default
  getCurrentTheme = 
    if builtins.pathExists "${config.home.homeDirectory}/.config/nix-themes/current" 
    then lib.removeSuffix "\n" (builtins.readFile "${config.home.homeDirectory}/.config/nix-themes/current")
    else cfg.current;

  themeType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Theme display name";
      };
      
      colors = mkOption {
        type = types.submodule {
          options = {
            background = mkOption { type = types.str; };
            foreground = mkOption { type = types.str; };
            surface0 = mkOption { type = types.str; };
            surface1 = mkOption { type = types.str; };
            surface2 = mkOption { type = types.str; };
            overlay0 = mkOption { type = types.str; };
            overlay1 = mkOption { type = types.str; };
            overlay2 = mkOption { type = types.str; };
            text = mkOption { type = types.str; };
            subtext0 = mkOption { type = types.str; };
            subtext1 = mkOption { type = types.str; };
            red = mkOption { type = types.str; };
            green = mkOption { type = types.str; };
            blue = mkOption { type = types.str; };
            yellow = mkOption { type = types.str; };
            orange = mkOption { type = types.str; };
            pink = mkOption { type = types.str; };
            purple = mkOption { type = types.str; };
            teal = mkOption { type = types.str; };
            sky = mkOption { type = types.str; };
            sapphire = mkOption { type = types.str; };
            lavender = mkOption { type = types.str; };
            mauve = mkOption { type = types.str; };
          };
        };
      };

      neovim = mkOption {
        type = types.submodule {
          options = {
            plugin = mkOption { 
              type = types.package; 
              description = "Neovim theme plugin package"; 
            };
            colorscheme = mkOption { 
              type = types.str; 
              description = "Colorscheme name to set in neovim"; 
            };
          };
        };
      };

      ghostty = mkOption {
        type = types.submodule {
          options = {
            theme = mkOption { 
              type = types.str; 
              description = "Ghostty theme name"; 
            };
          };
        };
      };

      btop = mkOption {
        type = types.submodule {
          options = {
            theme = mkOption { 
              type = types.str; 
              description = "Btop theme content"; 
            };
          };
        };
      };

      fish = mkOption {
        type = types.submodule {
          options = {
            colors = mkOption {
              type = types.attrsOf types.str;
              description = "Fish shell color configuration";
            };
          };
        };
      };

      wallpapers = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "List of wallpaper paths for this theme";
      };
    };
  };
in {
  options.themes = {
    enable = mkEnableOption "theme engine";
    
    current = mkOption {
      type = types.str;
      default = "catppuccin";
      description = "Currently active theme";
    };

    available = mkOption {
      type = types.attrsOf themeType;
      default = {};
      description = "Available themes";
    };
  };

  config = mkIf cfg.enable {
    # Create theme state directory
    home.file.".config/nix-themes/current".text = cfg.current;
    
    # Export current theme colors as environment variables
    home.sessionVariables = let
      currentTheme = cfg.available.${cfg.current};
      colors = currentTheme.colors;
    in {
      THEME_BACKGROUND = colors.background;
      THEME_FOREGROUND = colors.foreground;
      THEME_RED = colors.red;
      THEME_GREEN = colors.green;
      THEME_BLUE = colors.blue;
      THEME_YELLOW = colors.yellow;
      THEME_ORANGE = colors.orange;
      THEME_PINK = colors.pink;
      THEME_PURPLE = colors.purple;
      THEME_TEAL = colors.teal;
      THEME_CURRENT = cfg.current;
    };

    # Theme switching script
    home.packages = [
      (pkgs.writeShellScriptBin "nix-theme-set" ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        if [[ $# -ne 1 ]]; then
          echo "Usage: nix-theme-set <theme-name>"
          echo "Available themes: ${lib.concatStringsSep ", " (lib.attrNames cfg.available)}"
          exit 1
        fi
        
        THEME="$1"
        AVAILABLE_THEMES="${lib.concatStringsSep " " (lib.attrNames cfg.available)}"
        
        if [[ ! " $AVAILABLE_THEMES " =~ " $THEME " ]]; then
          echo "Theme '$THEME' not found."
          echo "Available themes: ${lib.concatStringsSep ", " (lib.attrNames cfg.available)}"
          exit 1
        fi
        
        echo "Switching to theme: $THEME"
        
        # Create theme config directory if it doesn't exist (with proper permissions)
        if [[ ! -d ~/.config/nix-themes ]]; then
          sudo mkdir -p ~/.config/nix-themes
          sudo chown $(whoami):$(id -gn) ~/.config/nix-themes
        fi
        
        # Update current theme file
        echo "$THEME" > ~/.config/nix-themes/current
        
        # Update environment for current session
        export THEME_CURRENT="$THEME"
        
        echo "Theme switched to $THEME!"
        echo "Rebuild your Nix configuration to fully apply the theme:"
        echo "  darwin-rebuild switch --flake .#macbook"
      '')
      
      (pkgs.writeShellScriptBin "nix-theme-current" ''
        #!/usr/bin/env bash
        if [[ -f ~/.config/nix-themes/current ]]; then
          cat ~/.config/nix-themes/current
        else
          echo "${cfg.current}"
        fi
      '')
      
      (pkgs.writeShellScriptBin "nix-theme-list" ''
        #!/usr/bin/env bash
        echo "Available themes:"
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: theme: "echo '  ${name} - ${theme.name}'") cfg.available)}
        echo ""
        echo "Current theme: $(nix-theme-current)"
      '')
    ];
  };
}