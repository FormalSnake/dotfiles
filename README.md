# dotfiles

[![ci](https://github.com/FormalSnake/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/FormalSnake/dotfiles/actions/workflows/ci.yml)
[![update](https://github.com/FormalSnake/dotfiles/actions/workflows/update.yml/badge.svg)](https://github.com/FormalSnake/dotfiles/actions/workflows/update.yml)
[![nixpkgs](https://img.shields.io/badge/nixpkgs-unstable-5277C3?logo=nixos&logoColor=white)](https://github.com/NixOS/nixpkgs)

One flake, three machines. This is my personal computer network, not a
framework: steal whatever looks useful, but hostnames and hardware quirks are
baked in everywhere.

| Host      | Hardware                    | OS         | Job                                    |
| --------- | --------------------------- | ---------- | -------------------------------------- |
| `macbook` | MacBook, Apple Silicon      | nix-darwin | the actual dev machine                 |
| `g815`    | ASUS ROG laptop, RTX 5070   | NixOS      | thin client to the mac, build server   |
| `e1504g`  | ASUS Vivobook, 8 GB RAM     | NixOS      | the little one                         |

The Linux hosts run Hyprland with my own
[FormalShell](https://github.com/FormalSnake/FormalShell) on top, configured in
Lua because Hyprland 0.55 dropped the old config syntax. Colours come from the
wallpaper (matugen via [DMS](https://github.com/AvengeMedia/DankMaterialShell)),
with [Flexoki](https://stephango.com/flexoki) as the static fallback for tools
that can't retheme at runtime. The Vivobook is too weak to build its own
system, so it offloads builds to the g815 over Tailscale; the mac runs a
Rosetta VM builder as the fallback for x86_64-linux.

## Layout

```
flake.nix        inputs + flake-parts entry
flake/           dev shells, formatter
modules/
  shared/        both platforms: nix settings, tailscale, home-manager glue
  darwin/        macOS: homebrew, system defaults, dock
  nixos/         NixOS: boot, nvidia, hyprland, gaming, asus
systems/         per-host wiring (macbook, g815, e1504g)
users/           home-manager config, one concern per file
secrets/         agenix-encrypted
```

Mixins hold one concern each, profiles compose them into roles, and hosts pick
profiles plus their hardware config. Anything togglable is a
`kyan.<name>.enable` option.

## Rebuilding

```sh
# macbook
just bootstrap   # first time only, before darwin-rebuild is on PATH
just r           # darwin-rebuild switch
just b           # build without activating
just rollback    # undo

# NixOS hosts (fish function, runs from any directory)
rebuild          # nixos-rebuild switch for this host
rebuild boot     # stage for next boot instead
```

New files must be `git add`ed first; the flake can't see untracked files and
will build as if they don't exist. This costs me ten confused minutes roughly
once a month.

Claude is allowed to run rebuilds here, on all three hosts. The ground rules
for that (and the theming and power details) live in [`CLAUDE.md`](./CLAUDE.md).

## Updates

A GitHub Action bumps `flake.lock` every Saturday morning, evals all three
host configs against the new lock, and only pushes to main if they all pass.
The mac pulls and rebuilds itself two hours later via launchd; the laptops
pick it up on their next rebuild.

A few packages are pinned to a git rev with `fetchFromGitHub` instead of being
flake inputs, so the weekly bump skips them: `fallout-limine-theme`, `clipssh`,
`fast`, and `lumen`. To bump one, update the `rev` in its mixin, blank the
hash, rebuild, and copy the real hash out of the mismatch error.

---

Structure originally inspired by
[getchoo/borealis](https://github.com/getchoo/borealis).
