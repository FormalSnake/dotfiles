# NixOS gaming host `g815` — setup plan

Adds a second host to this flake-parts config: a NixOS gaming/coding laptop, **without
touching the existing `macbook` (nix-darwin) host**. The laptop is an **Asus ROG Strix
G18 G815LP-S9034** (Intel Core Ultra 9 275HX "Arrow Lake-HX", RTX 5070 Laptop "Blackwell",
32 GB RAM, 1 TB SSD, 18" WQXGA 240 Hz). Used primarily for gaming, some coding.

## Decisions (locked)

- **Kernel:** CachyOS via the `chaotic` flake (`nyxpkgs-unstable`) + `services.scx`
  (sched-ext, `scx_bpfland`) for the 24-thread P/E hybrid.
- **GPU:** RTX 5070 Blackwell → `hardware.nvidia.open = true` (mandatory), **PRIME offload**
  (`nvidia-offload` wrapper). dGPU auto-powers when the external monitor is plugged in.
- **No supergfxd / no MUX switching** (would require a relog). "Game mode" is a runtime
  asusd profile toggle instead — no relog.
- **Desktop:** Hyprland + **caelestia** shell (official flake `homeManagerModules.default`),
  full-experience config. Keybinds mirror the macOS/aerospace muscle memory with **SUPER**
  as primary mod; **SUPER+Space** = app launcher.
- **Boot:** systemd-boot, auto-detects Windows. **No Secure Boot / no lanzaboote** (casual
  Fortnite doesn't require it; only tournaments do). Laptop ships with no OS → install
  Win11 into its own partition, then NixOS alongside.
- **Browser:** Helium via `github:schembriaiden/helium-browser-nix-flake` overlay → `web` ws.
- **Home mixins:** `herdr` is cross-platform (comes to laptop). `rift` + `lynk-browser` stay
  macOS-only. Shared dev env (fish, neovim, git, gh, ssh, claude-code, pi, tmux, catppuccin,
  fastfetch, ghostty, programs.nix tools) comes to the laptop.

## Hardware items that can only be done on the real machine

- [ ] `nixos-generate-config` → real `systems/g815/hardware-configuration.nix` (fileSystems,
      LUKS, swap, initrd modules). The committed file is a **placeholder template**.
- [ ] Read PCI bus IDs: `lspci -D | grep -E "VGA|3D"`, convert hex→decimal, fill
      `prime.intelBusId` / `prime.nvidiaBusId` in `systems/g815/default.nix`.
- [ ] Generate a host age key and add it to `secrets/secrets.nix`, then `agenix -r`
      (linux secrets are stubbed until then).
- [ ] Verify G815**LP** speaker audio (upstream quirk is documented for G815**LR**).
- [ ] Confirm MT7925 Wi-Fi stability (module + powersave fixes already wired).
- [ ] Test suspend/resume (open-NVIDIA s2idle regression on bleeding-edge kernels).

---

## Status

All five phases implemented and committed. `flake.lock` updated. `nix eval` of
`.#nixosConfigurations.g815` used to shake out option errors (fixed: conditional-import
recursion, `asusd.enableUserService` removal, `cpu.intel.npu` non-option). Remaining
verification is hardware-only (see the checklist above).

## Implementation tasks

### Phase 1 — Plumbing / skeleton
- [ ] `flake.nix`: add inputs `nixos-hardware`, `chaotic` (nyxpkgs-unstable), `caelestia-shell`,
      `helium`.
- [ ] `modules/default.nix`: import `./nixos` alongside `./darwin`.
- [ ] `modules/nixos/default.nix`: `flake.nixosModules.default` = shared + nixos mixins + profiles.
- [ ] `modules/nixos/mixins/nix.nix`: experimental-features, chaotic substituter+key, gc, optimise.
- [ ] `modules/nixos/mixins/users.nix`: `kyandesutter` normal user (wheel/networkmanager/video/
      audio/input/gamemode), `programs.fish.enable`, default shell fish.
- [ ] `modules/nixos/mixins/home-manager.nix`: import HM nixosModule, useGlobalPkgs/UserPackages.
- [ ] `modules/nixos/mixins/locale.nix`: timezone `Atlantic/Canary`, i18n, console, keymap.
- [ ] `modules/nixos/mixins/networking.nix`: NetworkManager, firewall.
- [ ] `modules/nixos/mixins/agenix.nix`: import agenix nixosModule, host identity TODO, secrets stubbed.
- [ ] `modules/nixos/profiles/{default,desktop,gaming}.nix`: `kyan.profiles.{desktop,gaming}` options.
- [ ] `systems/default.nix`: add `flake.nixosConfigurations.g815`.
- [ ] `systems/g815/default.nix`: hostPlatform, hostname, nixos-hardware imports, HM wiring,
      prime busId placeholders, stateVersion.
- [ ] `systems/g815/hardware-configuration.nix`: placeholder template with TODO header.

### Phase 2 — Kernel + GPU
- [ ] `modules/nixos/mixins/boot.nix`: systemd-boot, `linuxPackages_cachyos`, kernel params.
- [ ] `modules/nixos/mixins/scx.nix`: `services.scx` (`scx_bpfland`).
- [ ] `modules/nixos/mixins/graphics.nix`: `hardware.graphics.enable + enable32Bit`.
- [ ] `modules/nixos/mixins/nvidia.nix`: open driver, modesetting, prime offload, powerManagement,
      Wayland env vars.

### Phase 3 — Desktop (Hyprland + caelestia)
- [ ] `modules/nixos/mixins/hyprland.nix`: `programs.hyprland`, xdg portals, polkit, greetd/login.
- [ ] `modules/nixos/mixins/audio.nix`: pipewire (alsa/pulse/jack) + rtkit.
- [ ] `users/kyandesutter/mixins/hyprland.nix`: monitors (eDP-1 240Hz + external 1440p), keybinds
      (SUPER mirror of aerospace), window→workspace rules, animations/look, autostart.
- [ ] `users/kyandesutter/mixins/caelestia.nix`: import caelestia HM module + `programs.caelestia`.
- [ ] `users/kyandesutter/mixins/helium.nix`: helium overlay + package, default browser, web ws.

### Phase 4 — Gaming + game-mode + ASUS
- [ ] `modules/nixos/mixins/gaming.nix`: steam (+proton-ge, gamescopeSession, firewall),
      gamescope, gamemode, mangohud, vkbasalt, lutris, heroic, obs, vesktop.
- [ ] `modules/nixos/mixins/asus.nix`: `services.asusd` + `game-mode` writeShellApplication
      (asusd Performance ↔ balanced, no relog).

### Phase 5 — Home split + polish
- [ ] `users/kyandesutter/default.nix`: split imports shared / `lib.optionals isDarwin` /
      `lib.optionals isLinux`; conditional `homeDirectory`.
- [ ] Verify shared mixins eval on Linux (ghostty `package = null` is darwin-specific → guard).
- [ ] `git add` everything (flakes only see tracked files); owner rebuilds.

---

## Install runbook (owner, on the hardware)

1. Partition 1 TB: EFI (~1 GB), Windows (~200 GB for Win11 + Fortnite), rest for NixOS.
   Install **Windows first**, then NixOS.
2. Boot NixOS installer, `nixos-generate-config`, copy `hardware-configuration.nix` into
   `systems/g815/`, `git add` it.
3. `lspci -D | grep -E "VGA|3D"` → fill bus IDs in `systems/g815/default.nix`.
4. `sudo nixos-rebuild switch --flake .#g815`.
5. Post-boot: enroll age host key, re-encrypt secrets, verify audio/wifi/suspend, test a game
   via `gamescope`/`nvidia-offload`, toggle `game-mode`.
