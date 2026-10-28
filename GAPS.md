# Not ported from NixOS

Source: the NixOS and Home Manager generations on the e1504g and the g815. The Tumbleweed root is
`spec.star`, `system.star` (shared Linux root, `e1504g/rootfs/`), `home.star` (shared home,
`home/`, overlaid by `<host>/home/`) and `g815.star` (`g815/rootfs/`). `image.star` is the
earlier Fedora Atomic image and nothing loads it.

## Both Linux hosts

### Not verified

- uxplay and colloid-icon-theme run as `fspec-packages.yml` jobs; nothing has applied them yet.
- Discord 1.0.160 with moonlight from Discord's distro and module archives (`pkg(parts = ...)`) and
  `~/.local/bin/discord`, which links the modules into `~/.config/discord` and skips the host update
  as nixpkgs' wrapper does: not applied yet. It replaces the Flathub Discord, so the e1504g's
  `~/.var/app/com.discordapp.Discord` login stays behind.

### Version differences from NixOS

- vscode-langservers-extracted 4.10.0 from npm; NixOS packages 1.126.04524, not published to npm.
- gopls, lua-language-server, tree-sitter, typescript and uv are Tumbleweed's versions, not
  nixpkgs'. taplo comes from Tumbleweed (aqua resolves `tamasfe/taplo` ambiguously against
  `tamasfe/taplo/full`, an fspec bug).
- python313-streamdeck 0.9.8 lacks the Stream Deck PID 0x00b3 that NixOS's git build
  (ac67de1f70) has.
- ananicy-cpp 1.2.0 is built without the BPF process backend.

### Dropped

- dcal (DankCalendar) and the quickshell its UI needs: FormalShell reads local `.ics` directories
  and cannot read dcal's IPC, so NixOS already had its service forced off.
- Android Studio, codex: not in the generations.
- dillo and terminal-browser: no longer wanted.
- `.cache/nix-index`, comma, fish `nix`/`rebuild`, `NH_FLAKE`, `nixpkgs/config.nix`,
  `hm-nix-direnv.sh`, `10-hm-fonts.conf`: Nix only. `cnf` replaces command-not-found and the
  `fish-completions` timer regenerates completions.
- formalmusic-maintenance: deploys through the nix flake.
- nix-daemon builder key and `/etc/nix/machines`: `host(builders = [builder("g815", ...)])`.
- tzupdate: the zone is fixed.
- fastfetch's background-refreshed pkgs count: it works around `nix-store` queries stalling on a
  busy nix daemon, which Tumbleweed does not have.
- `t3code-cli-sync`: it needs `t3code-cli-sync.mjs` and a `t3` built with nix's
  `t3code-import-new-turns.patch`; the spec ships upstream's 0.1.3 release.
- DankMaterialShell, `dms.service`, `flexoki-pin.service`: replaced by FormalShell.
- `tray.target`, `.keep` placeholders: Home Manager and NixOS only.
- `.config/net.imput.helium/WidevineCdm`: Helium's component updater fetches it.
- matugen `aura` template: the ASUS Aura repaint is a NixOS module; `asus-aura` seeds the keyboard.

### Changed behaviour

- App logins, the Helium profile and its Safe Storage key, and the wallpapers move with
  `fspec sync` (`sync.star`). Flare, Beeper and 1Password are linked per device, never synced;
  the e1504g's old `~/.local/share/flare` stays where it is.
- `.claude/CLAUDE.md`, `.claude/hooks`, `.pi/agent/*` were symlinks into `~/.config/nix`; they are
  copies now, so an edit there needs a re-apply here.
- Store tools live in `/opt/fspec/current/bin`, which `environment.d` and fish put on PATH;
  Hyprland binds, meshtop's entries and the scripts call them there.
- `dualsense-herdr` and `streamdeck-keys` keep `/etc/profiles/per-user/kyandesutter/bin/herdr`:
  the macbook's path, reached over ssh.
- Units are `fspec-<name>.service` and exec directly instead of `bash -lc`.
- ananicy-cpp and asusd run from a `service()` with the store path, since their upstream units
  name `/usr/bin`; asusd's dbus policy is linked from its package with `etc`.
- dconf loads through `fspec-dconf-load` and `.Xresources` through `fspec-xrdb-merge` at login.
- nvim plugins come from `vim.pack` pinned by `nvim-pack-lock.json`; nvim-treesitter compiles its
  parsers on first start.
- `programs.ssh.knownHosts` is `/etc/ssh/ssh_known_hosts`; the NixOS firewall is firewalld zones;
  `nix.gc` is the `fspec-gc` timer; scripts NixOS wrapped live in `/usr/local/libexec`.
