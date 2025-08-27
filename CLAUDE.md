# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Architecture

This is a modular Nix configuration supporting both NixOS (homelab) and macOS (macbook) systems using nix-darwin and home-manager. The configuration follows a hierarchical approach with minimal duplication.

### Configuration Structure
- **Common**: Shared packages and programs in `modules/home-manager/common/`
- **Platform-specific**: macOS and NixOS specific configurations in `hosts/`
- **Host-specific**: Machine-specific overrides in `home/kyandesutter/`
- **Program modules**: Individual program configurations in `modules/home-manager/programs/`

## Theme Engine

This configuration includes a comprehensive theme management system that provides consistent theming across all applications.

### Theme Commands

```bash
# List available themes
nix-theme-list

# Check current theme
nix-theme-current

# Switch theme (requires rebuild to fully apply)
nix-theme-set <theme-name>
```

### Available Themes

- **catppuccin**: Catppuccin Mocha (purple-tinted dark theme)
- **everforest**: Everforest Dark (forest green-inspired theme)  
- **nord**: Nord (arctic blue-inspired theme)

### Themed Applications

- **Neovim**: Automatic plugin installation and colorscheme
- **Ghostty**: Terminal theme switching
- **btop**: System monitor colors
- **Fish Shell**: Shell colors and syntax highlighting

See `docs/theme-engine.md` for detailed documentation on usage and extending the theme system.

## Common Development Commands

### Building and Applying Configurations

**macOS (Darwin):**
```bash
# Build the configuration
nix build .#darwinConfigurations.macbook.system

# Apply the configuration  
./result/sw/bin/darwin-rebuild switch --flake .#macbook
```

**NixOS (Homelab):**
```bash
# Build the configuration
nixos-rebuild build --flake .#homelab

# Apply the configuration (as root)
sudo nixos-rebuild switch --flake .#homelab
```

### Development Environment
```bash
# Enter development shell with formatters
nix develop

# Format Nix files using alejandra
nix fmt

# Update all flake inputs
nix flake update
```

### Testing and Validation
```bash
# Check flake for errors
nix flake check

# Build without applying (dry-run equivalent)
nix build .#darwinConfigurations.macbook.system  # macOS
nixos-rebuild build --flake .#homelab            # NixOS
```

## Key Configuration Files

- `flake.nix` - Main flake configuration with system definitions
- `modules/home-manager/common/default.nix` - Shared packages and program imports
- `hosts/macbook/default.nix` - macOS system settings and defaults
- `hosts/homelab/default.nix` - NixOS system configuration
- `home/kyandesutter/{host}/default.nix` - Host-specific user packages

## Program Configuration Locations

All program configurations follow the pattern `modules/home-manager/programs/{program}/default.nix`:

- **Neovim**: Comprehensive Lua configuration with LSP, completion, and plugins
- **Fish**: Shell with custom functions and aliases
- **Tmux**: Terminal multiplexer with vim-like navigation
- **Kitty/Ghostty**: Terminal emulators with theming
- **Aerospace**: macOS tiling window manager (macOS only)

## Adding New Programs

1. Create directory: `modules/home-manager/programs/{program}/`
2. Add `default.nix` with program configuration
3. Import in `modules/home-manager/common/default.nix`:
   ```nix
   imports = [
     ../programs/{program}
     # ... other imports
   ];
   ```

## Adding New Hosts

1. Create system config: `hosts/{hostname}/default.nix`
2. Create user config: `home/kyandesutter/{hostname}/default.nix`  
3. Add to `flake.nix`:
   ```nix
   # For NixOS
   nixosConfigurations.{hostname} = mkNixosConfig {
     username = "kyandesutter";
     hostname = "{hostname}";
     system = "x86_64-linux";
   };
   
   # For Darwin  
   darwinConfigurations.{hostname} = mkDarwinConfig {
     username = "kyandesutter";
     hostname = "{hostname}";
     system = "aarch64-darwin";
   };
   ```

## Package Management

- **Common packages**: Added in `modules/home-manager/common/default.nix`
- **macOS-specific**: Added in `home/kyandesutter/macbook/default.nix`
- **NixOS-specific**: Added in `home/kyandesutter/homelab/default.nix`
- **Homebrew (macOS)**: Managed in `hosts/macbook/homebrew.nix`

## Theming

- Uses Catppuccin theme (mocha flavor) across all programs
- Configured globally in `modules/home-manager/common/default.nix`
- Individual programs inherit theme automatically

## Custom Neovim Configuration

- Modular Lua configuration with LSP support
- Plugins configured individually in `modules/home-manager/programs/neovim/plugins/`
- Language servers: Lua, Nix, TypeScript, Astro, HTML, CSS, JSON
- Features: AI completion (Supermaven), Treesitter, diagnostics, git integration
- See `docs/neovim.md` for detailed keybindings and usage

## Shell Migration Notes

The configuration uses Fish shell by default. For shell migration:
1. Rebuild system configuration
2. Add fish to allowed shells: `echo "/etc/profiles/per-user/$(whoami)/bin/fish" | sudo tee -a /etc/shells`
3. Set as default: `chsh -s /etc/profiles/per-user/$(whoami)/bin/fish`
4. Configure secrets in `~/.config/fish/secrets.fish`

## State Versions

- Home Manager: 25.05
- macOS Darwin: 6  
- NixOS: 25.05

State versions should only be changed when migrating to new NixOS releases.