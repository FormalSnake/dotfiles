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
| multi-scrobbler | 9078 | Buffers Navidrome's plays on the way to ListenBrainz |
| Explo | 7288 | Downloads ListenBrainz weekly-exploration tracks the library lacks, via slskd |

One launchd agent (`kyan.music-stack`) runs `docker compose up` in the
foreground under `KeepAlive`, so launchd restarts the stack if it dies. It
refuses to start when `/Volumes/Music` is absent — without the SD card
Navidrome would scan an empty folder and mark the whole library deleted.

## Paths

```
/Volumes/Music/library      final library, Navidrome scans this (/music in containers)
/Volumes/Music/library/explo  Explo's downloads, picked up by the ordinary scan
/Volumes/Music/library/_edits  hand-added tracks Lidarr does not own
/Volumes/Music/downloads    slskd output, shared back to Soulseek (/downloads)
/Volumes/Music/incomplete   slskd partials
/Volumes/Music/purchases    drop bought albums here, then run `music-import`
/Volumes/Music/.trash       music-gc quarantine, one folder per sweep date
~/.local/share/music-stack  per-service config + databases
~/.local/share/music-stack/navidrome-backup  Navidrome DB backups, every 6h, 14 kept
docker volume music-stack_navidrome-data     Navidrome's own data dir (/data)
```

`library` and `downloads` mount at the *same container path* in every service.
Soularr hands Lidarr the path slskd reported, so a mismatch shows up as a
confusing "file not found" on import rather than an obvious path bug.

### `_edits`: tracks with no MusicBrainz release

Slowed, sped-up and nightcore edits circulate on YouTube and streaming without
ever becoming MusicBrainz releases, so Lidarr has nothing to want and Soulseek
has nothing to find. They go in `_edits/`, one folder per track, tagged by hand.

It sits beside the artist folders rather than inside one because Lidarr owns
every artist folder under `library/`, and an unmapped file in one lands in its
manual-import queue on every rescan. Navidrome groups by tags, not by folder,
so the track still shows up under its real artist; drop a `cover.jpg` in
alongside it for art.

These and the YouTube singles below are the library's only lossy files. yt-dlp's `bestaudio` is Opus around
128 kbps, and remuxing that into Ogg Opus (`ffmpeg -c:a copy`) keeps it as-is.
Re-encoding to FLAC would multiply the size for nothing.

Getting one into a `playlists.json` playlist needs the entry title to match the
file's title tag exactly, because the matcher tries the unstripped title first:
`I Took A Pill In Ibiza - Seeb Remix (Slowed + Reverb)` picks the edit, while
anything shorter normalises to the same key as the plain remix and picks that
instead. That fallback is deliberate, and it is what the playlist shows until
the edit exists.

First one, 2026-08-11: the Ibiza edit above, alongside the Seeb remix itself on
`At Night, Alone. (Expanded Edition)`.

A whole SoundCloud set by one uploader goes in as a single album folder instead
of one folder per track, since the tracks share an artist and only make sense
together: `_edits/wtfpreston/` (32 tracks, 2026-08-14) from
`soundcloud.com/mlicavoli/sets/wtfpreston-songs`, tagged
`artist = album = wtfpreston` with the playlist position as the track number.
SoundCloud serves no Opus, so those are the mp3 128 kbps `http_mp3_1_0` stream
copied through ffmpeg to write the tags. Nothing about them exists in
MusicBrainz, so Lidarr and Soularr never see them.

The watcher does not notice a folder that did not exist when it started
watching: the 32 files sat there unscanned for five minutes until
`touch library/_edits` changed the parent's mtime, which triggered the usual
`WATCHERWAIT` scan ten seconds later. Otherwise it waits for the hourly scan.

### Singles Soulseek never has

