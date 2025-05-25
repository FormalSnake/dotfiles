# Modular Nix Configuration

This is a modular Nix configuration that supports both NixOS and macOS (nix-darwin) systems with minimal duplication and clear separation of platform-specific configurations.

## Screenshot
![image](https://raw.githubusercontent.com/FormalSnake/dotfiles/main/assets/screenshot.png)

## Architecture

The configuration follows a hierarchical approach:

1. **Common**: Shared packages and programs available on all platforms
2. **Platform-specific**: macOS and NixOS specific packages and configurations
3. **Host-specific**: Machine-specific settings and overrides

## Structure

```
.
├── flake.nix       # Main flake configuration
├── flake.lock      # Locked dependencies
├── hosts           # Host-specific configurations (machine-specific settings only)
│   ├── macbook     # macOS machine configuration
│   │   ├── default.nix  # System-level settings, homebrew packages
│   │   └── home.nix     # Host-specific home-manager settings
│   └── homelab     # NixOS machine configuration  
│       ├── default.nix  # System-level settings, hardware config
│       └── home.nix     # Host-specific home-manager settings
└── modules         # Modular configurations
    ├── common      # Cross-platform shared configurations
    │   └── home.nix     # Common packages, programs, and settings
    ├── darwin      # macOS-specific configurations
    │   ├── default.nix  # macOS system defaults and settings
    │   ├── home.nix     # macOS-specific packages and programs
    │   └── homebrew.nix # Homebrew configuration
    ├── nixos       # NixOS-specific configurations
    │   ├── default.nix  # NixOS system configuration and Hyprland
    │   └── home.nix     # Linux-specific packages and Hyprland utilities
    └── programs    # Individual program configurations
        ├── btop.nix         # System monitor (cross-platform)
        ├── fastfetch.nix    # System info (cross-platform)
        ├── fzf.nix          # Fuzzy finder (cross-platform)
        ├── ghostty.nix      # Terminal emulator (cross-platform config)
        ├── hyprland.nix     # Window manager (Linux-specific)
        ├── kitty.nix        # Terminal emulator (cross-platform)
        ├── neovim.nix       # Text editor (cross-platform)
        ├── tmux.nix         # Terminal multiplexer (cross-platform)
        ├── zoxide.nix       # Smart cd (cross-platform)
        └── zsh.nix          # Shell configuration (cross-platform)
```

## Package Distribution

### Common Packages (All Platforms)
- **Development**: nodejs, bun, cargo, rustc, go, zig, lua
- **Utilities**: ripgrep, fd, fzf, gh, bat, lazygit
- **Applications**: firefox, brave
- **Programs**: neovim, tmux, zsh, kitty, ghostty, btop, fastfetch, spicetify, zoxide, fzf

### macOS-Specific
- **Development**: aider-chat, claude-code, pyenv, nixd, devenv, chafa, repomix
- **Utilities**: ice-bar, mousecape, the-unarchiver
- **Applications**: zed-editor
- **Programs**: (none currently - all moved to cross-platform)

### NixOS-Specific  
- **Utilities**: neofetch
- **Applications**: ghostty (via Nix package)
- **Hyprland Ecosystem**: waybar, swww, dunst, rofi-wayland, wl-clipboard, grim, slurp, wofi
- **Programs**: hyprland

### Host-Specific Settings
- **macbook**: Uses `catppuccin_mocha` oh-my-posh theme, homebrew packages
- **homelab**: Uses `huvix` oh-my-posh theme, Hyprland desktop environment

## Requirements
Ensure you have the following installed on your system:

### Nix
```sh
curl -L https://nixos.org/nix/install | sh
```

## Usage

### Building for macOS

```bash
# Build the configuration
nix build .#darwinConfigurations.macbook.system

# Apply the configuration
./result/sw/bin/darwin-rebuild switch --flake .#macbook
```

### Building for NixOS

```bash
# Build the configuration
nixos-rebuild build --flake .#homelab

# Apply the configuration (as root)
nixos-rebuild switch --flake .#homelab
```

## Adding a New Host

1. Create a new directory under `hosts/` with the hostname
2. Create `default.nix` and `home.nix` files for the system and home-manager configurations
3. Add the host to the appropriate section in `flake.nix`:

```nix
# For NixOS
nixosConfigurations = {
  "new-host" = mkNixosConfig {
    username = "username";
    hostname = "new-host";
    system = "x86_64-linux"; # or aarch64-linux
  };
};

# For Darwin
darwinConfigurations = {
  "new-mac" = mkDarwinConfig {
    username = "username";
    hostname = "new-mac";
    system = "aarch64-darwin"; # or x86_64-darwin
  };
};
```

## Updating Flakes

To update all flake inputs to their latest versions:

```sh
nix flake update
```

## Software Included

### Cross-Platform
- **Shell**: ZSH with syntax highlighting, autosuggestions, and oh-my-posh
- **Editor**: Neovim with comprehensive LSP, completion, and plugin setup
- **Terminals**: Kitty and Ghostty with Catppuccin theming
- **Multiplexer**: Tmux with session management and vim navigation
- **Monitoring**: Btop system monitor
- **System Info**: Fastfetch
- **Music**: Spicetify for Spotify theming
- **Utilities**: Git, Lazygit, FZF, Zoxide, Ripgrep, Bat

### macOS-Specific
- **Development**: Aider AI, Claude, PyEnv, DevEnv
- **Installation**: Ghostty via Homebrew (due to signing requirements)

### Linux-Specific  
- **Desktop**: Hyprland with Wayland support
- **System**: Complete Hyprland ecosystem (waybar, rofi, etc.)
- **Utilities**: Native Linux alternatives for system monitoring

## Contributing

Contributions are welcome! If you have improvements or suggestions, please open an issue or submit a pull request.

## License

This repository is licensed under MIT License. Feel free to use, modify, and distribute according to the license terms.
