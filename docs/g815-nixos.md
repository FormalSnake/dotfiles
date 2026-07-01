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
- **Desktop:** Hyprland + **noctalia** V5 shell (native C++/OpenGL ES, official flake
  `homeModules.default`), full-experience config. Keybinds mirror the macOS/aerospace muscle
  memory with **SUPER** as primary mod; **SUPER+Space** = app launcher.
- **Boot:** Limine (Catppuccin-themed menu), Windows via a chainload entry; a Noctalia
  "Windows" button does a one-shot UEFI BootNext and a "BIOS" button reboots to firmware
  setup. **No Secure Boot / no lanzaboote** (casual
  Fortnite doesn't require it; only tournaments do). Laptop ships with no OS → install
  Win11 into its own partition, then NixOS alongside.
- **Browser:** Helium via `github:schembriaiden/helium-browser-nix-flake` overlay → `web` ws.
- **Home mixins:** `herdr` is cross-platform (comes to laptop). `aerospace` + `lynk-browser` stay
  macOS-only. Shared dev env (fish, neovim, git, gh, ssh, claude-code, pi, tmux, catppuccin,
  fastfetch, ghostty, programs.nix tools) comes to the laptop.

## Hardware items that can only be done on the real machine

- [ ] `nixos-generate-config` → real `systems/g815/hardware-configuration.nix` (fileSystems,
      LUKS, swap, initrd modules). The committed file is a **placeholder template**.
- [x] Read PCI bus IDs: `lspci -D | grep -E "VGA|3D"`, convert hex→decimal, fill
      `prime.intelBusId` / `prime.nvidiaBusId` in `systems/g815/default.nix`.
      Verified on hardware: Intel `0000:00:02.0` → `PCI:0:2:0`, NVIDIA `0000:02:00.0`
      → `PCI:2:0:0`.
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
- [ ] `flake.nix`: add inputs `nixos-hardware`, `chaotic` (nyxpkgs-unstable), `noctalia`,
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
- [ ] `modules/nixos/mixins/boot.nix`: Limine, `linuxPackages_cachyos`, kernel params.
- [ ] `modules/nixos/mixins/scx.nix`: `services.scx` (`scx_bpfland`).
- [ ] `modules/nixos/mixins/graphics.nix`: `hardware.graphics.enable + enable32Bit`.
- [ ] `modules/nixos/mixins/nvidia.nix`: open driver, modesetting, prime offload, powerManagement,
      Wayland env vars.

### Phase 3 — Desktop (Hyprland + noctalia)
- [ ] `modules/nixos/mixins/hyprland.nix`: `programs.hyprland`, xdg portals, polkit, greetd/login.
- [ ] `modules/nixos/mixins/audio.nix`: pipewire (alsa/pulse/jack) + rtkit.
- [ ] `users/kyandesutter/mixins/hyprland.nix`: monitors (eDP-1 240Hz + external 1440p), keybinds
      (SUPER mirror of aerospace), window→workspace rules, animations/look, autostart.
- [ ] `users/kyandesutter/mixins/noctalia.nix`: import noctalia HM module + `programs.noctalia`.
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

1. Partition 1 TB: EFI (~1 GB), Windows (~256 GB for Win11 + Fortnite), rest for NixOS.
   Install **Windows first**, then NixOS.
2. Boot NixOS installer, `nixos-generate-config`, copy `hardware-configuration.nix` into
   `systems/g815/`, `git add` it.
3. `lspci -D | grep -E "VGA|3D"` → fill bus IDs in `systems/g815/default.nix`.
4. `sudo nixos-rebuild switch --flake .#g815`.
5. Post-boot: enroll age host key, re-encrypt secrets, verify audio/wifi/suspend, test a game
   via `gamescope`/`nvidia-offload`, toggle `game-mode`.

---

## Install guide (step-by-step)

Detailed expansion of the runbook above. Flake target is **`.#g815`**; repo is
`github.com/FormalSnake/dotfiles`, lives at `~/.config/nix`. The laptop ships with **no OS**,
so Windows is installed from scratch first, then NixOS alongside it (shared ESP; Limine
chainloads the Windows Boot Manager).

Three things in the repo are **placeholders** that only the real hardware can fill, and the
flake is not fully correct until all three are done:

1. `systems/g815/hardware-configuration.nix` — filesystems / UUIDs
2. PRIME GPU bus IDs in `systems/g815/default.nix` (the two `TODO verify` lines)
3. The age host key — `secrets/secrets.nix` recipient + the commented `age.secrets` block in
   `modules/nixos/mixins/agenix.nix`

### Phase 0 — BIOS (before installing anything)

- **Disable Intel VMD / RAID** (set NVMe/SATA to AHCI). ASUS ships VMD on, which hides the NVMe
  from the Linux installer. Do this *before* Windows so Windows also installs in AHCI mode —
  flipping it afterwards breaks Windows boot.
- **Disable Secure Boot** (locked decision: no lanzaboote).
- Confirm UEFI mode (no CSM/Legacy).

### Phase 1 — Partition + install Windows first

Boot the **NixOS minimal ISO** and pre-partition the whole disk. A **1 GB ESP** is deliberate —
the CachyOS kernel + NVIDIA modules + multiple generations won't fit in the ~100 MB ESP Windows
makes by default.

```sh
lsblk                          # confirm the disk, likely /dev/nvme0n1
sudo gdisk /dev/nvme0n1
```

Create (in gdisk: `n` per partition, `w` to write):

| # | Size   | Type   | Purpose                       |
|---|--------|--------|-------------------------------|
| 1 | +1G    | `ef00` | EFI System Partition (shared) |
| 2 | +16M   | `0c01` | Microsoft Reserved (MSR)      |
| 3 | +256G  | `0700` | Windows C:                    |
| 4 | (rest) | `8300` | NixOS root                    |

Then **install Windows 11**: select partition **3**, format it, install. Windows reuses the
1 GB ESP and the MSR. Finish OOBE, run Windows Update + ASUS drivers once so it's stable.

### Phase 2 — Install NixOS alongside

Boot the NixOS ISO again. **Do not reformat partition 1** — Windows lives on that ESP; only
mount it.

```sh
sudo mkfs.ext4 -L nixos /dev/nvme0n1p4        # format ONLY the NixOS root
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot           # the existing Windows ESP
# (optional swap — the placeholder has none; add if you want hibernate)

sudo nixos-generate-config --root /mnt        # writes the real hardware-configuration.nix
```

Pull the flake in and drop the generated hardware config into it:

```sh
export NIX_CONFIG="experimental-features = nix-command flakes"
nix-shell -p git

sudo git clone https://github.com/FormalSnake/dotfiles.git /mnt/etc/nixos/nix-config
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
        /mnt/etc/nixos/nix-config/systems/g815/hardware-configuration.nix
sudo git -C /mnt/etc/nixos/nix-config add systems/g815/hardware-configuration.nix
```

Install — **pass the chaotic cache explicitly** so the CachyOS kernel downloads instead of
compiling from source:

```sh
sudo nixos-install --flake /mnt/etc/nixos/nix-config#g815 \
  --option substituters "https://cache.nixos.org https://nyx-cache.chaotic.cx/" \
  --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
```

Set the **root** password when prompted, reboot, pull the USB. Limine should list **NixOS**
and **Windows 11**.

### Phase 3 — First boot, on the hardware

Log in (as root if the user has no password yet, then `passwd kyandesutter`). Put the repo where
daily rebuilds expect it:

```sh
git clone https://github.com/FormalSnake/dotfiles.git ~/.config/nix
cd ~/.config/nix
```

> ⚠️ The `justfile` recipes (`just r`, etc.) are **macOS-only** — they target `#macbook` with
> `darwin-rebuild`. On the laptop, rebuild directly:
> ```sh
> sudo nixos-rebuild switch --flake ~/.config/nix#g815
> ```

**3a — PRIME GPU bus IDs**

```sh
lspci -D | grep -E "VGA|3D"
```

Convert each `domain:bus:dev.fn` from hex to decimal `PCI:bus:dev:fn` in
`systems/g815/default.nix` (e.g. Intel `0000:00:02.0` → `PCI:0:2:0`; NVIDIA `0000:01:00.0` →
`PCI:1:0:0`; but if the NVIDIA bus shows hex `65`, that's decimal `101` → `PCI:101:0:0`).
`git add`, rebuild.

**3b — Enroll the age host key (unlocks the API-key secrets)**

```sh
nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub   # prints age1...
```

Add that `age1...` to `secrets/secrets.nix` (alongside `kyan`), then re-encrypt and enable:

```sh
cd ~/.config/nix/secrets
nix run github:ryantm/agenix -- -r
# uncomment the age.secrets = … block in modules/nixos/mixins/agenix.nix
cd ~/.config/nix && git add -A
sudo nixos-rebuild switch --flake ~/.config/nix#g815
```

Until enrolled, secrets are simply absent — harmless, since the fish mixin reads `/run/agenix/*`
defensively.

**3c — Hardware-only verification** (see the checklist near the top of this doc)

- Speaker audio (G815**LP** — quirk documented for the LR variant)
- MT7925 Wi-Fi/BT stability
- Suspend/resume (open-NVIDIA s2idle can regress on bleeding-edge kernels)
- A game via `gamescope` / `nvidia-offload`; toggle `game-mode` (asusd Performance ↔ balanced,
  no relog)
