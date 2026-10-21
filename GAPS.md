# Not ported from NixOS

Source: generation `r2p4l9m6zqgq9a3f61yiv0y2bjaxdafp-home-manager-generation` and the system
generation on the e1504g. The Tumbleweed root is `spec.star`, `system.star` and `home.star`;
`image.star` is the earlier Fedora Atomic image and nothing loads it.

## Open: fspec has no way to express it yet

- Users run before Packages, so on a first apply `usermod -aG docker,uinput,nordvpn` runs before
  the docker and nordvpn rpms and `/etc/sysusers.d/uinput.conf` create those groups. A second
  apply adds them.
- `git()` builds on `fspec ci packages` (ubuntu-24.04) take no build dependencies. librepods
  (Qt 6 Bluetooth, libpulse), Messages and formalmusic (NativeDesktop: GTK, WebKit, Vulkan) and
  kopuzd need apt packages the runner lacks; boxxy needs GTK 4.22, newer than Ubuntu 24.04 has.
- Prebuilt archives only link executables in their top two levels. FormalShell's release tarball
  keeps them in `formalshell/bin/` and terminal-browser in its own tree, so neither links.
- `url()` stores a bare file as data, so the Beeper 4.3.73 AppImage cannot be a store pkg. The
  unit skips until `/opt/fspec/current/bin/beeper` exists.
- Data-only pkgs (no executables) are refused: Bibata cursor, Geist Mono Nerd Font, Colloid-Dark,
  adw-gtk3. None is in Tumbleweed's repos.
- Discord with Moonlight, Last.fm RPC and midnight: Tumbleweed's non-oss `discord` is 1.0.156
  (NixOS runs 1.0.164) and Discord's own tarball is brotli-compressed modules fspec cannot
  unpack. Discord runs from Flathub without Moonlight; the moonlight config files are ported.

## Open: no Tumbleweed package and no upstream binary

- quickshell (dcal runs on it), dillo, uxplay: not in Tumbleweed, no release binaries.

## Version differences from NixOS

- FormalShell: v0.2.0 release; NixOS runs e8a800d, which has no release.
- vscode-langservers-extracted 4.10.0 from npm; NixOS packages 1.126.04524, not published to npm.
- gopls 0.23.0 is a source build; Tumbleweed has 0.24.0. taplo 0.10.0 comes from Tumbleweed
  (aqua resolves `tamasfe/taplo` ambiguously against `tamasfe/taplo/full`, an fspec bug).
- python313-streamdeck 0.9.8 lacks the Stream Deck PID 0x00b3 that NixOS's git build
  (ac67de1f70) has.

## Dropped

- Android Studio, codex, the formalmusic maintenance timer: not in the e1504g's generations.
- `.cache/nix-index`, comma, fish `nix`/`rebuild`, `NH_FLAKE`, `nixpkgs/config.nix`,
  `hm-nix-direnv.sh`, `10-hm-fonts.conf`: Nix only. `cnf` replaces command-not-found and the
  `fish-completions` timer regenerates completions.
- DankMaterialShell, `dms.service`, `flexoki-pin.service`: replaced by FormalShell.
- `discord-kde`, `kwin-outputs`, `steamed-theme`: KDE session only.
- `tray.target`, `Desktop/switch-to-hyprland.desktop`, `.keep` placeholders: Home Manager and
  NixOS only.
- `.config/net.imput.helium/WidevineCdm`: Helium's component updater fetches it.
- matugen `aura` template: the ASUS Aura repaint is a NixOS module.

## Changed behaviour

- `.claude/CLAUDE.md`, `.claude/hooks`, `.pi/agent/*` were symlinks into `~/.config/nix`; they are
  copies now, so an edit there needs a re-apply here.
- Store tools live in `/opt/fspec/current/bin`, which `environment.d` and fish put on PATH;
  Hyprland binds, meshtop's `e1504g` entry and the scripts call them there.
- `dualsense-herdr` and `streamdeck-keys` keep `/etc/profiles/per-user/kyandesutter/bin/herdr`:
  the macbook's path, reached over ssh.
- Units are `fspec-<name>.service` and exec directly instead of `bash -lc`.
- dconf loads through `fspec-dconf-load` and `.Xresources` through `fspec-xrdb-merge` at login.
- nvim-treesitter parsers compile once through `fspec-nvim-treesitter-parsers` instead of coming
  from Nix.
- `/home` is shared with the NixOS root, which has no Home Manager, so the home belongs to this
  layer.
