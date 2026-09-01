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

**Sudo works non-interactively on all three hosts** (since 2026-07-22):
`sudo -n` succeeds passwordless when the invoking environment carries an SSH
agent holding one of the three machine keys — which Claude's shell on the g815
always does (gcr agent at `$SSH_AUTH_SOCK` holds the g815 on-disk key), and
which SSH sessions between our hosts do via agent forwarding. On the macbook
the agent is no longer required at all (since 2026-07-27): `kyandesutter` has
blanket `NOPASSWD: ALL` in sudoers, so ANY process running as that user sudos
without a prompt, forwarded key or not. So Claude can rebuild ALL hosts
without owner hand-off:
- g815 (local): `sudo -n nixos-rebuild switch --flake .#g815`
- e1504g: `ssh e1504g 'cd ~/.config/nix && git pull && sudo -n nixos-rebuild switch --flake .#e1504g'`
- macbook: `ssh macbook 'cd ~/.config/nix && git pull && sudo -n /run/current-system/sw/bin/darwin-rebuild switch --flake .#macbook'`
  (absolute path: non-interactive fish on the mac has a minimal PATH).

If sudo unexpectedly prompts anyway, the agent chain is broken (no
`SSH_AUTH_SOCK`, or the agent lost the key) — stop and hand the step to the
owner via `! <cmd>` rather than working around it. One known-benign case:
sessions born under mosh inherit a dead forwarded socket (OpenSSH 10.1+
unlinks `~/.ssh/agent/s.*` when the bootstrap ssh exits). Fish `shellInit`
(`users/kyandesutter/mixins/fish.nix`) self-heals new shells by falling back
to the local gcr agent; in an already-running session started before that fix,
`set -x SSH_AUTH_SOCK $XDG_RUNTIME_DIR/gcr/ssh` restores the intended chain —
that IS the fix, not a workaround.

**⚠️ With great sudo comes great responsibility.** The password prompt used to
be a natural safety gate; it's gone now, on all three machines at once. Root
commands run the moment Claude types them. So: use sudo for rebuilds,
service restarts and diagnostics freely, but treat anything destructive or
hard to reverse (deleting data, partitioning/formatting, `nix-collect-garbage
-d`, bootloader changes, firewall/network changes on a remote host that could
cut off SSH) as owner-confirmation territory — ask first, exactly as if the
password were still required. Never fan a risky command out to multiple hosts
in one step; do one host, verify, then the next.

### How the sudo mesh works — don't break it

`pam_ssh_agent_auth` is a `sufficient` auth module for sudo on every host: it
accepts sudo iff the session's `SSH_AUTH_SOCK` agent holds a key from the
machine-key list. Console sudo still password/Touch-ID prompts on the Linux
hosts; on the mac `kyandesutter` is covered by the NOPASSWD line below
instead, so nothing prompts there. The moving parts, all load-bearing:
- **Machine-key lists**: `modules/nixos/mixins/users.nix` (Linux hosts, PAM
  reads `/etc/ssh/authorized_keys.d/%u`) and
  `modules/darwin/mixins/remote-access.nix` (mac). On the mac PAM can NOT read
  the nix-managed symlink (its path check rejects /nix/store), so activation
  installs a real root-owned copy at `/etc/ssh/sudo_authorized_keys`.
- **`Defaults noninteractive_auth`** (sudoers, both platforms): without it
  `sudo -n` refuses before PAM even runs.
- **`kyandesutter ALL=(ALL) NOPASSWD: ALL`** (mac only, `remote-access.nix`):
  covers local non-interactive shells that carry no forwarded agent — the case
  pam_ssh_agent_auth can't help with. It makes that module redundant for this
  one account on the mac; the module still gates every other user arriving
  over SSH, so don't drop it.
