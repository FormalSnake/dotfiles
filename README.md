# nix-config

Declarative configuration for two machines from one flake:

- **`macbook`** — `aarch64-darwin`, nix-darwin + home-manager (primary dev host)
- **`g815`** — `x86_64-linux`, NixOS + home-manager (ASUS ROG laptop: Hyprland +
  Noctalia desktop, gaming, NVIDIA PRIME offload)

Inspired by [getchoo/borealis](https://github.com/getchoo/borealis).

## Layout

- `flake.nix` — flake-parts entry point + inputs
- `flake/` — flake-level outputs (dev shells, formatter)
- `modules/` — reusable module sets
  - `modules/shared/` — cross-platform (nix settings, home-manager glue, tailscale)
  - `modules/darwin/` — macOS (homebrew, system defaults, dock, login items)
  - `modules/nixos/` — NixOS (boot, graphics/nvidia, hyprland, gaming, power, asus, …)
  - each platform has `mixins/` (one concern per file) and `profiles/` (compose mixins)
- `systems/` — per-host config (`macbook/`, `g815/`)
- `users/` — per-user home-manager config (`kyandesutter/`)
- `secrets/` — agenix-encrypted secrets

See [`CLAUDE.md`](./CLAUDE.md) for repo conventions, the Noctalia/matugen theming
model, and the power-management architecture.

## ⚠️ Rebuild policy

**Only the repository owner (kyandesutter) may run rebuilds.** AI assistants and
automated tooling must **never** run `darwin-rebuild`, `nixos-rebuild`,
`home-manager switch`, `just r`/`b`/`rebuild`/`build`/`bootstrap`, or any
equivalent build/activation command — not even `build`-only variants. Stage and
document changes, then stop and let the owner rebuild.

## Usage

### macbook (darwin)

```sh
# First-time bootstrap (darwin-rebuild not yet on PATH)
just bootstrap

just r          # darwin-rebuild switch
just b          # build only
just c          # nix flake check
just u          # update all inputs
just ui nixpkgs # update one input
just rollback   # previous generation
```

### g815 (NixOS)

```sh
# `rebuild` fish function (defined in users/kyandesutter/linux.nix); runs from any dir
rebuild                 # sudo nixos-rebuild switch --flake ~/.config/nix#g815
rebuild boot            # stage for next boot
rebuild --show-trace    # extra flags pass through
```
