# Not ported from nix-darwin

Source: `darwinConfigurations.macbook` in ~/.config/nix at 98ca1b6c, brought up to 244dbeca, and the live machine (Home
Manager generation `pvy93i9lkhxfxz0byv8n80y0h2zmi7sz`). The spec is `../macbook.star`, loaded
from `spec.star`: `fspec plan --host macbook --local`, run from the spec.

## Not verified

- pam_ssh_agent_auth is applied and PAM loads it, but `kyandesutter ALL=(ALL) NOPASSWD: ALL` in
  `10-fspec` means sudo never asks it to authenticate, so the agent path is untested.
- `ssh windows`: the PC was offline in tailscale during the cutover.

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
  1.27.3 (1.26.8), zig 0.17.0 (0.16.0), node 24.22.1 (24.21.0),
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
- `nil` (no Homebrew formula, no release binaries for macOS).
- The `jnsahaj/lumen` tap: nothing installs lumen on the macbook.
- fastfetch's background-refreshed pkgs count: it works around `nix-store` stalls on a busy nix
  daemon.

## Changed behaviour

- T3 Code's device hub keys are owned by the spec, so turning it off in the UI lasts until the
  next apply; nix set them once and left them to the UI.
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

Run on 2026-10-28. Applied: everything in `macbook.star`. The nix jobs it replaces are booted out
and their plists are in `~/.local/state/nix-launchd-backup/{user,system}`; the Home Manager links
fspec replaced are listed in `removed-hm-links.map` there.

Found on the way:

- **First apply on a Mac needs `oras` and `openssl@3` from Homebrew before it starts.** The system
  scope runs before the user scope that installs formulae, so it cannot pull CI-built packages
  without `oras`, and `/etc/pam.d/sudo_local` loads `pam_ssh_agent_auth.so`, which links
  `/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib`. Without openssl, PAM fails to initialise and
  every `sudo` fails ("unable to initialize PAM"). Uninstalling `openssl@3` does the same; sudo then
  needs a root shell or Recovery to fix.
- Home Manager linked whole directories (`~/.config/tmux/plugins/*`) into the read-only store, so
  fspec writing a file under them fails. Those links, and every other link at a path the spec
  manages, were removed before the apply.
- Apps installed outside Homebrew block their cask: `/Applications/Kopuz.app` (0.6.0, manual) went
  to the Trash; Discord was taken over with `brew install --cask --adopt`.
- `usbfluxd` is a source build now: the release's macOS tarball carries only `usbfluxctl`.

### Not ported

- **`t3code-cli-sync`** (`org.nix-community.home.t3code-cli-sync`): needs `t3code-cli-sync.mjs` and
  the nix-patched `t3`; the spec runs upstream 0.1.3. Dropped until the patch lands upstream.
- `dev.formalsnake.nd-resume` in `~/Library/LaunchAgents` is a one-shot another session left; its
  PATH names nix profile dirs. Not the spec's.
- `~/Sync/zen-profile/*` links into the store and dangles once `/nix` is gone. Left alone: it is a
  Syncthing folder, and deleting there deletes on every peer.
- Dead links into the store with no owner, deleted by the cutover script below:
  `~/.vscode/extensions/*`, `~/.config/aerospace 19.21.48`, `~/.local/state/mac-server-optimization-2026-10-27/*`,
  the meshtop skill backups, `~/.local/share/devenv/gc/*`.

### The last step

`t3code`, `tailscaled` and `meshtop-web` replace jobs that host the running T3 Code session and its
tailscale route, and removing `/nix` takes the shell that session runs in. So the swap and the
uninstall run as one launchd job, `~/.local/state/fspec-cutover/cutover.sh`:

```
sudo launchctl submit -l fspec.cutover -- /bin/bash /Users/kyandesutter/.local/state/fspec-cutover/cutover.sh
```

It boots out the nix t3code, t3code-cli-sync, meshtop-web and tailscaled jobs, applies the spec,
waits for 3773 and `tailscale status`, removes nix-darwin's `/etc/static` links and restores the
`*.before-nix-darwin` files, runs `/nix/nix-installer uninstall --no-confirm`, removes the per-user
nix state and dead links, and logs checks to `~/Library/Logs/fspec-cutover.log`.
Homebrew was re-homed before it: `/opt/homebrew` is a git checkout of Homebrew/brew (stable,
7.0.11) running its own portable Ruby; nix-homebrew's two links are in
`~/.local/state/nix-launchd-backup/homebrew/links.txt`.

- CouchDB lost its LiveSync settings and admin when Homebrew upgraded it to 3.5.3 (Oct 13): the
  formula keeps `local.ini` in the keg. `couchdb-start.sh` now keeps it at
  `/opt/homebrew/var/couchdb/local.ini`; the server uuid is new, so LiveSync clients re-check once.
- `fish_user_paths` (a universal variable) held `/run/current-system/sw/bin` and
  `/etc/profiles/per-user/kyandesutter/bin`; both are gone from it.
