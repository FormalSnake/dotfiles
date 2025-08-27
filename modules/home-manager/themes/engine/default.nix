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

      tmux = mkOption {
        type = types.submodule {
          options = {
            config = mkOption { 
              type = types.str; 
              description = "Tmux theme configuration"; 
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
    # Create theme files
    home.file = lib.mkMerge [
      # Theme state directory
      {".config/nix-themes/current".text = cfg.current;}
      
      # Individual theme directories with all theme files
      (lib.mkMerge (lib.mapAttrsToList (themeName: themeConfig: {
        # Ghostty theme reference
        ".config/nix-themes/themes/${themeName}/ghostty".text = themeConfig.ghostty.theme;
        
        # Btop theme file
        ".config/nix-themes/themes/${themeName}/btop.theme".text = themeConfig.btop.theme;
        
        # Fish colors script
        ".config/nix-themes/themes/${themeName}/fish.fish".text = 
          lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "set -g ${name} ${value}") themeConfig.fish.colors);
        
        # Tmux theme file  
        ".config/nix-themes/themes/${themeName}/tmux.conf".text = themeConfig.tmux.config;
        
        # Neovim colorscheme reference
        ".config/nix-themes/themes/${themeName}/neovim".text = themeConfig.neovim.colorscheme;
      }) cfg.available))
    ];
    
    # Theme management scripts
    home.packages = [
      (pkgs.writeShellScriptBin "get-current-theme" ''
        if [[ -f ~/.config/nix-themes/current ]]; then
          cat ~/.config/nix-themes/current | tr -d '\n'
        else
          echo "${cfg.current}"
        fi
      '')
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
        
        # Create symlinks to current theme (Omarchy-style)
        THEME_DIR=~/.config/nix-themes/themes/$THEME
        
        # Create symlinks for each application
        ln -nsf "$THEME_DIR/ghostty" ~/.config/nix-themes/current-ghostty
        ln -nsf "$THEME_DIR/btop.theme" ~/.config/btop/themes/current.theme
        ln -nsf "$THEME_DIR/fish.fish" ~/.config/fish/current-theme.fish
        ln -nsf "$THEME_DIR/tmux.conf" ~/.config/tmux/current-theme.conf
        ln -nsf "$THEME_DIR/neovim" ~/.config/nix-themes/current-neovim
        
        # Update environment for current session
        export THEME_CURRENT="$THEME"
        
        echo "Theme switched to $THEME!"
        echo "Symlinks created for dynamic theme loading."
        echo "Some applications may need restart to pick up new theme."
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