A single that stays on the wanted list for weeks is one nobody on Soulseek
shares, and waiting longer does not change that. Those come from the artist's
own YouTube upload instead: yt-dlp `bestaudio[ext=webm]`, remuxed with
`ffmpeg -c:a copy` and tagged with the MusicBrainz ids Lidarr already holds
(`/api/v1/track?albumId=`), named the way Lidarr would name them and dropped
into the album folder. A `RefreshArtist` then maps the file, so Lidarr stops
wanting the album and Soularr stops searching for it. Lidarr grades it
`OGG Vorbis Q5`, so a lossless copy that turns up later still upgrades it.

The nixpkgs yt-dlp (2026.07 on this channel) gets a 403 on every YouTube
stream; `nix shell github:NixOS/nixpkgs/nixpkgs-unstable#yt-dlp` works.

If Lidarr's metadata mirror has no release for the album (`releases: []` on
the album, "Couldn't find similar album" on manual import) the file cannot be
mapped and would sit in the manual-import queue on every rescan, so it goes to
`Non-Album/<artist>/<title>.opus` like the Moonshine singles instead.

First two, 2026-08-25: Niko B's *Quick Drive* (mapped) and *Canada Goose*
(`Non-Album/`, MusicBrainz has the release but Lidarr does not).

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

1. `scripts/music-want.sh "Artist" "Album"` monitors that one album, adding the
   artist first if Lidarr does not have them.
2. Soularr polls Lidarr's wanted list every 300s, searches slskd.
3. slskd downloads into `downloads/`.
4. Soularr tells Lidarr to import; Lidarr renames into
   `library/Artist/Album (Year)/`.
5. Navidrome's watcher picks it up within ~10s.

Adding an artist in the web UI no longer starts this. The root folder's
`defaultMonitorOption` is `none` (reapplied by the reconcile), so an add lands
the artist with their catalogue visible and nothing on the wanted list. That is
deliberate: Lidarr's default was to monitor every release MusicBrainz lists,
which is how one liked song became a thirteen-album download and how the
library reached 206 GB with 1132 of 10379 tracks ever played. `music-want.sh`
is the way back in, and `--track "Artist" "Song title"` finds the album
carrying a song when you only know the song.

Lidarr's own indexer and download-client machinery is unused, which is why its
health page permanently shows three warnings about missing indexers and
download clients. **Those are expected and will never clear.**

## Scrobbling

Everything is played through Navidrome now, and every listen ends up in
ListenBrainz:

- **Navidrome** posts to multi-scrobbler's `endpointlz` source instead of
  ListenBrainz, via `ND_LISTENBRAINZ_BASEURL`. Its own scrobbler is used rather
  than a Subsonic source because that one is the only path that sends multiple
  artists and replays scrobbles made while offline.
- multi-scrobbler forwards everything to ListenBrainz, buffering and retrying
  when the network is down. A source scrobbles to every client by default, so
  adding Maloja later is one more `clients` entry.
- ListenBrainz is the history of record, and `kyan.music-stack-listens` reads
  it back into Navidrome's play counts (see Discovery).

There was a Spotify source too, polled every 60s because Spotify cannot push
plays out. The subscription was cancelled on 2026-08-11 and the source was
removed from the seed and from the live config; the years of history it
collected stay in ListenBrainz. With one source left, multi-scrobbler is now
only a buffer: dropping it means pointing `ND_LISTENBRAINZ_BASEURL` back at
listenbrainz.org and re-linking with the real token, which is a manual step
per user, so it stays.

Pointing `BaseURL` away from listenbrainz.org is safe: only `submit-listens` and
`validate-token` follow it. Verified against 0.63.2
(`adapters/listenbrainz/client.go`), where `lbzApiUrl` and `labsBase` are
constants: artist metadata, popularity, similar-artists and similar-recordings
all ignore `BaseURL`, so radio and the metadata agent are unaffected.

Two things nix cannot do, both one-time:

