# ASUS G815 proper support — design

Date: 2026-06-16
Host: `g815` (ASUS ROG Zephyrus, Intel Core Ultra 9 275HX + NVIDIA RTX 5070 Mobile, Hyprland + Caelestia, Catppuccin Mocha)

## Goals

1. Fix flaky battery detection in the Caelestia bar.
2. Make ASUS support always-on (not gated behind gaming).
3. Theme the Aura keyboard RGB to Catppuccin Mauve, static, dimmed on battery.
4. Set a 80% battery charge limit for longevity.
5. Set `river-city.jpg` as the wallpaper, tracked in-repo.

## Non-goals (deliberately excluded)

- `supergfxd` / MUX switching — needs a relog; already documented as impractical.
- OpenRGB — keyboard-only was chosen; no other RGB peripherals.
- `power-profiles-daemon` — conflicts with asusd platform profiles; not needed for battery detection.

## Background / root causes

- **Battery:** Caelestia reads battery state from **UPower** over D-Bus. `services.upower.enable` is set nowhere in the config; it has relied on D-Bus auto-activation, which is unreliable. This is the cause of flaky battery detection.
- **ASUS gating:** `modules/nixos/mixins/asus.nix` wraps everything in `lib.mkIf config.kyan.gaming.enable`, so `asusd` and all ASUS features disappear outside the gaming profile.
- **asusctl version:** `6.3.8` (v6 CLI), verified on hardware — `asusctl aura effect static -c <hex>` (`-c` takes RRGGBB, no `#`), `asusctl battery limit <20-100>` for charge limit. Keyboard LED node `/sys/class/leds/asus::kbd_backlight` (max_brightness 3); AC adapter is `ADP0` (`online` 0/1).
- **Caelestia wallpaper:** `caelestia wallpaper -f <path>` writes `~/.local/state/caelestia/wallpaper/path.txt`, regenerates a Material You scheme into `scheme.json`. The existing `home.activation.caelestiaScheme` hook re-pins Catppuccin Mocha, so Mocha wins as long as the wallpaper is set first.

## Design

### 1. UPower (battery fix)

Add to `modules/nixos/mixins/hyprland.nix`, inside the `kyan.desktop.enable` config block (it belongs with the graphical desktop that consumes it, so any desktop host benefits):

```nix
services.upower.enable = true;
```

### 2. New `kyan.asus.enable` option (decouple from gaming)

Refactor `modules/nixos/mixins/asus.nix`:

- Add `options.kyan.asus.enable = lib.mkEnableOption "ASUS laptop support (asusd, Aura RGB, charge limit)";`
- Move `services.asusd.enable = true`, the charge-limit + Aura oneshot, and the dim-on-battery udev rule under `lib.mkIf config.kyan.asus.enable`.
- Keep the `game-mode` script + package under `lib.mkIf config.kyan.gaming.enable` (it is gaming-specific). `game-mode` uses `asusctl`, which is fine because the g815 enables both.
- Enable it for the host: add `kyan.asus.enable = true;` to `systems/g815/default.nix`.

This mirrors the existing `kyan.desktop` / `kyan.gaming` option pattern. Other hosts (macbook = darwin, future linux hosts) are unaffected because the option defaults to false.

### 3. Aura keyboard RGB — Catppuccin Mauve, static

A systemd **oneshot** service that runs after `asusd.service`:

```nix
systemd.services.asus-aura = {
  description = "Set Aura keyboard to Catppuccin Mauve + 80% charge limit";
  after = [ "asusd.service" ];
  requires = [ "asusd.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig.Type = "oneshot";
  serviceConfig.RemainAfterExit = true;
  script = ''
    ${pkgs.asusctl}/bin/asusctl aura effect static -c cba6f7 || true  # Mocha Mauve
    ${pkgs.asusctl}/bin/asusctl battery limit 80 || true              # 80% limit
  '';
};
```

- Mauve = `#cba6f7` → passed as `cba6f7`.
- `|| true` + logging so a flag mismatch never fails activation/boot.
- Exact `aura static -c` / `-c` flags verified against the pinned asusctl 6.3.8 binary during implementation (`asusctl --help`, `asusctl aura --help`); adjust if the subcommand differs.

### 4. Battery charge limit 80%

Folded into the same `asus-aura` oneshot above (`asusctl battery limit 80`). Using `asusctl` (not raw sysfs) lets asusd own/persist the threshold and avoids fighting it.

### 5. Dim keyboard on battery

A udev rule reacting to AC power state, writing the keyboard backlight brightness node. The helper enumerates `/sys/class/leds/*kbd_backlight*` so it tolerates the exact node name (`asus::kbd_backlight`).

```nix
# pseudostructure — implemented as a small script invoked by a udev RUN+= rule
# on SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE} change:
#   online == 1 (AC)      -> brightness = max
#   online == 0 (battery) -> brightness = 0 (off)
```

Color (static Mauve) is unchanged; only brightness toggles. Implementation will use `services.udev.extraRules` plus a `writeShellScript` helper, or `brightnessctl`. Exact rule keys verified on hardware during implementation.

### 6. River-city wallpaper

- Add the image to the repo: `users/kyandesutter/wallpapers/river-city.jpg` (copied from `~/Downloads/river-city.jpg`), and `git add` it (flakes only see tracked files).
- In `users/kyandesutter/mixins/caelestia.nix`, add an activation step (before the existing `caelestiaScheme` re-pin) that runs:
  ```
  caelestia wallpaper -f <store path of ../wallpapers/river-city.jpg>
  ```
  Pointing at the immutable nix store path keeps it reproducible. Guard it so it is a no-op when already set, and never fails the switch (`|| true`).
- Ordering: wallpaper set first → Material You auto-scheme generated → existing `caelestiaScheme` hook re-pins Catppuccin Mocha. Mocha wins.

## Files touched

| File | Change |
| --- | --- |
| `modules/nixos/mixins/hyprland.nix` | add `services.upower.enable = true` |
| `modules/nixos/mixins/asus.nix` | add `kyan.asus.enable` option; move asusd + aura/charge oneshot + dim-on-battery udev under it; keep game-mode under gaming |
| `systems/g815/default.nix` | add `kyan.asus.enable = true` |
| `users/kyandesutter/mixins/caelestia.nix` | add wallpaper activation step |
| `users/kyandesutter/wallpapers/river-city.jpg` | new (git-tracked image) |

## Verification

- Cannot rebuild (owner-only rule). Stage all changes with `git add`, document, hand off to owner for `nixos-rebuild`.
- During implementation, verify exact `asusctl` flags against 6.3.8 and the kbd_backlight LED node name.
- Post-rebuild checks for the owner: battery shows in Caelestia bar; `asusctl -c` reports 80; keyboard is Mauve on AC and off on battery; wallpaper is river-city with Mocha colors.
