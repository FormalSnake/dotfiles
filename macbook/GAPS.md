# Not ported from nix-darwin

Source: `darwinConfigurations.macbook` in ~/.config/nix at 98ca1b6c and the live machine (Home
Manager generation `pvy93i9lkhxfxz0byv8n80y0h2zmi7sz`). The spec is `../macbook.star`, loaded
from `spec.star`: `fspec plan --host macbook --local`, run from the spec.

## Not verified

- The pam_ssh_agent_auth, sbarlua, Messages and FormalMusic `git()` packages are built by CI and
  locked, but nothing has applied them on the macbook yet.

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

- `~/.claude/skills` is no longer in the spec: `meshtop skills sync` fills it from the agent-config
  registry, as on the e1504g. `~/.claude-pulse/skills` still links to it.
- `meshtop-web` (127.0.0.1:7314), its tailscale serve poll (8314) and the Messages bridge
  (`messages-agent`, bun from Homebrew) are now `fspec.*` services; nix ran the first two from
  `/nix/store` and the third from a hand-made plist with nix's bun.
- Messages and FormalMusic run unwrapped; nix put ffmpeg on their PATH, and their `Info.plist`
  now does through `LSEnvironment` (`/opt/homebrew/bin` first).
- Secrets decrypt to `/var/run/fspec/secrets/<name>` (was `/run/agenix`); fish, wgtunnel and the
  LiveSync daemon read them there, and `fspec-secrets` decrypts them again at boot.
- `livesync-passphrase` is macbook-only, so its `.age` file sits in `macbook/secrets/`.
- The launchd helper scripts (storage-gc, dev-vm-reaper, the Obsidian watchers) are copies in
  `~/.local/bin` instead of running from `~/.config/nix/scripts`.
- Jobs are `fspec.<name>` (were `kyan.<name>` and `org.nix-community.home.<name>`).
- `JAVA_HOME` is the zulu@21 cask's JDK; tools run from `/opt/fspec/current/bin` and Homebrew.
- The host's own name is `MacBook-Pro-2`, so `fspec plan --host macbook` without `--local`
  tries ssh to `macbook` and fails.

## Cutover

Found by comparing the plan with the live machine (2026-10-28). Not fixed in the spec:

- **fspec itself.** `service:secrets` runs `/usr/local/bin/fspec`, which does not exist; the binary
  is `~/.cargo/bin/fspec` and the engine never links itself on macOS. Install it first.
- **Homebrew is nix-homebrew's.** `/opt/homebrew/bin/brew` and `Library/Homebrew` are symlinks into
  `/nix/store`, `.managed_by_nix_darwin` is set, and only the jnsahaj and pluk-inc taps are real.
  Removing `/nix` leaves no `brew`, so every `brew:` package breaks. Re-home Homebrew before the
  uninstall (official installer over the existing prefix; untested here, try it with `HOMEBREW_PREFIX`
  backed up first). fspec cannot do this itself.
- **`t3code-cli-sync`** (`org.nix-community.home.t3code-cli-sync`) has no replacement. It needs
  `t3code-cli-sync.mjs` from `~/.config/nix/users/kyandesutter/mixins/dev/` and the nix-patched
  `t3` 0.1.3 (the spec ships upstream 0.1.2 with no import patch). Dropped until the patch lands.
- **`org.nixos.start_karabiner_daemons`, `setsuid_karabiner_session_monitor`** are nix-darwin's.
  The `karabiner-elements` cask ships its own; re-approve its driver and daemons in System Settings.
- **`sh.brew.couchdb`** (a `brew services` plist, not nix) listens on 5984 like `fspec.couchdb`.
  Boot it out in the same step as the nix jobs.
- **`~/.config/age/keys.txt`** and `~/.ssh` keys stay as they are; `fspec` decrypts with them.
- Leftover dead links with no owner in the spec, left to rot or `rm`: `~/Sync/zen-profile/{user.js,
  containers.json,chrome/*}`, `~/.vscode/extensions/*`, `~/.config/aerospace 19.21.48`,
  `~/Library/Application Support/go/env`, `~/.config/{nixpkgs,git_nix,nix-themes/current}`,
  `~/.local/state/mac-server-optimization-2026-10-27`, `.direnv/flake-profile-*` in ~/Developer.
- `/etc/zshenv`, `/etc/bashrc`, `/etc/zshrc`, `/etc/zprofile`, `/etc/static` are nix-darwin's; its
  uninstaller restores the `*.before-nix-darwin` copies. The login shell is set by `user()`
  (`/opt/homebrew/bin/fish`, already in `/etc/shells`; the nix fish entry stays harmless).
  `/etc/synthetic.conf` (`nix`, `run`) and the `/nix` line in `/etc/fstab` go with the installer.
- sshd keeps four dead links to `/etc/static` after the uninstall: `099-host-keys.conf`,
  `100-kyan.conf`, `100-nix-darwin.conf`, `101-authorized-keys.conf`. The host keys are real files
  and `100-fspec.conf` replaces the rest. Remove the links (step 7).

### Order

Each command is run by hand, in this order, with the check after it. Nothing here has been run.

1. Install the engine: `install -m755 ~/.cargo/bin/fspec /usr/local/bin/fspec`.
2. `cd ~/.config/nix-wt/formalspec && fspec plan --host macbook --local`, then
   `fspec apply --host macbook --local` (user scope; it hands the system scope to sudo).
3. Unload the nix jobs. User domain, `for l in kyan.dev-vm-reaper kyan.login.aldente
   kyan.login.betterdisplay kyan.login.nordvpn kyan.login.orbstack kyan.nix-weekly-update
   kyan.obsidian-livesync-daemon kyan.obsidian-livesync-serve kyan.obsidian-note-watcher
   kyan.obsidian-scan-watcher kyan.storage-gc org.nix-community.home.meshtop-web
   org.nix-community.home.meshtop-web-serve org.nix-community.home.t3code
   org.nix-community.home.t3code-cli-sync org.nix-community.home.t3code-serve
   es.canarycoders.messages.agent sh.brew.couchdb; do launchctl bootout gui/502/$l; done`.
4. System domain, `for l in kyan.caffeinate kyan.portless-proxy kyan.usbfluxd
   com.tailscale.tailscaled org.nixos.activate-agenix org.nixos.activate-system
   org.nixos.rosetta-builderd org.nixos.nix-optimise; do sudo launchctl bootout system/$l; done`.
   Leave `org.nixos.nix-daemon` and `systems.determinate.*` for the installer.
5. Check: `launchctl list | rg 'fspec\.'` shows every service in the plan, none `kyan.*` or
   `org.nix*` remain, `fspec plan --host macbook --local` reports no changes, `sudo -k; sudo true`
   authenticates through the agent, `ssh macbook true` from the g815, `curl -s 127.0.0.1:5984`,
   `meshtop --version` resolves under `/opt/fspec/current/bin`, a new fish shell starts with no
   `/nix` in `$PATH`.
6. Uninstall nix-darwin: `sudo nix run nix-darwin#darwin-uninstaller`. Then re-home Homebrew (see
   above) and check `brew --version` and `brew list` before going on.
7. `sudo rm /etc/ssh/sshd_config.d/{099-host-keys,100-kyan,100-nix-darwin,101-authorized-keys}.conf`
   and confirm `sudo sshd -t`.
8. `sudo /nix/nix-installer uninstall`, then reboot and repeat the step 5 checks.
