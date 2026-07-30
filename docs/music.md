# Self-hosted music (macbook)

A Spotify replacement: Navidrome serves the library, Lidarr + slskd + Soularr
fill it, ListenBrainz supplies discovery playlists. Runs entirely on the
macbook; reachable from the phone over Tailscale only.

Nix: `modules/darwin/mixins/music.nix` (`kyan.music.enable`) and
`users/kyandesutter/mixins/beets.nix`.

## Why everything is in Docker

`pkgs.navidrome` is `broken = stdenv.hostPlatform.isDarwin` in nixpkgs, and
`pkgs.slskd` has no darwin platform at all. Both are Linux-first, so the whole
stack runs as containers under OrbStack rather than half launchd, half Docker.

The one exception: `navidromePlugins.*` are plain `.ndp` data files that build
fine on darwin, so plugin *versions* stay pinned by the flake even though the
server does not. The launcher copies them out of the store into a writable
directory on every start, because Navidrome unpacks each `.ndp` next to itself.

## Services

| Service | Port | Role |
| --- | --- | --- |
| Navidrome | 4533 | Server, Subsonic API, discovery playlists |
| Lidarr | 8686 | Wanted-list and importer. Never searches or downloads |
| slskd | 5030 | Soulseek client |
| Soularr | 8265 | Bridges Lidarr to slskd |

One launchd agent (`kyan.music-stack`) runs `docker compose up` in the
foreground under `KeepAlive`, so launchd restarts the stack if it dies. It
refuses to start when `/Volumes/Music` is absent — without the SD card
Navidrome would scan an empty folder and mark the whole library deleted.

## Paths

```
/Volumes/Music/library      final library, Navidrome scans this (/music in containers)
/Volumes/Music/downloads    slskd output, shared back to Soulseek (/downloads)
/Volumes/Music/incomplete   slskd partials
/Volumes/Music/purchases    drop bought albums here, then run `music-import`
~/.local/share/music-stack  per-service config + databases
```

`library` and `downloads` mount at the *same container path* in every service.
Soularr hands Lidarr the path slskd reported, so a mismatch shows up as a
confusing "file not found" on import rather than an obvious path bug.

## How a download happens

1. You add an artist or album in Lidarr and monitor it.
2. Soularr polls Lidarr's wanted list every 300s, searches slskd.
3. slskd downloads into `downloads/`.
4. Soularr tells Lidarr to import; Lidarr renames into
   `library/Artist/Album (Year)/`.
5. Navidrome's watcher picks it up within ~10s.

Lidarr's own indexer and download-client machinery is unused, which is why its
health page permanently shows three warnings about missing indexers and
download clients. **Those are expected and will never clear.**

## API keys

Generated once by the launcher into `~/.local/share/music-stack/.api-keys` and
substituted into the Lidarr, slskd and Soularr seed configs. Both Lidarr and
slskd accept a pre-seeded key, which is what lets Soularr be wired up without
copying keys out of two web UIs by hand.

Seeds are written once and never rewritten (same contract as DMS
`settings.json`), because the web UIs write their own state back into them.

## Settings that do not live in nix

Lidarr and Navidrome keep these in their application databases, so a stack
rebuilt from scratch silently reverts to defaults. `kyan.music-stack-reconcile`
reapplies them every 600s:

- **Lidarr `renameTracks`** — off by default, and while off the configured
  folder format is ignored entirely, dumping every album loose into the artist
  directory.
- **Metadata profile `Singles and Albums`** — the stock "Standard" profile
  disallows primary types Single and EP, so a singles-led artist shows almost
  nothing. Created by name (ids are not stable) and pinned to the artists in
  `kyan.music.singlesArtists`. Pinning is followed by a `RefreshArtist`;
  without it Lidarr never re-reads the newly allowed releases.
- **Per-client transcoding** — `kyan.music.playerProfiles`. Applied
  unconditionally, so nix is authoritative: a profile changed by hand in the
  web UI reverts within ten minutes.

`transcoding_id` must be an empty string, never NULL. Navidrome scans it into
a Go string and a NULL makes every lookup for that client fail with
`converting NULL to string is unsupported`.

The reconcile also prunes duplicate player rows: Kopuz registers a new one on
every reconnect instead of reusing one, reaching 423 rows in a single morning.

## Transcoding

Library is FLAC; clients get what suits them.

- **Phone (NaviBeat)** — raw FLAC. See below; transcoding made it buffer.
- **Desktop (Kopuz)** — raw FLAC. Same machine as the server, wired speakers,
  so bit-perfect costs nothing.
- **Web UI** — Opus 128.

Measured on a 24-bit source: 98 MB FLAC at 1.69 Mbps versus 8 MB Opus at
128 kbps, with a whole-track transcode costing 3.5s of CPU. Navidrome streams
progressively, so audio starts well before that completes.

