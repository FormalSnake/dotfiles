# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## ⚠️ Rebuild policy — READ FIRST

**Only the owner (kyandesutter) runs rebuilds.** Never run `darwin-rebuild`,
`nixos-rebuild`, `home-manager switch`, or any `just` build/switch/bootstrap
recipe — not even build-only variants. When changes are ready: `git add` the
new/changed files (the flake only sees git-tracked files), document what
changed, then stop and let the owner rebuild.

Safe, non-building checks you MAY run:
- `nix-instantiate --parse <file>.nix` — syntax only.
- `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'` and
  `nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'` —
  forces all module imports to resolve without building the system. (Avoid
  evaluating `home-manager.users.*` config paths: they trigger IFD, e.g.
  Noctalia's `config validate` and the Catppuccin palette import.)

## Overview

Declarative config for two machines via one flake (flake-parts):
- **`macbook`** — `aarch64-darwin`, nix-darwin + home-manager. Primary dev host.
- **`g815`** — `x86_64-linux`, NixOS + home-manager. ASUS ROG laptop; Hyprland +
  Noctalia desktop, gaming + NVIDIA PRIME offload.

Secrets are agenix-encrypted (`secrets/`). The two hosts are wired in
`systems/default.nix` (`darwinConfigurations.macbook`, `nixosConfigurations.g815`).

## Layout & conventions

```
flake.nix              flake-parts entry; all inputs
flake/                 flake-level outputs (dev shells)
modules/
  shared/              cross-platform system modules (nix settings, home-manager
                       glue, tailscale) — imported by BOTH platforms
  darwin/  nixos/      per-platform module trees, each with:
    mixins/            one concern per file (audio, bluetooth, hyprland, …)
    profiles/          compose mixins into roles (desktop, gaming)
systems/<host>/        per-host config (hardware, host-specific options)
users/kyandesutter/
  default.nix          cross-platform home base + imports
  darwin.nix linux.nix platform-specific home mixin wiring
  mixins/              per-program home-manager config (one concern per file)
  noctalia-templates/  matugen-syntax templates Noctalia renders at runtime
  claude/              VENDORED Claude config (skills/commands/agents) — data,
                       not nix; ignore when analyzing the config itself
secrets/               agenix .age files + secrets.nix
```

Conventions:
- **One concern per mixin.** A mixin that does several unrelated things should be
  split. Hardware-specific tuning belongs in `systems/<host>/`, not generic mixins.
- **Enable flags:** togglable mixins use `options.kyan.<name>.enable =
  lib.mkEnableOption …` gated with `lib.mkIf`. Always-on mixins set options
  directly; use `lib.mkDefault` for anything a second host might override.
- **No hardcoded `/home/...` or `/Users/...`** in module bodies — derive from
  `config.home.homeDirectory` (home-manager) or
  `config.users.users.kyandesutter.home` (system).
- **Platform-gating:** cross-platform mixins guard with
  `lib.optionals/​optionalAttrs pkgs.stdenv.isDarwin/isLinux`; platform-only
  mixins are imported solely from `darwin.nix`/`linux.nix` and need no guard.

## Theming model (g815 desktop)

Colours are **wallpaper-derived (matugen/M3) via Noctalia**, the single source of
truth. Noctalia regenerates a palette on every wallpaper pick / light-dark flip and
renders templates (`users/kyandesutter/noctalia-templates/`) into per-app files,
running each app's reload hook. **Catppuccin is only a static fallback**
(`autoEnable = false`) for consumers that genuinely can't be dynamic: SDDM
(pre-login), Herdr (build-time theme name), Neovim's pre-palette colourscheme, and
the alt-tab switcher's build-time fallback. When adding a themed surface, prefer a
Noctalia template + a Catppuccin fallback (see `mixins/alttab.nix` for the
file-watch + fallback pattern).

## Power management — DO NOT BREAK

Power management is centered on **Noctalia + Hyprland** and is load-bearing:
- `modules/nixos/mixins/power.nix` — `power-source` classifier (AC / power bank /
  battery) + `power-reconcile` (the single automatic owner of the PPD profile,
  publishes `/run/power/state`). udev-triggered on power events.
- `users/kyandesutter/mixins/hyprland.nix` — `power-tune` reacts to source changes
  (GPU choice on AC, AC-dock relog, keyboard aura via `aura-repaint`).
- `modules/nixos/mixins/asus.nix` — asusd, battery limit, Aura keyboard.
- `night-mode`/`game-mode` (`gaming.nix`) — profile toggles.

When touching any of these, treat them as **reorganize-only unless explicitly
asked to change behavior**. `power-source` MUST stay in `environment.systemPackages`
(referenced by absolute path `/run/current-system/sw/bin/power-source`).

## Autostart (g815)

DE-agnostic login apps (Steam, Helium, Equibop, Spotify, …) are home-manager
`systemd.user.services` bound to `graphical-session.target` in
`users/kyandesutter/mixins/autostart.nix`. Only genuinely Hyprland-coupled startup
(alttab Quickshell, session-restore/snapshot, polkit) stays in `hyprland.nix`'s
`hyprland.start` block.

## Tooling

Prefer `fd` (find), `rg` (grep). For broad code analysis, delegate to the
code-searcher subagent. Never proactively create docs/*.md unless asked.
