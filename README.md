# Modular Nix Configuration

This is a modular Nix configuration that supports both NixOS and macOS (nix-darwin) systems with minimal duplication and clear separation of platform-specific configurations.

## Screenshot
![image](https://raw.githubusercontent.com/FormalSnake/dotfiles/main/assets/screenshot.png)

## Architecture

The configuration follows a hierarchical approach:

1. **Common**: Shared packages and programs available on all platforms
2. **Platform-specific**: macOS and NixOS specific packages integrated into host configurations
3. **Host-specific**: Machine-specific settings and overrides organized by user

## Structure

```
.
├── flake.nix           # Main flake configuration
├── flake.lock          # Locked dependencies
├── overlays/           # External overlays
│   └── default.nix     # Custom Neovim plugin overlays
├── home/               # User home configurations
│   └── kyandesutter/   # User-specific configurations
│       ├── macbook/    # macOS home configuration
│       │   └── default.nix  # macOS-specific packages and settings
│       └── homelab/    # NixOS home configuration
│           └── default.nix  # Linux-specific packages and settings
├── hosts/              # Host-specific system configurations
│   ├── macbook/        # macOS system configuration
│   │   └── default.nix # System settings, dock, homebrew packages, stateVersion
│   └── homelab/        # NixOS system configuration
│       └── default.nix # Boot config, filesystems, services, stateVersion
└── modules/            # Modular configurations
    └── home-manager/   # Home Manager modules
        ├── common/     # Cross-platform shared configurations
        │   └── default.nix  # Common packages, programs, and settings
        ├── misc/       # Miscellaneous configurations
        │   ├── gtk/    # GTK theming
        │   ├── qt/     # Qt theming
        │   ├── wallpaper/  # Wallpaper settings
        │   └── xdg/    # XDG directories
        ├── programs/   # Individual program configurations
        │   ├── aerospace/   # Window manager (macOS-specific)
        │   │   └── default.nix
        │   ├── btop/        # System monitor (cross-platform)
        │   │   └── default.nix
        │   ├── fastfetch/   # System info (cross-platform)
        │   │   └── default.nix
        │   ├── fish/        # Shell configuration (cross-platform)
        │   │   └── default.nix
        │   ├── fzf/         # Fuzzy finder (cross-platform)
        │   │   └── default.nix
        │   ├── ghostty/     # Terminal emulator (cross-platform config)
        │   │   ├── default.nix
        │   │   └── ghostty-shaders/  # Custom shaders
        │   ├── kitty/       # Terminal emulator (cross-platform)
        │   │   └── default.nix
        │   ├── neovim/      # Text editor with Lua configurations
        │   │   ├── default.nix
        │   │   ├── .luarc.json
        │   │   ├── core/    # Core Neovim configurations
        │   │   ├── options.lua
        │   │   └── plugins/ # Individual plugin configurations
        │   ├── tmux/        # Terminal multiplexer (cross-platform)
        │   │   └── default.nix
        │   └── zoxide/      # Smart cd (cross-platform)
        │       └── default.nix
        ├── scripts/    # Custom scripts
        └── services/   # Background services
```

## Key Features

### **Consistent Structure**
- All programs follow the `{program}/default.nix` pattern
- No mixed file/directory references
- Clean, maintainable organization

### **User-Centric Organization**
- Home configurations organized by `user/host` pattern
- Platform-specific packages integrated into host configs
- Clear separation of system vs. user configurations

### **External Overlays**
- Custom Neovim plugin overlays externalized
- Modular overlay system for easy extension

### **Modern Nix Features**
- Experimental features enabled (`nix-command`, `flakes`)
- Proper store optimization with `nix.optimise.automatic`
- Required `stateVersion` settings for all hosts

## Package Distribution

### Common Packages (All Platforms)
- **Development**: nodejs, bun, cargo, rustc, go, zig, lua
- **Utilities**: ripgrep, fd, fzf, gh, bat, lazygit, zoxide
- **Applications**: firefox
- **Programs**: neovim, tmux, fish, kitty, ghostty, btop, fastfetch, fzf

### macOS-Specific (home/kyandesutter/macbook/)
- **Development**: aider-chat, claude-code, pyenv, nixd, devenv, chafa, repomix
- **Utilities**: ice-bar, mousecape, the-unarchiver
- **Applications**: zed-editor
- **Programs**: aerospace (window manager)

### NixOS-Specific (home/kyandesutter/homelab/)
- **Utilities**: neofetch
- **Applications**: ghostty (via Nix package), github-desktop
- **KDE Utilities**: kde-specific tools and applications

### Host-Specific Settings
- **macbook**: Dock configuration, Homebrew packages, Darwin system settings
- **homelab**: Boot configuration, filesystem setup, SSH services

## Requirements

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

### Deploying to NixOS Homelab

To deploy your flake configuration to an existing NixOS machine:

1. **On the homelab, switch to the flake configuration:**
   ```bash
   sudo nixos-rebuild switch --flake /path/to/nix-config#homelab
   ```

The homelab configuration will automatically import your existing hardware configuration and set up KDE Plasma as the desktop environment.

## Adding a New Host

1. Create system configuration under `hosts/{hostname}/default.nix`
2. Create user configuration under `home/{username}/{hostname}/default.nix`
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

## Adding New Programs

1. Create a new directory: `modules/home-manager/programs/{program}/`
2. Add `default.nix` with your program configuration
3. Import in `modules/home-manager/common/default.nix`:
   ```nix
   imports = [
     ../programs/{program}
     # ... other imports
   ];
   ```

## Updating Flakes

To update all flake inputs to their latest versions:

```sh
nix flake update
```

## Shell Migration (Zsh to Fish)

If you're migrating from zsh to fish, follow these steps:

### 1. Rebuild your system
```bash
sudo darwin-rebuild switch --flake .
```

### 2. Add fish to allowed shells
```bash
echo "/etc/profiles/per-user/$(whoami)/bin/fish" | sudo tee -a /etc/shells
```

### 3. Set fish as default shell
```bash
chsh -s /etc/profiles/per-user/$(whoami)/bin/fish
```

### 4. Set up secret environment variables
```bash
# Copy the template
cp ~/.config/fish/secrets.fish.template ~/.config/fish/secrets.fish

# Edit the file and add your API keys/tokens
# Example:
# set -gx OPENAI_API_KEY "your-api-key-here"
# set -gx GITHUB_TOKEN "your-github-token-here"
```

### 5. Restart your terminal
Fish will now be your default shell with all your aliases and functions ported over.

## Software Included

### Cross-Platform
- **Shell**: Fish with syntax highlighting, autosuggestions, and custom functions
- **Editor**: Neovim with comprehensive LSP, completion, and custom Lua configurations
- **Terminals**: Kitty and Ghostty with Catppuccin theming
- **Multiplexer**: Tmux with session management and vim navigation
- **Monitoring**: Btop system monitor
- **System Info**: Fastfetch
- **Utilities**: Git, Lazygit, FZF, Zoxide, Ripgrep, Bat

### macOS-Specific
- **Development**: Aider AI, Claude, PyEnv, DevEnv
- **Window Management**: Aerospace tiling window manager ([User Guide](docs/aerospace.md))
- **Installation**: Ghostty via Homebrew (due to signing requirements)

### Linux-Specific  
- **Desktop**: KDE Plasma 6 with X11 support
- **System**: Minimal KDE setup with essential utilities
- **Utilities**: Native Linux alternatives for system monitoring

## Contributing

Contributions are welcome! If you have improvements or suggestions, please open an issue or submit a pull request.

## License

This repository is licensed under MIT License. Feel free to use, modify, and distribute according to the license terms.