- **Agent forwarding** (`users/kyandesutter/mixins/ssh.nix`): our three host
  entries set `ForwardAgent yes` + `IdentityAgent SSH_AUTH_SOCK`. The latter
  MUST NOT become `none` (that silently disables forwarding) or be removed
  (the global 1Password IdentityAgent would be forwarded instead, and its keys
  aren't authorized). Never enable ForwardAgent for foreign hosts.
- **The darwin pam_ssh_agent_auth build** (`remote-access.nix`): nixpkgs marks
  it linux-only; the override builds it against OpenPAM with `-std=gnu99` and
  fortify off. Both flags are required.
- mac→Linux sudo needs an interactive mac session (launchd agent + loaded
  keychain key); chained hops (g815→mac→g815) work because the forwarded
  agent is re-forwarded.

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

Claude can drive all four steps non-interactively (see the sudo mesh above) —
steps 3+4 collapse to the one-shot macbook command in the rebuild policy
section. The e1504g follows the same flow, also in one shot. Only if sudo
unexpectedly prompts (broken agent chain) does a step go back to the owner.

## Overview

Declarative config for three machines via one flake (flake-parts):
- **`macbook`** — `aarch64-darwin`, nix-darwin + home-manager. Primary dev host.
- **`g815`** — `x86_64-linux`, NixOS + home-manager. ASUS ROG laptop; Hyprland +
  FormalShell desktop, everything on the NVIDIA dGPU (MUX), always on AC.
- **`e1504g`** — `x86_64-linux`, NixOS + home-manager. ASUS Vivobook (8 GB,
  Intel-only); same Hyprland + FormalShell desktop, none of the dGPU/asus
  machinery. Its
  nix builds offload to the g815 over Tailscale (LAN fallback) and fall back
  to local building when the g815 is unreachable.

The macbook is the real development host; the g815 is used as a thin client that
reaches the mac over SSH/MOSH and remote desktop to work remotely, rather than
building locally.

Both Linux hosts run **Hyprland** (since 2026-08-17; it replaced niri, which had
replaced Hyprland in July). The config language is **Lua**, not hyprlang —
Hyprland 0.55 dropped the old `.conf` syntax outright, and home-manager's
`wayland.windowManager.hyprland.settings` still emits hyprlang, so
`users/kyandesutter/mixins/hyprland.nix` writes `~/.config/hypr/hyprland.lua`
itself rather than using the HM module. The tiling layout is Hyprland's built-in
`scrolling` (in core since 0.54), so the niri column model carries over. Wiki:
<https://wiki.hypr.land/Configuring/>.

Which shell owns the session is `kyan.desktop.shell` (enum `dms` |
`formalshell`, defined in `modules/nixos/mixins/hyprland.nix`). Both Linux hosts run
`formalshell` now: the e1504g as the trial, the g815 promoted 2026-08-10. DMS
stays installed but dormant on both, so rollback is deleting the host's one
line. The theming section below still describes the DMS path.

The g815 is back online (2026-08-10) and is the e1504g's build host again. If it
ever goes down for a stretch, remember that `/etc/nix/machines` lists it twice
(Tailscale, then LAN) ahead of the macbook's rosetta builder and nix walks that
list per derivation, so every e1504g build pays two SSH connect timeouts
(measured 2026-08-04: 4m35s per derivation) before falling back to local. Pin
the mac as the only builder to skip that:

```
ssh e1504g 'cd ~/.config/nix && sudo -n /run/current-system/sw/bin/nixos-rebuild switch --flake .#e1504g \
  --option builders "ssh-ng://builder@macbook-rosetta x86_64-linux /root/.ssh/nix-builder 6 3 big-parallel,benchmark - -"'
```

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
  `lib.optionals/​optionalAttrs pkgs.stdenv.hostPlatform.isDarwin/isLinux`; platform-only
  mixins are imported solely from `darwin.nix`/`linux.nix` and need no guard.

## Theming model (g815 desktop)

Colours are **wallpaper-derived (matugen/M3) via DMS** (Dank Material Shell,
since 2026-07-20; it replaced Noctalia), the single source of truth. DMS runs
matugen on every wallpaper pick / light-dark flip: its built-in templates theme
GTK (`~/.config/gtk-{3,4}.0/dank-colors.css`, imported via gtk.css) and Qt
(`~/.config/qt{5,6}ct/colors/matugen.conf`), and it merges our user templates
(`users/kyandesutter/matugen-templates/`, registered via the generated
`~/.config/matugen/config.toml` in `mixins/dms.nix`: aura, ghostty, neovim,
obsidian, hypr-border, btop, yazi) into the
same matugen run, executing each template's post_hook. Hyprland's window borders
are themed through the `hypr-border` template: it renders
`~/.cache/dank/hypr-border.lua` (an `hl.config({ general = { col = … } })` call)
and its post_hook applies it live with `hyprctl eval 'pcall(dofile, …)'`;
`hyprland.lua` runs the same `pcall(dofile, …)` at the bottom of the config so a
later `hyprctl reload` keeps the wallpaper colours instead of snapping back to
the static Flexoki `general.col`. DMS's `settings.json` is runtime-mutable
(NOT home-manager-managed): `mixins/dms.nix` seeds it once if absent — idle
blanking must stay disabled there (eDP-1 wake-modeset bug). **Flexoki is only a
static fallback** for consumers that genuinely can't be dynamic: Neovim's
pre-palette colourscheme, Hyprland's pre-palette border colours (the static
`general.col` in `mixins/hyprland.nix`), and CLI tools with no matugen
template (bat, fzf, lazygit, fish). Per-wallpaper Flexoki *pinning* lives on as
`flexoki-pin.service` (`mixins/dms.nix`): it watches DMS's session.json and
pins/unpins the Flexoki custom theme while a flexoki-named wallpaper is active
(same substring match as the old Noctalia `flexoki-scheme` hook). The Flexoki palette is
pure Nix data in
`users/kyandesutter/mixins/flexoki/palette.nix` (base tones + accents + ready
`light`/`dark` terminal views), and `mixins/flexoki/` themes the CLI tools from
it — static Flexoki dark on Linux, appearance-following light/dark on macOS
(where Flexoki is the *primary* scheme, not a fallback: Ghostty uses its built-in
Flexoki Light/Dark, bat uses `auto:system`, fish re-selects by appearance). The
greeter and the lock screen sit outside all of it: both are qylock on `sword`
(`programs.qylock` in `modules/nixos/mixins/hyprland.nix`), since the greeter
runs before any user session exists and so has no wallpaper to derive colours
from. Herdr pins Flexoki Dark via `[theme.custom]` tokens
sourced from `palette.nix` (`mixins/herdr.nix`) — it used to follow ghostty via its `terminal` theme, but
that reads the terminal palette over OSC, which doesn't survive SSH/mosh (herdr
runs on the macbook, reached over SSH), so the static tokens keep it correct and
low-contrast remotely. When
adding a themed surface, prefer a matugen user template + a Flexoki fallback
derived from `palette.nix` (see the `hypr-border` template in `mixins/dms.nix`
for the render + static-fallback pattern).