- `/home` is shared with the NixOS root, which has no Home Manager, so the home belongs to this
  layer.

## e1504g

Nothing beyond the shared list.

## g815

### Port

Windows (p2, p3, p4, p6) and the partition table are never touched; only p5 is converted and only
the FAT inside p1 grows. Every step keeps the g815 on Wi-Fi, ssh and tailscale.

1. `umount /boot`, `dd` p1 whole to `/root/esp-p1.img` and to the external disk, grow its FAT32
   (446 MiB) to fill the 1 GiB partition with `fatresize`, `fsck.fat -n` it and `mount /boot`.
2. In `~/.config/nix`, point `.#g815` at systemd-boot (the bootloader block of
   `systems/g815/fspec-migration.nix`), `nixos-rebuild boot --install-bootloader` (systemd-boot is
   already on the ESP behind Limine, and a plain rebuild would not move it to the front), reboot,
   and require `bootctl status` to show `Product: systemd-boot` as the current boot loader. Check it
   lists Windows Boot Manager, that `EFI/Microsoft/Boot/bootmgfw.efi` hashes as it did before step
   1 and that `efibootmgr` still has the firmware's Windows Boot Manager entry. Booting Windows to
   check would strand the g815 there, out of reach. Only then delete `/boot/limine`, which the
   Limine menu booted until now. `umount /boot`, `dd` p1 again to `/root/esp-p1-sdboot.img` and
   the external disk, `mount /boot`: it holds the `EFI/nixos` kernels the new entries load, which a
   rollback after `forget nixos` needs. Keep both images.
3. Static fspec to `/usr/local/bin/fspec` (the ISO build's musl binary); the ISO from
   `installer/iso/build.sh --release`.
4. `tar` of `/` without `/nix` to the external disk, then
   `fspec disk migrate --stage <iso> --nixos-system <g815-btrfs> --backup <tar> --overlay
   /root/g815-overlay.tar` and reboot. The overlay carries the Wi-Fi connections, tailscale state,
   root's authorized keys and a guard that needs tailscale online.
5. In `@nixos`: fold `fspec-migration.nix` into `.#g815` before any rebuild, then
   `fspec switch --beside tumbleweed --inherit @nixos`.
6. Mount `@tumbleweed`, install the static fspec at `usr/local/bin/fspec` in it and a
   `etc/sudoers.d/99-first-apply` with `kyandesutter ALL=(ALL) NOPASSWD: ALL`: the inherited wheel
   rule (`50-fspec-inherit`) asks for a password and sudoers lets the later file win, and
   pam_ssh_agent_auth only arrives with the first apply.
   Copy `/var/lib/bluetooth` from `@nixos` too: the pairings are the only system state worth
   keeping that `--inherit` does not carry (Wi-Fi and tailscale it does).
7. `bootctl set-oneshot tumbleweed-<kernel>.conf`, the id `bootctl list` shows (no `+3`), and reboot, so a failed boot lands in
   NixOS again. Check ssh, tailscale and the Windows entry, then `fspec apply --host g815` from the
   macbook and delete `99-first-apply`.
8. The first apply writes Limine with `preferred tumbleweed-*`. `--adopt-boot` does not cover a
   root installed with `--beside`, so check `loader.conf` names no NixOS entry and Tumbleweed has
   its own entries, reboot, then `fspec forget nixos`.
9. Declare the 16G swapfile in `@swap` in `g815.star` and apply: zram covers swap until then,
   since Tumbleweed would overwrite the swapfile of a hibernated NixOS.

### Not verified

- macos-vm (macOS 10.9 guest): OpenCore 1.0.7 from its release zip as a `github(...)` package, the
  config.plist render and ESP image in the `macos-vm` launcher (cached under
  `~/.local/share/macos-vm`), `macos-vm-fetch` and the guest installer. Built from the nix module
  but never run on the g815.
- libvirt (virtqemud and the network and storage sockets), Steam's gamescope session in the greeter
  and the FormalShell smoke rig users: not applied yet.
- The rig nests Tumbleweed's Hyprland, whose aquamarine 0.15.1 lacks hyprwm/aquamarine#415 that
  NixOS patches in, so the nested session gets no monitor until Tumbleweed ships a newer one.

### Version differences from NixOS

- NVIDIA G07 from NVIDIA's openSUSE repo is 595.x; NixOS runs 615.71.09 and nvidia-settings.

### Dropped

- `checkReversePath = false`: no longer in the nix config. Tumbleweed's IPv4 rp_filter is loose.
- aarch64-linux binfmt emulation and nix's min-free/max-free: they only serve nix builds.
- gamescope's `cap_sys_nice`: fspec has no file capabilities and Tumbleweed's gamescope ships none.

## macbook

See `macbook/GAPS.md`.