1. Put a ListenBrainz user token and username into the `listenbrainz` client in
   `~/.local/share/music-stack/multi-scrobbler/config.json`, then
   `docker restart multi-scrobbler`.
2. In Navidrome (profile icon → ListenBrainz), link with `MSLZ_KEY` from
   `.api-keys`, not the real ListenBrainz token. Existing links break when the
   base URL moves, so this has to be redone once per user.

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
- **A service missing from the stack** — `docker compose start`, run first and
  ahead of the early exits, since a stopped Lidarr would otherwise abort the
  whole reconcile. `compose up` can race a container still shutting down from
  the previous agent run: it reads that container as present, leaves it alone,
  and the container then exits by itself. `restart: unless-stopped` will not
  bring back something stopped explicitly, so the stack runs on short one
  service. slskd lost that race during a rebuild on 2026-08-09 and stayed down
  for twenty minutes while soularr crash-looped on `Failed to resolve 'slskd'`.
- **Per-client transcoding** — `kyan.music.playerProfiles`. Applied
  unconditionally, so nix is authoritative: a profile changed by hand in the
  web UI reverts within ten minutes.
- **AudioMuse's clustering cron** — see Discovery. Its schedule table is in its
  own postgres, so a toggle in its UI would otherwise survive every rebuild.

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

## Plugins

Six `.ndp` files, staged by the launcher on every start. Four come from
nixpkgs (`listenbrainz-daily-playlist`, `audiomuseai`, `apple-music`,
`discord-rich-presence`); `navibeat-mixes` and `nd-lyrics` are prebuilt
release files pinned by hash in `music.nix`. Every new or updated plugin must
be approved in the web UI (profile icon → Plugins) before it does anything —
discovery alone is inert, and Navidrome re-disables a plugin whenever its file
changes.

- **navibeat-mixes** — time-of-day / genre / artist mixes as ordinary Subsonic
  playlists; NaviBeat renders them as its Home shelf. Needs its four
  permissions approved; time-of-day mixes take weeks to become personal (the
  Subsonic API exposes only last-played, so it builds its own play log).
- **nd-lyrics** — replaced the LRCLIB fetch script and its hourly agent
  (removed 2026-08-09). Fetches on client request, from LRCLIB and lyrics.ovh
  by default; the manifest also offers lrcmux, NetEase, KuGou, QQ Music, Apple
  Music (needs a subscriber `media-user-token`) and stixoi.info, settable with
  `navidrome plugin edit`. `ND_LYRICSPRIORITY` is **reordered from Navidrome's
  default**, which puts `.yaml`/`.yml`/`.txt` ahead of `.lrc` and the plugin
  last. The plugin writes a sidecar in whatever format the provider had, so
  under that order a plain-only `.yml` or `.txt` outranks a synced `.lrc`
  forever and the plugin never gets asked again to upgrade it. Only the
  always-synced extensions keep their free local hit now; everything plain sits
  behind the plugin. Sidecars are read at request time, not at scan time, so
  editing one takes effect immediately with no rescan. Enable its
  write-to-files option to keep growing the sidecar collection (it writes the
  best format the provider had, e.g. `.yml` lyricsfiles, all read directly via
  LyricsPriority). The plugin sandbox mounts libraries read-only; writing
  needs `docker exec navidrome /app/navidrome plugin edit nd-lyrics
  --write-access` plus a container restart — runtime state, reapply after a
  from-scratch rebuild. The Navidrome web UI cannot display plugin-served
  lyrics; NaviBeat and kopuz can.
- **apple-music** — metadata agent for artist images and localized album
  bios, keyless. Addressed as `apple-music-plugin` in `ND_AGENTS` (agents go
  by `.ndp` basename, and that is the filename nixpkgs ships), ahead of
  lastfm so its art wins.
- **discord-rich-presence** — now-playing in the Discord status. Configured
  entirely in the plugin UI: a Discord application client id plus a per-user
  Discord token. Grabbing a user token is against Discord's ToS; decide there,
  nothing about it lives in nix.

