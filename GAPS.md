# Not ported from NixOS

Source: the NixOS and Home Manager generations on the e1504g and the g815. The Tumbleweed root is
`spec.star`, `system.star` (shared Linux root, `e1504g/rootfs/`), `home.star` (shared home,
`home/`, overlaid by `<host>/home/`) and `g815.star` (`g815/rootfs/`). `image.star` is the
earlier Fedora Atomic image and nothing loads it.

## Both Linux hosts

### Waiting on formalspec

- users-before-packages: Users run before Packages, so on a first apply
  `usermod -aG docker,uinput,nordvpn,ancs4linux` runs before the rpms and `/etc/sysusers.d/*.conf`
  create those groups. A second apply adds them.
- sync (draft in `sync.star`, nothing loads it): the Helium profile and its Safe Storage key, the
  app logins and tokens (each app signs in again on the new root until then). Flare, Beeper and
  1Password are linked per device and never synced: Flathub plus the `fspec-flare` unit for Flare,
  and the e1504g's old `~/.local/share/flare` stays where it is.

### Needs Kyan

- quickshell, which dcal's UI runs on: no Tumbleweed package and no release binary, so it would be
  a Qt 6 source build (`git()` on the Tumbleweed image, its QML modules found outside the store
  prefix). dcal's daemon runs without it. Build it, or keep dcal UI-less.

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

### Needs Kyan

- The root is ext4, so the install needs `fspec disk` to carve the Tumbleweed root before
  `fspec switch --beside`.
- The 16G swapfile tier: it goes on the disk layout `fspec disk` makes.
- macos-vm (macOS 10.9 guest): its OpenCore EFI is a nix build. Port it as a `git()` OpenCore
  build, or drop it.

### Version differences from NixOS

- NVIDIA G07 from NVIDIA's openSUSE repo is 595.x; NixOS runs 615.71.09 and nvidia-settings.
- godot-mcp is the npm release 0.1.1; nixpkgs builds the 2026-01-30 git snapshot.

### Dropped

- `checkReversePath = false`: no longer in the nix config. Tumbleweed's IPv4 rp_filter is loose.

## macbook

See `macbook/GAPS.md`.
