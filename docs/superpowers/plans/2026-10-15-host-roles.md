# Host roles: macbook as the dev server, g815 and e1504g as clients and Linux test targets, SSD and superserver for personal data

**Goal:** the macbook is the development server: its internal disk belongs to dev work (Apple, Android, web, everything). The g815 Linux side and the e1504g are clients for that work plus general computing; the g815 (Linux and its Windows partition) is also where Linux and Windows builds get compiled and tested. The external SSD (`/Volumes/Kyan Drive`) and the superserver hold personal, local data. Nothing personal grows on the mac's internal disk, and nothing on it is kept beyond what one command regenerates.

**State on 2026-10-15:** the internal disk is 914 GB of 927 GB used. Personal data on it is small (Pictures 1.8 GB, Photos library 1.9 GB, Documents 190 MB, Sync 686 MB). The disk is full of dev output, and the SSD is currently used as dev overflow, the inverse of its intended role.

| Where | What | Size |
| --- | --- | --- |
| `~/Developer/kopuz-wt` | five cargo `target` copies (clean-a..d, rv-stack) | 169 GB |
| `~/Developer/ecosystem/FormalShell` | worktrees and their output | 68 GB |
| `~/Developer/befit2sail` | apps/ output, `.claude` 8.5 GB, node_modules | 28 GB |
| `~/Developer/FormalShell-m59`, `-m55` | 119 worktrees under `dev/` | 36 GB |
| `~/Developer/CanaryPulseDemo*` | three checkouts | 19 GB |
| `~/.android` + `~/Library/Android` | Android SDK, emulator images | 27 GB |
| `~/Library/Developer/Xcode/iOS DeviceSupport` | old device symbol sets | 13 GB |
| `~/Library/Group Containers/*.orbstack` | OrbStack VM disk | 13 GB |
| `~/Library/Application Support/Spotify` | cache | 8.7 GB |
| `/nix` | store | 71 GB |
| SSD `dev-cache.noindex` | cargo targets, cef, sccache, zed (nativedesktop worktrees' `.cargo/config.toml`) | 143 GB |
| SSD `CoreSimulator` | simulator devices | 72 GB |
| SSD `Movies` | personal | 19 GB |

The superserver (`superserver.local`, Ubuntu 24.04, Docker) already holds the personal services: Immich on `/mnt/photos` (1.8 TB), `/mnt/shared` over SMB, Time Machine `MyBackups`, a Minecraft server with its Discord bot, CouchDB instances on `/mnt/couchdb`.

## Phase 1: config (done, commit `host roles`)

- Mac homebrew drops `docker-desktop` (OrbStack holds the containers), `balenaetcher`, `firefox`, `codex`. `cleanup = "uninstall"` removes them at the next switch; Docker Desktop's own data under `~/Library/Containers/com.docker.docker` stays until a `zap`.
- `mixins/android.nix` is cross-platform behind `kyan.android.enable`, on for the macbook only: the SDK env and `JAVA_HOME`; on Linux it would also install the nixpkgs Android Studio, should a laptop ever need it.
- `modules/nixos/mixins/docker.nix` (`kyan.docker.enable`), on for the g815 as a Linux test target.
- `office-dc-bot` mixin, option and secret deleted: the superserver runs that bot as a container.
- `kyan-drive.nix` states the SSD's role.
- `scripts/storage-gc.sh` (daily on every host) now also sweeps: any dir carrying a `CACHEDIR.TAG` (the renamed and relocated cargo targets, 130 GB in `kopuz-wt`), the SSD's `dev-cache.noindex`, idle `dev/.linux-builder` and `dev/.testvm` VM disks (80 GB under FormalShell checkouts), clean agent worktrees untouched for 14 days (`--prune-worktrees`, on in both units), unavailable simulators, and Spotify's stream cache.

## Phase 2: free the internal disk (needs the owner's go, it deletes)

1. `scripts/storage-gc.sh --apply --deep --prune-worktrees` (the extended sweep: cargo targets, VM disks, finished worktrees, old iOS DeviceSupport, nix generations).
2. Whatever the sweep's "not touched" list still shows is a by-hand decision: the 32 FormalShell worktrees checked out directly under `~/Developer`, simulator devices, Claude's `vm_bundles`.

## Phase 3: put the SSD back to personal use

Once the internal disk has room (target: 300 GB free):

1. Move `CoreSimulator` back to `~/Library/Developer/CoreSimulator` and drop the link in `kyan-drive.nix`; point `IDECustomDerivedDataLocation` back at the default.
2. Delete `dev-cache.noindex` on the SSD and remove the `target-dir` lines from the nativedesktop worktrees' `.cargo/config.toml`.
3. Personal data onto the SSD: `~/Pictures/screenshots`, `we-engine-archive`, `appstore-screenshots-demo`, Photo Booth; keep the Photos library and `Wallpapers` (Syncthing folder) where they are.

## Phase 4: personal services off the mac (separate task)

- Obsidian LiveSync: CouchDB brew formula plus four launchd agents and `tailscale serve` on 443. The superserver already runs CouchDB containers; moving it means a new container, replicating the database, and re-pointing the plugin on the g815, iPhone and iPad.
- BlueBubbles stays: it needs a signed-in Mac for iMessage.
- Syncthing hub stays for now (87 MB of state); the laptops' mixin pins the mac as hub.

## Tool usage (shell history 2024-01-04 to 2026-10-15, fish and zsh, interactive commands only)

Never typed, not referenced by any script in this repo, and not referenced by any project manifest under `~/Developer` (depth 3): assimp, raylib, libcaca, libpq (as psql), poppler, tree-sitter, ninja, pyenv, git-filter-repo, rclone, cloudflared, swiftformat, swiftlint, xcodegen, cliamp, spice-edit. Candidates to drop from `programs.nix`.

Typed once or twice, over a year ago: xcbeautify (912 days), cmake, imagemagick, lua, stow (492), chafa (477), uv (443), lazydocker (399), zulu21 as `java` (362; gradle runs it, so it stays with Android), dipc (327).

Used in the last 90 days: bun, node, just, rg, lsd, fastfetch, herdr, meshtop, btop, t3code, tmux, zig, fut, opencode, cocoapods, stripe-cli, fastlane, fast, xxd, python3, mosh.

Limits of the check: history records only what was typed at a prompt. A tool an agent, a hook, a Justfile or a project script calls does not show up, so each candidate above was also grepped for in this repo and in the project manifests; both came back empty. Cask last-opened dates are not available (Spotlight returns nothing for `/Applications`).
