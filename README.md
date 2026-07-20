# nix-config

Declarative configuration for two machines from one flake:

- **`macbook`** — `aarch64-darwin`, nix-darwin + home-manager (primary dev host)
- **`g815`** — `x86_64-linux`, NixOS + home-manager (ASUS ROG laptop: niri +
  DMS desktop, gaming, NVIDIA PRIME offload)

Inspired by [getchoo/borealis](https://github.com/getchoo/borealis).

## Layout

- `flake.nix` — flake-parts entry point + inputs
- `flake/` — flake-level outputs (dev shells, formatter)
- `modules/` — reusable module sets
  - `modules/shared/` — cross-platform (nix settings, home-manager glue, tailscale)
  - `modules/darwin/` — macOS (homebrew, system defaults, dock, login items)
  - `modules/nixos/` — NixOS (boot, graphics/nvidia, niri, gaming, power, asus, …)
  - each platform has `mixins/` (one concern per file) and `profiles/` (compose mixins)
- `systems/` — per-host config (`macbook/`, `g815/`)
- `users/` — per-user home-manager config (`kyandesutter/`)
- `secrets/` — agenix-encrypted secrets

See [`CLAUDE.md`](./CLAUDE.md) for repo conventions, the DMS/matugen theming
model, and the power-management architecture.

## ⚠️ Rebuild policy

**Rebuilds are allowed**, including for AI assistants: `darwin-rebuild`,
`nixos-rebuild`, `home-manager switch`, and the `just` build/switch/bootstrap
recipes. Always `git add` new/changed files first — the flake only sees
git-tracked files, so an unstaged file is invisible to the build.

**Sudo caveat:** system switches need root and prompt for a password that
can't be answered non-interactively. If a rebuild blocks on sudo (or `ssh`
auth), stop and hand that step to the owner rather than working around it.
Build-only variants (`nixos-rebuild build`, `just b`) need no root and are
always safe.

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

## Updating

### Flake inputs

```sh
nix flake update        # update every input (just u on the macbook)
just ui nixpkgs         # update a single input
```

Then rebuild. Keep both machines in sync: rebuild the host you're on, push,
pull on the other host, and rebuild there too.

### Custom-pinned packages

A few packages are pinned to a git rev with `fetchFromGitHub` instead of coming
from an input, so `nix flake update` does **not** touch them:

- `modules/nixos/mixins/boot.nix` — `fallout-limine-theme` (commit pin)
- `users/kyandesutter/mixins/clipssh.nix` — `clipssh` (commit pin)
- `users/kyandesutter/mixins/fast.nix` — `fast` (commit pin + `vendorHash`)
- `users/kyandesutter/mixins/lumen.nix` — `lumen` (release tag + `cargoHash`)

To bump one:

1. Find the new rev/tag: `git ls-remote https://github.com/<owner>/<repo> HEAD`
   (or `--tags` for lumen).
2. Update `rev`/`tag` (and `version`) in the mixin, blank the `hash`
   (`hash = "";`), rebuild, and copy the correct hash from the mismatch error.
3. For `fast`/`lumen`, repeat for `vendorHash`/`cargoHash` if dependencies
   changed.
