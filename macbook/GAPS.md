# Not ported from nix-darwin

Source: `darwinConfigurations.macbook` in ~/.config/nix at 98ca1b6c and the live machine (Home
Manager generation `pvy93i9lkhxfxz0byv8n80y0h2zmi7sz`). The spec is `../macbook.star`, loaded
from `spec.star`: `fspec --spec examples/kyan/spec.star plan --host macbook --local`.

## Not verified

- The pam_ssh_agent_auth, sbarlua, Messages and FormalMusic `git()` recipes have not been
  built: they run on the macos-26 CI runner. pam_ssh_agent_auth follows nixpkgs' recipe (its four patches in
  `patches/`, ed25519-donna at `8757bd4`, autoreconf, OpenSSL 3 from Homebrew) plus the
  `-std=gnu99 -D_FORTIFY_SOURCE=0` the nix override adds for OpenPAM.

## Not in sync.star yet

Secret-carrying state `fspec sync` can carry, still to be declared with the macbook as a peer
(`../sync.star` holds the Linux pair's items):

- The Helium profile.
- Claude Code sign-ins: `~/.claude.json` (oauthAccount) and the `~/.claude-pulse` login.
- `gh` auth (`~/.config/gh/hosts.yml`), NordVPN, Tailscale node state. 1Password stays per device.
- App sessions: Discord, BlueBubbles, Parsec, Jump Desktop, Syncthing's device keys.
- `~/.config/age/keys.txt`, the identity the secrets decrypt with, and `~/.ssh` keys.

## Version differences from nix

- Homebrew ships its current versions: herdr 0.9.5 (nix 0.9.3), opencode 2.1.2 (1.18.35), go
  1.27.3 (1.26.8), zig 0.17.0 (0.16.0), node 24.22.1 (24.21.0), Discord 0.0.418 (0.0.414),
  T3 Code app 0.1.1 (0.1.0), gopls 0.24.0, typescript stays 5.9.3 from npm.
- Claude Code is `self_managed` at 2.1.310 and updates itself.
- nvim plugins are the same revisions nix pinned, through `vim.pack` and
  `.config/nvim/nvim-pack-lock.json`; nvim-treesitter compiles every parser on first start
  instead of shipping `withAllGrammars`.

## Dropped

- nix-rosetta-builder (x86_64-linux in a Rosetta VM, port 31122) and Determinate's aarch64-linux
  builder. fspec's `builder()` builds only for its own platform, so the macbook cannot build for
  the e1504g (the g815 does), and no other host builds for aarch64-darwin: its `git()` packages
  come from CI or build here. The e1504g's `restrict,permitopen` key is gone from
  `authorized_keys.d` with it.

- Determinate Nix, nix-homebrew, mac-app-util, the Home Manager glue, `nixpkgs.config`, the
  `nix-weekly-update` agent, nix-index and comma, nh, `NH_FLAKE`, `NIXPKGS_ALLOW_UNFREE`, the
  fish `nix` and `rebuild` functions, `direnvrc` (nix-direnv and its Apple toolchain scrub),
  `TERMINFO_DIRS` into the nix profile: nix only.
- nix-darwin's `AuthorizedKeysCommand /bin/cat` and the root-owned copy of the sudo key list:
  workarounds for sshd and PAM refusing `/nix/store` symlinks. fspec writes real files, so sshd
  reads `/etc/ssh/authorized_keys.d/%u` through `AuthorizedKeysFile`.
- The ghostty terminfo `tic` step: the compiled entry is `~/.terminfo/78/xterm-ghostty`.
- Moonlight in Discord: the cask runs without it, and its stable.json render with it.
- `nil` (no Homebrew formula, no release binaries for macOS).
- The `jnsahaj/lumen` tap: nothing installs lumen on the macbook.
- Hammerspoon's config is ported, the app is not installed (nix never installed it either).

## Changed behaviour

- Messages and FormalMusic run unwrapped; nix put ffmpeg on their PATH, and their `Info.plist`
  now does through `LSEnvironment` (`/opt/homebrew/bin` first).
- Secrets decrypt to `/var/run/fspec/secrets/<name>` (was `/run/agenix`); fish, wgtunnel and the
  LiveSync daemon read them there, and `fspec-secrets` decrypts them again at boot.
- `livesync-passphrase` is macbook-only, so its `.age` file sits in `macbook/secrets/`; it still
  needs an entry in `secrets.star` for `fspec secret edit` and `rekey`.
- The launchd helper scripts (storage-gc, dev-vm-reaper, the Obsidian watchers) are copies in
  `~/.local/bin` instead of running from `~/.config/nix/scripts`.
- Jobs are `fspec.<name>` (were `kyan.<name>` and `org.nix-community.home.<name>`).
- `JAVA_HOME` is the zulu@21 cask's JDK; tools run from `/opt/fspec/current/bin` and Homebrew.
- The host's own name is `MacBook-Pro-2`, so `fspec plan --host macbook` without `--local`
  tries ssh to `macbook` and fails.