## Explo

Fetches the ListenBrainz weekly-exploration playlist and downloads the tracks
the library lacks — the one thing the daily-playlist plugin cannot do, since
it only matches what is already on disk. Soulseek (the existing slskd, same
API key) is the only configured source: the youtube source would seed lossy
rips into a FLAC library.

The seed at `~/.local/share/music-stack/explo/.env` needs its `CHANGEME`s
filled in once: web UI login, ListenBrainz username + token, and a real
Navidrome login (playlists are created as that user). After that the wizard at
`:7288` owns the file — it and the settings UI write schedules and options
back into it, same write-once contract as the other seeds. Downloads land in
`library/explo`, so Navidrome's ordinary scan imports them.

## Discovery

Three engines produce the auto playlists and the per-song radio, and in August
2026 all three were failing at once, which is what made every generated mix
look like the same thirty songs.

**Radio comes from AudioMuse, not ListenBrainz.** `ND_AGENTS` now leads with
`audiomuseai`. Navidrome's `SimilarSongs` asks the agent chain for songs like
the seed track and stops at the first agent that returns anything
(`core/agents/agents.go`, `callAgentSliceMethod`). ListenBrainz answers a track
seed out of labs `similar-recordings`, which is chart-level co-listening data:
for a Soulseek library almost none of it is on disk, and `SimilarSongs` returns
that empty match set rather than falling back to the similar-artists algorithm
(`core/external/provider.go`). Measured before the change, seeds carrying a
recording MBID returned nought to one track (Oliver Tree "Miss You" → 0, Drake
"Nonstop" → 1) while seeds without one got a full twenty from the healthy
fallback. After it, all six probe seeds returned nineteen or twenty
genre-coherent tracks. AudioMuse needs no MBID and no listening history, which
is why it suits this library; ListenBrainz stays behind it for similar-artists,
popularity and the daily-playlist plugin.

**AudioMuse's own playlists need its clustering cron.** Analysis (nightly at
03:00) computes the embeddings; clustering (05:00) is what writes the
`*_automatic` playlists. Clustering was switched off by hand on 2026-08-09 and
the playlists it had made were deleted, so analysis kept running and produced
nothing visible. The schedule lives in AudioMuse's postgres rather than in a
config file, so `kyan.music-stack-reconcile` now re-enables it, the same way it
reapplies Lidarr and Navidrome settings. To turn it off for real, remove that
block; toggling it in the web UI is reverted within ten minutes.

**Play counts come from ListenBrainz.** Navidrome only counts what it played
itself: 175 plays over 80 of 5063 tracks, against 21,074 listens in
ListenBrainz from the Spotify years. Everything that ranks by play count read
that 80-track pool, including NaviBeat, whose mixes fall back to "your most
played" until it has logged `minEventsForAffinity` (150) plays of its own. That
is why Morning, Afternoon, Evening and Night came out with an identical thirty
tracks. `kyan.music-stack-listens` pulls the history back down hourly and
upserts it into Navidrome's `annotation` table: 6970 listens (33%) match onto
660 tracks, and the rest name music not on disk yet.

It keys the history by recording MBID, else by artist and title, and rematches
the whole thing every run rather than only new listens, so a track Soularr
imports next month picks up the plays it already had. Counts are written with
`max()`, never `+`, so re-running never inflates them. State lives in
`~/.local/share/music-stack/.listens-state.json`; delete it to refetch the
whole history.

NaviBeat's time-of-day split needs its own play log, which Navidrome's play
counts cannot supply, so those four mixes stay identical to each other until it
has seen 150 plays (77 as of 2026-08-10). Everything ranked by play count —
Essentials, On Repeat, Wrapped, the decade mixes, Daily Mix seeds — widened
immediately.

`navidromePlugins.listenbrainz-daily-playlist` imports Weekly Jams, Daily Jams
and Weekly Exploration. Requirements, all easy to miss:

