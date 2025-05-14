# Modular Nix Configuration

This is a modular Nix configuration that supports both NixOS and macOS (nix-darwin) systems.

## Screenshot
![image](https://raw.githubusercontent.com/FormalSnake/dotfiles/main/assets/screenshot.png)

## Structure

```
.
├── flake.nix       # Main flake configuration
├── flake.lock      # Locked dependencies
├── hosts           # Host-specific configurations
│   ├── macbook     # macOS configuration
│   │   ├── default.nix
│   │   └── home.nix
│   └── homelab     # NixOS homelab configuration
│       ├── default.nix
│       └── home.nix
└── modules         # Shared module configurations
    ├── common      # Shared between all systems
    │   └── home.nix
    ├── darwin      # macOS specific
    │   ├── default.nix
    │   ├── home.nix
    │   └── homebrew.nix
    ├── nixos       # NixOS specific
    │   ├── default.nix
    │   └── home.nix
    └── programs    # Program configurations
        ├── btop.nix
        ├── fastfetch.nix
        ├── fzf.nix
        ├── ghostty.nix
        ├── matugen.nix
        ├── neovim.nix
        ├── tmux.nix
        ├── zoxide.nix
        └── zsh.nix
```

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

## What software does this provide configuration for?
* Tmux 
* Ghostty
* zsh 
* nvim
* And more via homebrew on macOS and system packages on NixOS

## Contributing

Contributions are welcome! If you have improvements or suggestions, please open an issue or submit a pull request.

## License

This repository is licensed under MIT License. Feel free to use, modify, and distribute according to the license terms.
