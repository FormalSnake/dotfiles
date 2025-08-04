# CRUSH.md

## Build Commands
```bash
# Build macOS configuration
nix build .#darwinConfigurations.macbook.system

# Build NixOS configuration
nixos-rebuild build --flake .#homelab

# Apply macOS configuration
./result/sw/bin/darwin-rebuild switch --flake .#macbook

# Apply NixOS configuration
sudo nixos-rebuild switch --flake .#homelab
```

## Development Commands
```bash
# Enter development shell
nix develop

# Format Nix files
nix fmt

# Update flake inputs
nix flake update

# Check flake
nix flake check
```

## Code Style Guidelines

### Nix Code Style
- Use 2 space indentation
- Prefer modular, reusable configurations
- Follow the existing pattern of imports in `modules/home-manager/common/default.nix`
- Use descriptive variable names in camelCase
- Put complex configurations in separate modules

### Naming Conventions
- Module directories: Use program names in lowercase (`programs/neovim/`)
- Configuration files: `default.nix` for main configuration
- Host configurations: Match hostname (`hosts/macbook/`, `hosts/homelab/`)

### Testing
- Test configuration builds before applying
- Use `nix build` commands as dry-run equivalents

## Project Structure
- `flake.nix`: Main flake configuration
- `modules/home-manager/`: Program configurations
- `hosts/`: System-specific configurations
- `home/kyandesutter/`: User-specific overrides