**Why the phone is not transcoded.** NaviBeat prefetches by opening several
streams in the same second, each spawning its own ffmpeg. They contend until
the track actually playing starves, which surfaces as endless buffering and
`Error sending transcoded file ... broken pipe` — the client hanging up, not a
server failure. Serving the original is a static file read, so range requests
work and seeking behaves. At 1.7 Mbps this is comfortable on 5G, and AirPods
re-encode to AAC over Bluetooth anyway, so transcoding was only ever saving
cellular data, never adding quality.

If data use becomes the problem, prefer 16-bit rips over reintroducing
transcoding: they are roughly a third the size for identical audible quality on
this hardware.

## Discovery

`navidromePlugins.listenbrainz-daily-playlist` imports Weekly Jams, Daily Jams
and Weekly Exploration. Requirements, all easy to miss:

- Enable **and configure** the plugin in the web UI (profile icon → Plugins).
  Discovering the `.ndp` only registers it; an unconfigured plugin is silently
  inert.
- A ListenBrainz account, mapped to the Navidrome username, following
  `troi-bot`.
- Real listening history. Connecting Spotify imports only the last 30 days and
  tracks forward; connecting Last.fm does nothing retroactively — the backfill
  is a separate manual job at `listenbrainz.org/settings/import/`.
- Playlists generate on troi-bot's schedule (daily-jams after local midnight,
  weekly-jams Mondays), not on demand.

The plugin matches tracks by MusicBrainz ID, falling back to artist/title for
`fallbackCount` tracks (default 15). Files without MBIDs are effectively
invisible to discovery, which is what beets is for.

## Tagging

Soulseek rip quality varies a lot: the Tame Impala albums arrived with full
MusicBrainz IDs, ISRC and barcode, while a Niko B single had no MBID at all.

beets owns `purchases/` — there its configured `move: true` is correct, filing
albums into the library. Do **not** run a plain `beet import` over the
Lidarr-managed library: it would move files out of Lidarr's layout and leave
Lidarr's database pointing at paths that no longer exist. To retag in place
use `beet import -C` (no copy, no move).

## Replacing cover art

`scripts/music-safe-covers.sh <artist>` rewrites an artist's covers as the
album title over a wash of its own artwork averaged down to a 4x4 grid and
blurred. Written for Artemas, whose covers are not something to have on screen
in public.

It writes `cover.jpg` and leaves `folder.jpg` alone. `cover.*` outranks
`folder.*` in Navidrome's `CoverArtPriority` and the Kodi consumer only ever
writes `folder.jpg`, so a Lidarr refresh cannot undo it and reverting is
`rm` on the `cover.jpg` files. Navidrome's watcher picks the new file up in
about ten seconds; no rescan needed.

Ink colour follows the wash brightness, so the same script works on a
near-black cover and a washed-out one.

`--embed` additionally rewrites the picture block in every FLAC. Album art and
track art are separate in Navidrome: a track with its own embedded picture
serves that, so without `--embed` the grid is clean but the now-playing screen
still shows the original. It is also what clients reading tags off downloaded
files use. Re-running is safe either way, since neither `cover.jpg` nor the
embedded art is ever used as the source to blur.

## Soulseek

Credentials are the one thing nix cannot generate — set `soulseek.username` and
`password` in `~/.local/share/music-stack/slskd/slskd.yml`.

`downloads/` is shared back to the network. Soulseek is ratio-driven and peers
deprioritise or reject accounts sharing nothing, so a new account sees a high
rejection rate until files accumulate. slskd only rescans shares at startup or
on demand (`PUT /api/v0/shares`).

## Gotchas

- **Soularr crashes rather than skipping when an album vanishes mid-flight.**
  Changing a metadata profile or deleting an artist while downloads are queued
  invalidates album ids; Soularr's cleanup path asks Lidarr for one, gets a
  404, and exits — then crash-loops on restart. Fix: `docker restart soularr`.
- **`search_timeout` is milliseconds**, passed straight to slskd. Anything under
  a second returns `TimedOut` with zero responses.
- **`album_prepend_artist` defaults to false**, so Soularr searches the bare
  album title. Searching Soulseek for "Currents" matches nothing useful.
- **Lidarr's `monitor: "none"` add-option unmonitors the artist**, not just the
  albums. An album stays `monitored: true` yet never appears as wanted.
- Lidarr sanitises `?` out of folder names (`Why's this dealer!`). Tags are
  unaffected, so clients display the real title.
- A newly added artist needs a `RefreshArtist` before missing state is computed.

## Checks

```bash
docker compose -p music-stack ps
tail -f ~/Library/Logs/music-stack.log
docker logs -f soularr

KEY=$(rg -o 'LIDARR_KEY=(\w+)' -r '$1' ~/.local/share/music-stack/.api-keys)
curl -s -H "X-Api-Key: $KEY" localhost:8686/api/v1/wanted/missing | jq .totalRecords

KEY=$(rg -o 'SLSKD_KEY=(\w+)' -r '$1' ~/.local/share/music-stack/.api-keys)
curl -s -H "X-API-Key: $KEY" localhost:5030/api/v0/transfers/downloads \
  | jq -r '[.[].directories[]?.files[]?|.state]|group_by(.)|map("\(length)x \(.[0])")|.[]'
```