- Enable **and configure** the plugin in the web UI (profile icon → Plugins).
  Discovering the `.ndp` only registers it; an unconfigured plugin is silently
  inert.
- A ListenBrainz account, mapped to the Navidrome username, following
  `troi-bot`.
- Real listening history, which is what multi-scrobbler is for (see
  Scrobbling). The 21k listens from the Spotify years were imported by hand as
  a CSV on 2026-07-29; everything since comes from Navidrome.
- Playlists generate on troi-bot's schedule (daily-jams after local midnight,
  weekly-jams Mondays), not on demand.
- ListenBrainz has to have processed the account at all. The back history
  arrived as a bulk CSV import on 2026-07-29 and as of 2026-08-10 the batch
  side had not caught up: `stats/user/<u>/artists?range=all_time` and
  `cf/recommendation/user/<u>/recording` both return 204, so troi-bot has
  generated nothing (`playlists/createdfor` → 0) and the plugin logs "No
  playlist ... found with algorithm/source patch 'daily-jams'". Nothing local
  fixes that; it clears when LB's next dump and Spark cycle picks the account
  up. Those three endpoints are the check.

The plugin matches tracks by MusicBrainz ID, falling back to artist/title for
`fallbackCount` tracks (default 15). Files without MBIDs are effectively
invisible to discovery, which is what beets is for.

## Spotify playlists

`~/.local/share/music-stack/playlists.json` holds the tracklists kept from the
Spotify account export (`Playlist1.json`, in Spotify's `title` + `artists`
shape). The `kyan.music-stack-playlists` agent matches them against the
Navidrome library every hour and writes `<name>.m3u` into the library root,
which Navidrome imports on its next scan.

An export is a snapshot, and with the account cancelled it is the last one, so
the hourly run is not about new Spotify data: it is about the library catching
up. Most tracks miss on the first pass and appear
weeks later as Soularr works through Lidarr's wanted list. Matching is
title-first with the Spotify remix and "slowed" suffixes stripped
progressively, then an artist check, because a Soulseek rip rarely carries the
exact title Spotify shows.

The agent leaves the `.m3u` untouched when the match is unchanged (Navidrome
reimports on mtime) and exits without writing anything if the container is
down, so a stopped stack cannot blank a playlist. Run it by hand with
`--misses` to list what is still unmatched.

### Playlists the export no longer owns

`kyan.music.frozenPlaylists` (`G Y M`, `G Y M 2`, `Chill Focus`) are curated in
the app now, not derived from the Spotify snapshot. The matcher skips those
names outright, and the reconcile clears Navidrome's `sync` flag on them, which
is the part that actually matters: an imported playlist carries `sync = 1` and
Navidrome rebuilds it from the `.m3u` on every scan, so a track added in the
app vanishes at the next one. With the flag cleared the file is ignored and the
copy in the database is the real one. The `.m3u` is left on disk as the
starting point it was; deleting it is safe once the flag is off.

Adding a name to the option freezes that playlist wherever it is. Removing one
hands it back to the matcher, which rebuilds it from `playlists.json` and drops
everything added by hand.

### Smart playlists

A `.nsp` file in the library root is a Navidrome smart playlist: it is
re-evaluated on every scan, so it needs no matcher run and picks up new imports
on its own. `Quattro.nsp` (rally house) is the first, matching genre
`rally house` or `Speed House`, or artist containing Noxygen, wev or Obsk.
`contains` on artist is what catches the casing and collaboration spellings the
tags carry (`wev`, `Wev`, `worldwidewev`, `wev & Nick AM`).

The playlist agent only writes `<name>.m3u` for names in `playlists.json`, so
the two mechanisms never touch each other's files.

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

### Covers for albums that have none

