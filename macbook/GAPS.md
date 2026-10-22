# Not ported from nix-darwin

Source: `darwinConfigurations.macbook` in ~/.config/nix at 98ca1b6c and the live machine (Home
Manager generation `pvy93i9lkhxfxz0byv8n80y0h2zmi7sz`). The spec is `../macbook.star`; it plans
standalone with `fspec --spec macbook.star plan --host macbook --local`.

## Open: fspec has no way to express it yet

Each one is a request sent to the formalspec agent.

- launchd keys beyond `RunAtLoad`/`KeepAlive`/env (request 1). `StartInterval` jobs became
  calendar timers (`*/5`, `*/10`, `*/15`), logs go through a `/bin/sh -c` redirect, and these are
  missing outright: `WatchPaths` on `~/Notes/_inbox/scans` (the scan watcher now only polls every
  ten minutes), `ThrottleInterval`, `ProcessType = Interactive` for sketchybar, and an idle
  `usbfluxd` daemon that `usbflux on` kickstarts. usbfluxd always starting at load would take
  over usbmuxd, so the daemon and the `usbflux` wrapper are not declared; the binary is.
- Symlinks to directories and to targets outside the repo (request 2): `~/Movies`, `~/.gradle`
  and `~/Library/Developer/CoreSimulator` into `/Volumes/Kyan Drive`, and
  `~/.claude-pulse/plugins` into `~/.claude/plugins`. Directories from the repo (sketchybar,
  hammerspoon, the pi extensions, Claude's agents, commands and hooks) are linked file by file
  instead, so a new file there needs a re-apply.
- Homebrew taps and tap trust (request 3): omniwm, tinycast, markdown-preview and sketchybar
  are written as `brew("<tap>/<name>")`. `fspec update` resolves through formulae.brew.sh, which
  has no tapped names, and nothing runs `brew tap` or trusts the tap first.
- System settings outside user defaults (request 4): `pmset` sleep never and `womp 1`,
  `systemsetup -setRestartFreeze on` and `-setremotelogin on`, the application firewall off (it
  drops mosh's UDP), and root-domain defaults: `com.apple.SoftwareUpdate
  AutomaticallyInstallMacOSUpdates = false`, `com.apple.RemoteManagement RestoreMachineState =
  false`. These already hold on the machine and survive without nix; a fresh Mac would miss them.
- `.app` bundles from store packages (request 5): Messages and FormalMusic (FormalStudio source
  builds), Kopuz (dmg only, no cask). Nothing places an app in `/Applications`, and fspec unpacks
  no dmg. The kopuzd daemon and kopuzctl are declared; the player app is not.
- No stable path into a store package on macOS (request 7, `share` is Linux only):
  pam_ssh_agent_auth's `.so`, which `/etc/pam.d/sudo_local` names, and SbarLua's
  `sketchybar.so`, which sketchybar's `LUA_CPATH` names. sbarlua is declared (its build is the
  makefile's own `install` target); the sketchybar service has no `LUA_CPATH` until the path
  exists. pam_ssh_agent_auth 0.10.4 (`7ff7858`, built against OpenPAM with `-std=gnu99
  -D_FORTIFY_SOURCE=0`) and `sudo_local` are not declared. The sudoers NOPASSWD line covers
  kyandesutter meanwhile; the module only gated other accounts arriving over ssh.
- One lock entry per package name (request 8). The macbook takes lazydocker, uv, herdr, gopls,
  nixfmt, rust-analyzer, marksman, lua-language-server, the brew language servers, discord and
  parsec from Homebrew where the e1504g uses aqua, github, npm or Flathub, so `plan` reports the
  lock as out of date and an `fspec update` from either host rewrites the other's entries.
  `fspec update` for this spec has not run: it writes the shared `examples/kyan/fspec.lock`.
- Remote builders: formalspec's builder config has not landed. The macbook ran
  nix-rosetta-builder (x86_64-linux in a Rosetta VM on port 31122, socket-activated, 6 cores,
  8 GiB) as the e1504g's fallback builder, and Determinate's native aarch64-linux builder. The
  e1504g's `restrict,port-forwarding,permitopen` key stays in `authorized_keys.d` for when it does.

## Waiting on p2p sync

Secret-carrying state, declared once formalspec's encrypted sync lands:

- The Helium profile.
- Claude Code sign-ins: `~/.claude.json` (oauthAccount) and the `~/.claude-pulse` login.
- `gh` auth (`~/.config/gh/hosts.yml`), 1Password, NordVPN, Tailscale node state.
- App sessions: Discord, BlueBubbles, Parsec, Jump Desktop, Syncthing's device keys.
- `~/.config/age/keys.txt`, the identity the secrets decrypt with, and `~/.ssh` keys.

## Version differences from nix

- Homebrew ships its current versions: herdr 0.9.5 (nix 0.9.3), opencode 2.1.2 (1.18.35), go
  1.27.3 (1.26.8), zig 0.17.0 (0.16.0), node 24.22.1 (24.21.0), Discord 0.0.418 (0.0.414),
  T3 Code app 0.1.1 (0.1.0), gopls 0.24.0, typescript stays 5.9.3 from npm.
- Claude Code is `self_managed` at 2.1.289 and updates itself.
- nvim plugins are the same revisions nix pinned, through `vim.pack` and
  `.config/nvim/nvim-pack-lock.json`; nvim-treesitter compiles every parser on first start
  instead of shipping `withAllGrammars`.

## Dropped

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
