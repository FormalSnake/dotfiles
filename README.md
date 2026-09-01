# dotfiles

[![update](https://github.com/FormalSnake/dotfiles/actions/workflows/update.yml/badge.svg)](https://github.com/FormalSnake/dotfiles/actions/workflows/update.yml)
[![nixpkgs](https://img.shields.io/badge/nixpkgs-unstable-5277C3?logo=nixos&logoColor=white)](https://github.com/NixOS/nixpkgs)

One flake, three machines. This is my personal computer network, not a
framework: steal whatever looks useful, but hostnames and hardware quirks are
baked in everywhere.

| Host      | Hardware                    | OS         | Job                                  |
| --------- | --------------------------- | ---------- | ------------------------------------ |
| `macbook` | MacBook, Apple Silicon      | nix-darwin | the actual dev machine               |
| `g815`    | ASUS ROG laptop, RTX 5070   | NixOS      | thin client to the mac, build server |
| `e1504g`  | ASUS Vivobook, 8 GB RAM     | NixOS      | the little one                       |

Yes, that means the laptop with the RTX 5070 spends most of its life rendering
a terminal that SSHes into a MacBook. I'm at peace with it.

The Linux hosts run Hyprland with my own
[FormalShell](https://github.com/FormalSnake/FormalShell) on top. Hyprland
speaks Lua these days, so the window manager config is a real program that can
misbehave in exciting new ways. Colours come from the wallpaper:
[DMS](https://github.com/AvengeMedia/DankMaterialShell) runs matugen on every
wallpaper change and the whole desktop retunes itself, with
[Flexoki](https://stephango.com/flexoki) as the fallback for tools that can't
retheme at runtime. The Vivobook has 8 GB of RAM and knows it: builds ship to
the g815 over Tailscale, and the mac's Rosetta VM catches them when the ROG is
off.

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
just rollback    # it was better before

# NixOS hosts (fish function, runs from any directory)
rebuild          # nixos-rebuild switch for this host
rebuild boot     # stage for next boot instead
```

New files must be `git add`ed first; the flake can't see untracked files and
will cheerfully build as if they don't exist. This costs me ten confused
minutes roughly once a month.

Claude is allowed to run rebuilds here, on all three hosts. Yes, the robots
have sudo. The ground rules (and the theming and power details) live in
[`CLAUDE.md`](./CLAUDE.md).

## Updates

Every Saturday morning a GitHub Action bumps `flake.lock`, evals all three
hosts against the result, and pushes to main only when they all pass. The
evals run even when no input changed, so whatever I broke during the week gets
caught too. The mac pulls and rebuilds itself two hours later; the laptops
pick it up on their next rebuild.

A few packages are pinned to a git rev with `fetchFromGitHub` instead of being
flake inputs, so the weekly bump skips them: `fallout-limine-theme`, `clipssh`,
`fast`, and `lumen`. To bump one, update the `rev` in its mixin, blank the
hash, rebuild, and copy the real hash out of the mismatch error.

---

Structure originally inspired by
[getchoo/borealis](https://github.com/getchoo/borealis).