`scripts/music-fill-covers.py` gives every album Navidrome shows blank a cover.
Twenty-five are, almost all hardstyle and nightcore edits plus a run of Eminem
bootlegs: a Soulseek rip of an edit carries no art, and neither Lidarr nor
MusicBrainz has any to fetch.

It works from Navidrome's own view of which albums have art rather than from a
directory walk, because an embedded picture counts and half of these are loose
singles under `Non-Album/` and `_edits/` where the folder name says nothing.

**No local file does not mean blank.** `CoverArtPriority` ends in `external`, so
for an album with no image and no embedded picture Navidrome asks its metadata
agents and shows whatever Apple Music, Last.fm or Deezer has. A `cover.jpg`
outranks that. The first run of this script, on 2026-08-19, did not know it and
buried 89 albums under placeholders, Niko B's `just call me` among them. So
every candidate is now fetched over `getCoverArt` first and skipped if a real
image comes back. Navidrome answers an album it has nothing for with the grey
note embedded in its binary rather than an error, so the check is a hash of the
response against `PLACEHOLDER_MD5`; if a Navidrome release changes that asset
every album reads as covered and the script writes nothing, which is the
harmless way for it to break. Sixty of the ninety candidates turned out to have
agent art. The Subsonic login comes from the audiomuse container, the one part
of the stack seeded with a real Navidrome account.

An edit takes the original release's cover: `Nevada - Slowed & Reverb` by
PANTHEON ends up with Vicetone's Nevada art, matched by the same progressive
suffix stripping the playlist and listens agents use, same artist first and
then a title only one artist in the library claims. Six matched that way.

Everything left gets a generated cover in the same shape as the Artemas ones:
the album title in Spotify Mix Black over a four-point mesh gradient, artist
and year along the bottom. The colours are hashed from artist and album, so a
re-run repaints the same cover and no two neighbouring albums come out alike.
Cyrillic and anything else outside Latin falls back to Arial Unicode, since
Spotify Mix draws blanks for it and ImageMagick has no font fallback.

Same `cover.jpg` rule and the same revert as above. It skips a folder that
already has one, which is also how the three Moonshine singles sharing
`Non-Album/Moonshine/` end up sharing a cover: one folder, one image.
`--dry-run` lists what it would write and where each carried cover comes from.

## Soulseek

Credentials are the one thing nix cannot generate — set `soulseek.username` and
`password` in `~/.local/share/music-stack/slskd/slskd.yml`.

`downloads/` is shared back to the network. Soulseek is ratio-driven and peers
deprioritise or reject accounts sharing nothing, so a new account sees a high
rejection rate until files accumulate. slskd only rescans shares at startup or
on demand (`PUT /api/v0/shares`).

## Broken rips

Nothing between Soulseek and the player checks that a file holds the audio its
tags promise. A peer sharing a 30-second preview under the full track's name
gets imported as the real thing, because Lidarr trusts the tags and Navidrome
trusts the header: the UI shows 3:37 and the audio stops at 0:30. Decoding is
the only test that catches it.

`kyan.music-stack-verify` decodes the whole library daily and writes
`~/.local/share/music-stack/broken-tracks.txt`, one line per file, with either
`audio ends at Ns of Ms` (truncated) or a decode-error count (damaged frames).
Results are keyed by size and mtime in `.verify-state.json`, so only newly
imported files cost anything after the first pass. Errors from the attached
cover art are ignored: a JPEG stored under a PNG signature is a tag defect, not
a damaged track.

It reports and never deletes. Re-requesting automatically would pull the same
bad copy from the same peer, so replacing one is manual: delete the track file
through Lidarr (`DELETE /api/v1/trackfile/{id}`, which removes it from disk and
marks the album missing) and Soularr picks it up on its next poll.

First sweep, 2026-08-09: 28 bad files in 4656. Five were 30-second previews
(ACRAZE, three HUGEL singles, Mau P), and John Summit's *Comfort in Chaos* was
damaged across the whole album. All were deleted and re-requested.

