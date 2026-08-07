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
| multi-scrobbler | 9078 | Merges Spotify and Navidrome plays into one ListenBrainz history |

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
~/.local/share/music-stack/navidrome-backup  Navidrome DB backups, every 6h, 14 kept
docker volume music-stack_navidrome-data     Navidrome's own data dir (/data)
```

`library` and `downloads` mount at the *same container path* in every service.
Soularr hands Lidarr the path slskd reported, so a mismatch shows up as a
confusing "file not found" on import rather than an obvious path bug.

### Never open navidrome.db from macOS

Navidrome's `/data` is a docker volume rather than a bind mount, and that is
load-bearing. SQLite in WAL mode coordinates through POSIX locks and a shared
`-shm` mapping; across OrbStack's virtiofs boundary the locks are emulated and
the mapping is not really shared, so two processes each believe they own the
write-ahead log and the next checkpoint writes over pages the other side is
using. The database was destroyed twice this way on 2026-08-02 and 2026-08-03,
the second time by a single `sqlite3 navidrome.db "select ..."` run from the
mac while the container had the file open: 377 of 3072 pages ended up zeroed,
page 1 among them, which is past what `.recover` can read.

Inside the VM's own filesystem the locking works, so the reconcile agent's
ten-minute `docker exec` writes are safe. To query the database by hand:

```bash
docker exec navidrome sqlite3 /data/navidrome.db "select count(*) from media_file"
```

Backups stay on a bind mount on purpose: SQLite's online backup is one
sequential file write, which that mount handles, and a host-side copy survives
losing the volume. Restore is `docker cp` of a backup into a stopped container.

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

## Scrobbling

Navidrome and Spotify each scrobbled to a different place, which left the
discovery playlists reading half a history. Both now go through
multi-scrobbler:

- **Spotify** has no way to push plays out, so multi-scrobbler polls the account
  every 60s. That covers every device on the account, including Spotify on the
  g815, with nothing installed there.
- **Navidrome** posts to multi-scrobbler's `endpointlz` source instead of
  ListenBrainz, via `ND_LISTENBRAINZ_BASEURL`. Its own scrobbler is used rather
  than a Subsonic source because that one is the only path that sends multiple
  artists and replays scrobbles made while offline.
- multi-scrobbler forwards everything to ListenBrainz. A source scrobbles to
  every client by default, so adding Maloja later is one more `clients` entry.

Pointing `BaseURL` away from listenbrainz.org is safe: only `submit-listens` and
`validate-token` follow it. Similar-artists, similar-songs, artist metadata and
popularity are hardcoded to listenbrainz.org and labs.api.listenbrainz.org in
Navidrome's client, so radio and the metadata agent are unaffected.

Four things nix cannot do, all one-time:

1. Create a Spotify app at developer.spotify.com with redirect URI
   `http://127.0.0.1:9078/callback`, and put its id and secret into
   `~/.local/share/music-stack/multi-scrobbler/config.json`. Spotify rejects
   `localhost` redirects and requires https for everything except loopback.
2. Put a ListenBrainz user token and username into the `listenbrainz` client in
   the same file, then `docker restart multi-scrobbler`.
3. In Navidrome (profile icon → ListenBrainz), link with `MSLZ_KEY` from
   `.api-keys`, not the real ListenBrainz token. Existing links break when the
   base URL moves, so this has to be redone once per user.
4. Authorise Spotify from the dashboard at http://127.0.0.1:9078.

Live plays only go forward from here. Backfilling older Spotify history is
still a manual job: request the data export from Spotify, wait the few weeks it
takes to arrive, then feed the ZIP to ListenBrainz at
`listenbrainz.org/settings/import/`.

## API keys

Generated once by the launcher into `~/.local/share/music-stack/.api-keys` and
substituted into the Lidarr, slskd, Soularr and multi-scrobbler seed configs. Both Lidarr and
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
- **Desktop (Kopuz)** — Opus 128. Kopuz runs on the linux laptops and streams
  over the tailnet, where a FLAC track took about a minute to load on a bad
  connection. Opus is safe: kopuz decodes it through
  `symphonia-adapter-libopus`.
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
- Real listening history, which is what multi-scrobbler is for (see
  Scrobbling). ListenBrainz's own Spotify connection imports only the last 30
  days and connecting Last.fm does nothing retroactively, so anything older
  than that arrives only through the manual export import.
- Playlists generate on troi-bot's schedule (daily-jams after local midnight,
  weekly-jams Mondays), not on demand.

The plugin matches tracks by MusicBrainz ID, falling back to artist/title for
`fallbackCount` tracks (default 15). Files without MBIDs are effectively
invisible to discovery, which is what beets is for.

## Spotify playlists

`~/.local/share/music-stack/playlists.json` holds the tracklists kept from the
Spotify account export (`Playlist1.json`, in Spotify's `title` + `artists`
shape). The `kyan.music-stack-playlists` agent matches them against the
Navidrome library every hour and writes `<name>.m3u` into the library root,
which Navidrome imports on its next scan.

An export is a snapshot, so the hourly run is not about new Spotify data: it is
about the library catching up. Most tracks miss on the first pass and appear
weeks later as Soularr works through Lidarr's wanted list. Matching is
title-first with the Spotify remix and "slowed" suffixes stripped
progressively, then an artist check, because a Soulseek rip rarely carries the
exact title Spotify shows.

The agent leaves the `.m3u` untouched when the match is unchanged (Navidrome
reimports on mtime) and exits without writing anything if the container is
down, so a stopped stack cannot blank a playlist. Run it by hand with
`--misses` to list what is still unmatched.

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
