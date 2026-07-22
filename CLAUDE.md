# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Just for fun (low priority)

If you catch yourself having made a mistake, open the correction with
"Oepsie woepsie floepsie!" and then say whatever you were going to say. This is
purely cosmetic — never let it delay, reword, or take priority over the actual
work.

## ⚠️ Rebuild policy — READ FIRST

**Claude may run rebuilds.** `darwin-rebuild`, `nixos-rebuild`,
`home-manager switch`, and the `just` build/switch/bootstrap recipes are
allowed. Always `git add` new/changed files first — the flake only sees
git-tracked files, so an unstaged file is invisible to the build.

**Sudo caveat:** system rebuilds (`nixos-rebuild switch`, `darwin-rebuild
switch`, most `just` recipes) need root and will prompt for a sudo password.
That prompt can't be answered non-interactively, so the rebuild may hang or
fail. If it does, stop and ask the owner to run that step (e.g. via `! <cmd>`)
or to grant passwordless sudo — don't try to work around it.

Safe, non-building checks you MAY run:
- `nix-instantiate --parse <file>.nix` — syntax only.
- `nix eval '.#nixosConfigurations.g815.config.system.stateVersion'` and
  `nix eval '.#darwinConfigurations.macbook.config.system.stateVersion'` —
  forces all module imports to resolve without building the system. (Avoid
  evaluating `home-manager.users.*` config paths: they can trigger IFD.)

## Keep both machines in sync

The two hosts must stay in sync: a change applied on one is expected to land on
the other. When working from the **g815 (nixos laptop)**, the full flow is:

1. Rebuild on g815 (`nixos-rebuild` / the `just` recipe).
2. `git push`.
3. `ssh macbook`, `cd ~/.config/nix`, `git pull`.
4. Rebuild on the macbook (`darwin-rebuild` / the `just` recipe).

Claude can drive all four steps. Watch for the sudo caveat above on the two
rebuilds (steps 1 and 4) and the `ssh macbook` auth on step 3 — if either blocks
on a password, hand that step to the owner and continue once it clears.

## Overview

Declarative config for two machines via one flake (flake-parts):
- **`macbook`** — `aarch64-darwin`, nix-darwin + home-manager. Primary dev host.
- **`g815`** — `x86_64-linux`, NixOS + home-manager. ASUS ROG laptop; niri +
  Dank Material Shell (DMS) desktop, NVIDIA dGPU as a power-managed peripheral.

The macbook is the real development host; the g815 is used as a thin client that
reaches the mac over SSH/MOSH and remote desktop to work remotely, rather than
building locally.

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
    mixins/            one concern per file (audio, bluetooth, niri, …)
    profiles/          compose mixins into roles (desktop)
systems/<host>/        per-host config (hardware, host-specific options)
users/kyandesutter/
  default.nix          cross-platform home base + imports
  darwin.nix linux.nix platform-specific home mixin wiring
  mixins/              per-program home-manager config (one concern per file)
  matugen-templates/   matugen-syntax templates DMS renders at runtime
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

Colours are **wallpaper-derived (matugen/M3) via DMS** (Dank Material Shell,
since 2026-07-20; it replaced Noctalia), the single source of truth. DMS runs
matugen on every wallpaper pick / light-dark flip: its built-in templates theme
GTK (`~/.config/gtk-{3,4}.0/dank-colors.css`, imported via gtk.css) and Qt
(`~/.config/qt{5,6}ct/colors/matugen.conf`), and it merges our user templates
(`users/kyandesutter/matugen-templates/`, registered via the generated
`~/.config/matugen/config.toml` in `mixins/dms.nix`: aura, ghostty, neovim,
equibop, spicetify, obsidian, niri-border, btop, yazi, wallpaper-path) into the
same matugen run, executing each template's post_hook. niri's window borders are
themed through the `niri-border` template: it renders
`~/.cache/dank/niri-border.kdl` (the `layout {}` fragment niri's config
`include`s last, so it wins) and its post_hook runs
`niri msg action load-config-file`. DMS's `settings.json` is runtime-mutable
(NOT home-manager-managed): `mixins/dms.nix` seeds it once if absent — idle
blanking must stay disabled there (eDP-1 wake-modeset bug). **Flexoki is only a
static fallback** for consumers that genuinely can't be dynamic: Neovim's
pre-palette colourscheme, niri's pre-palette border colours (the seeded
`niri-border.kdl` copy in `mixins/niri.nix`), and CLI tools with no matugen
template (bat, fzf, lazygit, fish). Per-wallpaper Flexoki *pinning* lives on as
`flexoki-pin.service` (`mixins/dms.nix`): it watches DMS's session.json and
pins/unpins the Flexoki custom theme while a flexoki-named wallpaper is active
(same substring match as the old Noctalia `flexoki-scheme` hook). The Flexoki palette is
pure Nix data in
`users/kyandesutter/mixins/flexoki/palette.nix` (base tones + accents + ready
`light`/`dark` terminal views), and `mixins/flexoki/` themes the CLI tools from
it — static Flexoki dark on Linux, appearance-following light/dark on macOS
(where Flexoki is the *primary* scheme, not a fallback: Ghostty uses its built-in
Flexoki Light/Dark, bat uses `auto:system`, fish re-selects by appearance). SDDM
is independent (the `sddm-astronaut` pixel_sakura preset's own colours); Herdr
pins Flexoki Dark via `[theme.custom]` tokens sourced from `palette.nix`
(`mixins/herdr.nix`) — it used to follow ghostty via its `terminal` theme, but
that reads the terminal palette over OSC, which doesn't survive SSH/mosh (herdr
runs on the macbook, reached over SSH), so the static tokens keep it correct and
low-contrast remotely. When
adding a themed surface, prefer a matugen user template + a Flexoki fallback
derived from `palette.nix` (see the `niri-border` template in `mixins/dms.nix`
for the render + seeded-fallback pattern).

