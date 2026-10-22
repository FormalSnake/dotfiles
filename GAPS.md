# Not ported from NixOS

Source: the NixOS and Home Manager generations on the e1504g and the g815. The Tumbleweed root is
`spec.star`, `system.star` (shared Linux root, `e1504g/rootfs/`), `home.star` (shared home,
`home/`, overlaid by `<host>/home/`) and `g815.star` (`g815/rootfs/`). `image.star` is the
earlier Fedora Atomic image and nothing loads it.

## Both Linux hosts

### Open: fspec has no way to express it yet

- Users run before Packages, so on a first apply `usermod -aG docker,uinput,nordvpn,ancs4linux`
  runs before the rpms and `/etc/sysusers.d/*.conf` create those groups. A second apply adds them.
- Store packages cannot link into system unit, dbus or udev dirs (FR to formalspec). ananicy-cpp
  runs from a `service()` and asusd's dbus policy is a copied file instead of the upstream ones.
- `git()` builds on `fspec ci packages` (ubuntu-24.04) take no build dependencies. librepods
  (Qt 6 Bluetooth, libpulse), Messages and formalmusic (NativeDesktop: GTK, WebKit, Vulkan) and
  kopuzd need apt packages the runner lacks.
- `url()` stores a bare file as data, so the Beeper 4.3.73 and Epic Games Launcher AppImages
  cannot be store pkgs. The Beeper unit skips until `/opt/fspec/current/bin/beeper` exists; Heroic
  covers the Epic library.
- Colloid-Dark: not in Tumbleweed's repos, and no release ships the built theme tree a `share`
  pkg can link.
- Discord with Moonlight, Last.fm RPC and midnight: Tumbleweed's non-oss `discord` is 1.0.156
  (NixOS runs 1.0.164) and Discord's own tarball is brotli-compressed modules fspec cannot
  unpack. Discord runs from Flathub without Moonlight; the moonlight config files are ported.

### Waiting on p2p sync

- Helium profile and the Helium takeover guard (synced over syncthing on NixOS).
- App logins and tokens: each app signs in again on the new root.
- Flare is linked per device, not synced: Flathub plus the `fspec-flare` unit on both hosts. The
  e1504g's old `~/.local/share/flare` stays where it is.

### Open: no Tumbleweed package and no upstream binary

- quickshell (dcal runs on it), uxplay.

### Version differences from NixOS

- vscode-langservers-extracted 4.10.0 from npm; NixOS packages 1.126.04524, not published to npm.
- gopls, lua-language-server, tree-sitter, typescript and uv are Tumbleweed's versions, not
  nixpkgs'. taplo comes from Tumbleweed (aqua resolves `tamasfe/taplo` ambiguously against
  `tamasfe/taplo/full`, an fspec bug).
- python313-streamdeck 0.9.8 lacks the Stream Deck PID 0x00b3 that NixOS's git build
  (ac67de1f70) has.
- ananicy-cpp 1.2.0 is built without the BPF process backend.

### Dropped

- Android Studio, codex: not in the generations.
- dillo and terminal-browser: no longer wanted.
- `.cache/nix-index`, comma, fish `nix`/`rebuild`, `NH_FLAKE`, `nixpkgs/config.nix`,
  `hm-nix-direnv.sh`, `10-hm-fonts.conf`: Nix only. `cnf` replaces command-not-found and the
  `fish-completions` timer regenerates completions.
- formalmusic-maintenance: deploys through the nix flake.
- nix-daemon builder key and `/etc/nix/machines`: `host(builders = [builder("g815", ...)])`.
- tzupdate: the zone is fixed.
- DankMaterialShell, `dms.service`, `flexoki-pin.service`: replaced by FormalShell.
- `tray.target`, `.keep` placeholders: Home Manager and NixOS only.
- `.config/net.imput.helium/WidevineCdm`: Helium's component updater fetches it.
- matugen `aura` template: the ASUS Aura repaint is a NixOS module; `asus-aura` seeds the keyboard.

### Changed behaviour

- `.claude/CLAUDE.md`, `.claude/hooks`, `.pi/agent/*` were symlinks into `~/.config/nix`; they are
  copies now, so an edit there needs a re-apply here.
- Store tools live in `/opt/fspec/current/bin`, which `environment.d` and fish put on PATH;
  Hyprland binds, meshtop's entries and the scripts call them there.
- `dualsense-herdr` and `streamdeck-keys` keep `/etc/profiles/per-user/kyandesutter/bin/herdr`:
  the macbook's path, reached over ssh.
- Units are `fspec-<name>.service` and exec directly instead of `bash -lc`.
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

### Waiting on formalspec

- Kernel arguments: `tumbleweed(kernel_args = [...])` (FR). The cmdline needs
  `nvidia-drm.modeset=1 acpi_backlight=native cfg80211.ieee80211_regdom=ES mitigations=off`;
  the full `/etc/kernel/cmdline` cannot be a file because the root UUID is unknown before install.
- The root is ext4, so the install needs `fspec disk` to carve the Tumbleweed root before
  `fspec switch --beside`.

### Not ported

- The 16G swapfile tier: depends on the new disk layout.
- macos-vm: its OpenCore EFI is a nix build.
- godot-mono, dotnet, godot-mcp.
- NixOS's `checkReversePath = false`; firewalld keeps rp_filter at the kernel default.

### Version differences from NixOS

- NVIDIA G07 from NVIDIA's openSUSE repo is 595.x; NixOS runs 615.71.09 and nvidia-settings.

## macbook

See `macbook/GAPS.md`.