## GPU and power (g815)

The g815 lives on the barrel charger and is never used on battery. Nothing in
the config reacts to the power source any more: the classifier, profile
switching, dGPU power toggling, idle suspend and relog prompts were all
removed on 2026-08-24 (git has them). What remains:
- The ASUS MUX routes the internal panel through the dGPU
  (`gpu-mux-dgpu.service` in `systems/g815/default.nix` writes
  `asus-nb-wmi/gpu_mux_mode=0`, firmware-persistent, applies at the next boot;
  Windows boots in the same mode). Both the panel (matched by `desc:` since
  its connector name follows the driver) and HDMI-A-1 scan out from the RTX
  5070; the iGPU is idle and not named in
  `AQ_DRM_DEVICES` (`~/.config/uwsm/env-hyprland`,
  `users/kyandesutter/mixins/hyprland.nix`).
- `modules/nixos/mixins/nvidia.nix`: open driver, `powerManagement.enable`
  (nvidia-suspend/resume services + VRAM preservation), PowerMizer max, VA-API
  on nvidia. PRIME and the per-app GPU wrappers are gone.
- tuned-ppd starts in `performance` (`services.tuned.ppdSettings` on the g815).
- `modules/nixos/mixins/asus.nix`: asusd, 80% charge limit, Aura keyboard seed.
- `lock-before-sleep` (`modules/nixos/mixins/hyprland.nix`) starts
  `qylock-lock.service` before sleep.target and must never fail (exit-0 always)
  so a dead session can't block suspend.

## Autostart (g815)

DE-agnostic login apps (Steam, Helium, Discord, …) are home-manager
`systemd.user.services` bound to `graphical-session.target` in
`users/kyandesutter/mixins/autostart.nix` (uwsm ties the compositor to that
target, so they follow the session). Nothing is compositor-hook-launched: there
is no `hl.on("hyprland.start", …)` block at all, and FormalShell registers its
own in-shell polkit agent. Alt-Tab is `hl.dsp.window.cycle_next()`; Hyprland has no
most-recently-used hold-and-cycle switcher, so niri's `recent-windows` and its
Alt+grave same-app cycle have no equivalent here.

## Tooling

Prefer `fd` (find), `rg` (grep). For broad code analysis, delegate to the
code-searcher subagent. Never proactively create docs/*.md unless asked.