## Power management — DO NOT BREAK

GPU model (since 2026-07-11, spec in `docs/superpowers/specs/`): the session is
**always iGPU-primary** — niri renders on the iGPU by default; gaming lives on
Windows; the dGPU is only a power-managed peripheral for the panel backlight
(its WMI) and the HDMI port. niri **hot-adds** the dGPU's DRM device at runtime
(monitor on the powered dGPU lights up with no relog), but it also holds an fd
on every GPU it has seen and has no release IPC — so on battery a held dGPU
stays powered until logout. dGPU power: ON while charging (AC or USB-C), OFF on
battery unless a monitor is connected on it or the session still holds it.
**Relogs are consent-only**: `gpu-relog-prompt` shows a persistent button
notification (never automatic).

Power management is centered on **DMS + niri** and is load-bearing:
- `modules/nixos/mixins/power.nix` — `power-source` classifier (AC / power bank /
  battery) + `power-reconcile` (the single automatic owner of the PPD profile,
  publishes `/run/power/state`; udev-triggered, restart-safe) +
  `dgpu-reconcile.service`/`dgpu-power` (the ONLY thing allowed to load/unload
  the nvidia modules — serialized via flock, holds a sleep inhibitor, only ever
  `systemctl start`ed, never `restart`ed: interrupting or racing an nvidia
  module transition deadlocks the kernel in D-state and breaks suspend until
  reboot — observed 2026-07-03; a held device is always left powered, never
  force-released) + `power-resume-reconcile` (re-runs power-reconcile at wake
  so a charger change during sleep is acted on) + a polkit rule letting the
  session `systemctl start dgpu-reconcile.service` (login convergence kick).
- `users/kyandesutter/mixins/niri.nix` — `power-tune` (keyboard aura via
  `aura-repaint`, refresh-follows-profile via the `edp-refresh.kdl` fragment +
  `niri msg action load-config-file` — niri has no runtime per-output IPC —
  spawns `gpu-relog-prompt` on power/drm events, kicks dgpu-reconcile once per
  login) + `gpu-relog-prompt` (the ONLY relog path: persistent [Relog now]/
  [Not now] notification for three situations, each needing a session restart
  because niri reads `render-drm-device` once at startup — a mid-session dock
  (relog to render on the dGPU), a mid-session undock (relog back to the iGPU),
  and battery drain from a held dGPU with no monitor on it (relog to power it
  off); relog = `niri msg action quit --skip-confirmation`). The render-GPU
  switch is driven by `niri-render-device-select` (oneshot before niri.service):
  it writes the `render-device.kdl` debug fragment AND stamps
  `render-device.booted`; gpu-relog-prompt compares the live ideal
  (`niri-render-device-ideal`) against that stamp to detect a dock/undock. There
  is no env-hyprland equivalent: iGPU-primary is niri's default and the dGPU is
  hot-added, so no login-time GPU set, no `session-gpu-mode` marker, no session
  snapshot/restore (autostart.nix relaunches the login apps).
- `modules/nixos/mixins/asus.nix` — asusd, battery limit, Aura keyboard.
- `lock-before-sleep` (`modules/nixos/mixins/niri.nix`) — locks via
  `dms ipc call lock lock` before sleep.target; DMS's IPC socket lives in the
  user's `XDG_RUNTIME_DIR` (not display-keyed). The unit must never fail
  (exit-0 always) so a dead shell can't block suspend.

When touching any of these, treat them as **reorganize-only unless explicitly
asked to change behavior**. `power-source` MUST stay in `environment.systemPackages`
(referenced by absolute path `/run/current-system/sw/bin/power-source`).

## Autostart (g815)

DE-agnostic login apps (Steam, Helium, Equibop, Spotify, …) are home-manager
`systemd.user.services` bound to `graphical-session.target` in
`users/kyandesutter/mixins/autostart.nix` (niri.service BindsTo that target, so
they follow the session). Nothing is compositor-hook-launched anymore: the
polkit agent and power-tune are plain user services in `mixins/niri.nix`; the
alttab Quickshell switcher and session-restore/snapshot were deleted with the
niri migration (niri's native `recent-windows` MRU switcher replaces alttab).

## Tooling

Prefer `fd` (find), `rg` (grep). For broad code analysis, delegate to the
code-searcher subagent. Never proactively create docs/*.md unless asked.
