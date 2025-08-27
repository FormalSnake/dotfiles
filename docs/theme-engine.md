# Nix Theme Engine

A comprehensive theme management system for your Nix configuration that provides consistent theming across all applications.

## Overview

The theme engine allows you to easily switch between different color themes (Catppuccin, Everforest, Nord, etc.) across all your applications with a single command. Unlike traditional theme systems that require manual configuration of each application, this system:

- **Centralized Management**: Define themes once, apply everywhere
- **Instant Switching**: Change themes without rebuilding (where possible)
- **Consistent Colors**: Maintains visual consistency across all applications
- **Easy Extension**: Simple to add new themes or applications

## Supported Applications

Currently themed applications:
- **Neovim**: Automatic plugin installation and colorscheme setting
- **Ghostty**: Terminal theme switching
- **btop**: System monitor color schemes
- **Fish Shell**: Shell prompt and syntax highlighting colors

## Available Themes

### Catppuccin Mocha
- **Plugin**: `catppuccin-nvim`
- **Colors**: Dark purple-tinted theme with warm accents
- **Ghostty**: `catppuccin-mocha`

### Everforest Dark
- **Plugin**: `everforest` 
- **Colors**: Forest green-inspired dark theme
- **Ghostty**: `Everforest Dark - Hard`

### Nord
- **Plugin**: `nord-nvim`
- **Colors**: Arctic blue-inspired theme
- **Ghostty**: `nord`

## Usage

### Theme Management Commands

```bash
# List all available themes
nix-theme-list

# Check current theme
nix-theme-current

# Switch to a different theme
nix-theme-set <theme-name>
```

### Example Usage

```bash
# Switch to Nord theme
nix-theme-set nord

# Apply changes with system rebuild
darwin-rebuild switch --flake .#macbook

# Switch to Everforest
nix-theme-set everforest

# Apply changes
darwin-rebuild switch --flake .#macbook
```

## Theme Architecture

### File Structure
```
modules/home-manager/themes/
├── engine/
│   └── default.nix          # Core theme engine logic
└── definitions/
    ├── default.nix          # Theme registry
    ├── catppuccin.nix       # Catppuccin theme definition
    ├── everforest.nix       # Everforest theme definition
    └── nord.nix             # Nord theme definition
```

### Theme Configuration

Each theme is defined with the following structure:

```nix
{pkgs, ...}: {
  name = "Theme Display Name";
  
  colors = {
    background = "#hex-color";
    foreground = "#hex-color";
    # ... standard color palette
  };

  neovim = {
    plugin = pkgs.vimPlugins.theme-plugin;
    colorscheme = "colorscheme-name";
  };

  ghostty = {
    theme = "Ghostty Theme Name";
  };

  btop = {
    theme = ''
      theme[main_bg]="#hex-color"
      # ... btop theme configuration
    '';
  };

  fish = {
    colors = {
      fish_color_command = "#hex-color";
      # ... fish color variables
    };
  };
}
```

## Adding New Themes

### Step 1: Create Theme Definition

Create a new file in `modules/home-manager/themes/definitions/`:

```bash
# Example: gruvbox.nix
{pkgs, ...}: {
  name = "Gruvbox Dark";
  
  colors = {
    background = "#282828";
    foreground = "#ebdbb2";
    # ... define your color palette
  };

  neovim = {
    plugin = pkgs.vimPlugins.gruvbox-nvim;
    colorscheme = "gruvbox";
  };

  ghostty = {
    theme = "gruvbox-dark";  # Check with: ghostty +list-themes
  };

  btop = {
    theme = ''
      theme[main_bg]="#282828"
      theme[main_fg]="#ebdbb2"
      # ... customize btop colors
    '';
  };

  fish = {
    colors = {
      fish_color_normal = "#ebdbb2";
      fish_color_command = "#8ec07c";
      # ... set fish colors
    };
  };
}
```

### Step 2: Register Theme

Add your theme to `definitions/default.nix`:

```nix
{pkgs, ...}: {
  catppuccin = import ./catppuccin.nix {inherit pkgs;};
  everforest = import ./everforest.nix {inherit pkgs;};
  nord = import ./nord.nix {inherit pkgs;};
  gruvbox = import ./gruvbox.nix {inherit pkgs;};  # Add this line
}
```

### Step 3: Rebuild and Test

```bash
darwin-rebuild switch --flake .#macbook
nix-theme-list  # Should now show your new theme
nix-theme-set gruvbox
```

## Adding New Applications

### Step 1: Extend Theme Type

Add your application to the theme type in `engine/default.nix`:

```nix
myapp = mkOption {
  type = types.submodule {
    options = {
      config = mkOption { 
        type = types.str; 
        description = "MyApp configuration"; 
      };
    };
  };
};
```

### Step 2: Update Theme Definitions

Add your application config to each theme in `definitions/`:

```nix
myapp = {
  config = ''
    # MyApp theme configuration
    color.background = ${colors.background}
    color.foreground = ${colors.foreground}
  '';
};
```

### Step 3: Create Application Module

Create or update your application module to use the theme:

```nix
{config, ...}: let
  currentTheme = config.themes.available.${config.themes.current or "catppuccin"} or {};
  myappConfig = currentTheme.myapp.config or "";
in {
  home.file.".config/myapp/config".text = myappConfig;
}
```

## Environment Variables

The theme engine exports color values as environment variables for use in scripts or applications that don't have direct theme support:

- `THEME_CURRENT`: Current theme name
- `THEME_BACKGROUND`: Background color
- `THEME_FOREGROUND`: Foreground color
- `THEME_RED`, `THEME_GREEN`, `THEME_BLUE`, etc.: Color palette

## Troubleshooting

### Ghostty Theme Not Found
If you get "theme not found" errors from Ghostty:

1. Check available themes: `ghostty +list-themes | grep -i theme-name`
2. Update theme definition with exact name from the list
3. Rebuild configuration

### Theme Not Switching in Application
Some applications require:
1. Application restart after theme switch
2. Full system rebuild: `darwin-rebuild switch --flake .#macbook`
3. Check application-specific configuration files

### Adding Debugging
Enable debug mode by checking theme state:

```bash
# Check current theme file
cat ~/.config/nix-themes/current

# Check environment variables
env | grep THEME_

# Verify theme definitions loaded
nix-theme-list
```

## Future Enhancements

Potential additions to the theme system:
- **Wallpaper Management**: Automatic wallpaper switching per theme
- **More Applications**: VSCode, browsers, window managers
- **Dynamic Switching**: Real-time theme updates without rebuilds  
- **Theme Variants**: Light/dark modes per theme family
- **Custom Color Palettes**: User-defined color overrides