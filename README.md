# nix-config

Declarative macOS configuration for `macbook` (and eventually `homelab`). Inspired by [getchoo/borealis](https://github.com/getchoo/borealis).

## Layout

- `flake.nix` — flake-parts entry point
- `flake/` — flake-level outputs (dev shells, formatter, CI)
- `modules/` — reusable module sets (shared + per-platform)
  - `modules/shared/` — cross-platform pieces (nix settings, home-manager glue)
  - `modules/darwin/` — macOS-specific (homebrew, system defaults, dock, login items)
- `systems/` — per-host configurations (`macbook/`, `homelab/`)
- `users/` — per-user home-manager configurations (`kyandesutter/`)
- `secrets/` — agenix-encrypted secrets

## ⚠️ Rebuild policy

**Only the repository owner (kyandesutter) may run rebuilds.** AI assistants and
automated tooling must **never** run `darwin-rebuild`, `nixos-rebuild`,
`home-manager switch`, `just r`, `just b`, `just rebuild`, `just build`,
`just bootstrap`, or any equivalent build/activation command — not even
`build`-only variants. Stage and document changes, then stop and let the owner
rebuild manually.

## Usage

```sh
# First-time bootstrap (darwin-rebuild not yet on PATH)
just bootstrap

# Subsequent rebuilds
just r          # darwin-rebuild switch
just b          # build only
just c          # nix flake check
just u          # update all inputs
just ui nixpkgs # update one input
just rollback   # previous generation
```