## Keeping the library to what you listen to

`kyan.music-stack-gc` runs daily and pulls in both directions. `music-gc` runs
it by hand; `--dry-run` prints what it would do and touches nothing.

**Trimming the wanted list.** For every artist Lidarr holds, each monitored
album with no files is checked against what you have actually asked for: the
listens in `.listens-state.json` (matched by recording MBID, else by artist and
title through the same suffix stripping the playlist matcher uses) and the
tracklists in `playlists.json`. An album nothing names is unmonitored, so
Soularr stops searching for it. A MusicBrainz discography is a catalogue, not a
request: the first pass cut 50 of the 98 missing albums it looked at and kept
48. This is reversible, and `music-want.sh` puts one back.

**Quarantining what you never played.** An artist whose every track has sat at
zero plays for 60 days has their files moved to `/Volumes/Music/.trash/<date>/`,
their Lidarr albums unmonitored, their artist row unmonitored, and their
`downloads/` copies pruned. Sixty days later that batch is deleted for real.
`music-gc --restore "<artist>"` moves the files back and re-monitors, until the
batch is purged.

Nothing is swept if any of these hold: a track of theirs sits in a playlist
that is `sync = 1` or named in `frozenPlaylists`; the Lidarr artist carries the
`keep` tag (created by the reconcile, applied by hand in the UI); their newest
file is under 14 days old. Play counts come from Navidrome's `annotation`
table, so they include the ListenBrainz history the listens agent backfills,
not just what Navidrome itself has played. If that backfill has never run the
whole thing exits without touching anything, since every artist would read as
untouched. It also exits if the library query returns under 50 artists, which
is what a scan caught mid-flight looks like.

One run quarantines at most 25 artists, largest first.

## Removing artists

`scripts/music-forget-artists.sh <lidarr id | from-to> ...` deletes artists
from Lidarr with their files and prunes their `downloads/` and
`downloads/failed_imports/` folders, which Lidarr's own delete leaves behind.
Lidarr ids are contiguous per add session, so a batch added in one sitting
is one range: the 42 artists added for the grandparents on 2026-08-14 were
`165-206`, 33 GB, removed 2026-08-25. A playlist that only made sense with
them goes out of `playlists.json` by hand, together with its `.m3u`.

## Gotchas

- **A full SD card stops everything and nothing says so.** slskd fails every
  download with `No space left on device` in its own log, Soularr reports
  each as "failed to find a match" and Lidarr's wanted list just stops
  shrinking. Filled up 2026-08-25 (`failed_imports/` alone was 14 GB);
  `df -h /Volumes/Music` is the first check when nothing has arrived for
  days.
- **Soularr crashes rather than skipping when an album vanishes mid-flight.**
  Changing a metadata profile or deleting an artist while downloads are queued
  invalidates album ids; Soularr's cleanup path asks Lidarr for one, gets a
  404, and exits — then crash-loops on restart. Fix: `docker restart soularr`.
- **`search_timeout` is milliseconds**, passed straight to slskd. Anything under
  a second returns `TimedOut` with zero responses.
- **`album_prepend_artist` defaults to false**, so Soularr searches the bare
  album title. Searching Soulseek for "Currents" matches nothing useful.
- **Lidarr's `monitor: "none"` add-option unmonitors the artist and nothing
  else.** Every album still arrives `monitored: true`; the add is inert only
  because the artist row is off, so re-monitoring the artist lights up the
  whole discography at once. `music-want.sh` clears the albums by hand after
  the refresh and sets the artist row last, which is the only ordering that
  ends with one album wanted.
- **`PUT /album/monitor` answers 202 and works through a command queue.** Two
  calls issued back to back land in either order, so a bulk unmonitor followed
  immediately by a single monitor can end with neither, or with both undone.
  `music-want.sh` polls for the state each call was meant to produce before
  making the next one.
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
