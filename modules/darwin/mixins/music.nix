{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kyan.music;
  home = config.users.users.kyandesutter.home;

  stackDir = "${home}/.local/share/music-stack";
  incompleteDir = "/Volumes/Music/incomplete";
  # Quarantine for the janitor. Beside the library rather than inside it, so
  # Navidrome never scans what is on its way out.
  trashDir = "/Volumes/Music/.trash";

  uid = "502";
  gid = "20";

  # Navidrome scans player.transcoding_id into a Go string, so a NULL there
  # makes every lookup for that client fail with "converting NULL to string is
  # unsupported". It must be an empty string. Bound out here because a literal
  # '' inside a Nix indented string terminates it.
  sqlEmpty = "''";

  # nixpkgs' navidrome is `broken = stdenv.hostPlatform.isDarwin`, so the whole
  # stack runs in Docker (OrbStack) rather than half launchd, half container.
  # The plugin derivations are plain .ndp data files and still build here, so
  # plugin versions stay pinned by the flake even though the server does not.
  #
  # Not in nixpkgs yet; both ship a prebuilt .ndp per release. Same $out/share
  # layout as the nixpkgs plugins so the launcher stages them identically. The
  # nd-lyrics filename is load-bearing: Navidrome registers the plugin under
  # the file's basename, which is what LyricsPriority refers to.
  prebuiltPlugin =
    name: url: hash:
    pkgs.runCommand "navidrome-plugin-${name}" { } ''
      install -Dm644 ${pkgs.fetchurl { inherit url hash; }} $out/share/${name}.ndp
    '';

  # navibeat-mixes builds time-of-day / genre / artist mixes as ordinary
  # playlists over the Subsonic API; NaviBeat additionally renders them as its
  # Home shelf. nd-lyrics replaces the old LRCLIB fetch script: same source
  # plus several more, fetched when a client asks instead of on an hourly
  # library sweep, with the existing .lrc sidecars left authoritative via
  # LyricsPriority below.
  pluginPkgs =
    (with pkgs.navidromePlugins; [
      listenbrainz-daily-playlist
      audiomuseai
      apple-music
      discord-rich-presence
    ])
    ++ [
      (prebuiltPlugin "navibeat-mixes"
        "https://github.com/nenadjokic/navibeat-mixes/releases/download/v0.7.1/navibeat-mixes.ndp"
        "sha256-NTPKX6ONbM//yE6ViSJswVPHO+HzSse9ZdMTQwPsaeM="
      )
      (prebuiltPlugin "nd-lyrics"
        "https://github.com/J0R6IT0/navidrome-lyrics-plugin/releases/download/v7.2.0/nd-lyrics.ndp"
        "sha256-qRluW04sLrKqzLnzXJ+vb0iP6Qgf9WhbFVaQFobHVA8="
      )
    ];

  # Container-side paths are deliberately identical across services: Soularr
  # hands Lidarr the path slskd reported, so a mismatch surfaces as a confusing
  # "file not found" on import rather than as an obvious path bug.
  compose = pkgs.writeText "music-stack-compose.yml" ''
    services:
      navidrome:
        image: deluan/navidrome:latest
        container_name: navidrome
        user: "${uid}:${gid}"
        environment:
          # Navidrome was the one service left on UTC. Timestamps in the
          # database are UTC either way, but the plugins bucket by local hour
          # inside this container: NaviBeat's morning / afternoon / evening /
          # night mixes were reading an hour early, so a play just before
          # midnight counted as evening. This variable alone does nothing:
          # the image carries no tzdata, so the zoneinfo bind mount below is
          # what makes the zone resolve instead of silently staying UTC.
          TZ: Atlantic/Canary
          ND_MUSICFOLDER: /music
          ND_DATAFOLDER: /data
          ND_CACHEFOLDER: /data/cache
          ND_PORT: "4533"

          ND_PLUGINS_ENABLED: "true"
          ND_PLUGINS_FOLDER: /plugins

          # Discovery: audiomuseai leads because it answers a track seed from
          # the library's own audio, and Navidrome stops at the first agent
          # returning anything (core/agents/agents.go, callAgentSliceMethod).
          # ListenBrainz answers a track seed out of labs similar-recordings,
          # which is chart-level co-listening data: for a Soulseek library it
          # matches almost nothing on disk, and SimilarSongs returns that empty
          # match set instead of falling back to the similar-artists algorithm
          # (core/external/provider.go). Every seed carrying an MBID therefore
          # came back with nought to one track. ListenBrainz stays in the chain
          # behind it for similar-artists, popularity and the daily-playlist
          # plugin; apple-music sits ahead of lastfm because its artist images
          # and localized bios are current where lastfm's are stale.
          ND_ENABLEEXTERNALSERVICES: "true"
          ND_LASTFM_ENABLED: "true"
          ND_LISTENBRAINZ_ENABLED: "true"
          # "apple-music-plugin" because agents are addressed by the .ndp
          # basename, and that is what the nixpkgs derivation ships.
          ND_AGENTS: audiomuseai,listenbrainz,apple-music-plugin,lastfm,deezer

          # Reordered from Navidrome's default, which puts .yaml/.yml/.txt
          # ahead of .lrc and the plugin last. nd-lyrics writes a sidecar in
          # whatever format the provider had, so a plain-only .yml or .txt
          # would then outrank a synced .lrc forever and the plugin would never
          # be asked again to upgrade it. Only the always-synced extensions
          # keep their free local hit; everything plain sits behind the plugin,
          # which caches its answers and still falls through to those files
          # when it has nothing.
          ND_LYRICSPRIORITY: ".ttml,.elrc,.lrc,.srt,nd-lyrics,.yaml,.yml,.txt,embedded"

          # Scrobbles go through multi-scrobbler, which buffers and retries them
          # on the way to ListenBrainz. Only submit-listens and validate-token
          # follow this URL; similar-artists, artist metadata and popularity are
          # hardcoded to listenbrainz.org in Navidrome's client (verified
          # against 0.63.2, adapters/listenbrainz/client.go), so discovery keeps
          # working while the stack is pointed here.
          ND_LISTENBRAINZ_BASEURL: http://multi-scrobbler:9078/1/

          # Without this, Subsonic's getArtist only counts albums an artist is
          # credited on as *album* artist, so a feature such as Majestic on
          # "Who's That What's That" is an artist with an empty page (the
          # track only reachable under Niko B). Navidrome splits the credit
          # correctly either way; this is what makes the second artist browsable.
          ND_SUBSONIC_ARTISTPARTICIPATIONS: "true"

          # Keeps cellular listening usable: library stays FLAC, clients that
          # ask for less get Opus.
          ND_ENABLETRANSCODINGCONFIG: "true"
          ND_TRANSCODINGCACHESIZE: 2GB

          # The database has been corrupted twice (2026-08-02 and 2026-08-03),
          # so keep restorable copies. Written with SQLite's own online backup,
          # a single sequential file write, which is safe on the bind mount in
          # a way that concurrent access is not.
          ND_BACKUP_PATH: /backup
          ND_BACKUP_SCHEDULE: "@every 6h"
          ND_BACKUP_COUNT: "14"

          ND_SCANNER_WATCHERWAIT: 10s
          # ND_SCANSCHEDULE was silently ignored here: 0.63 reads the schedule
          # from Scanner.Schedule, and the old name left periodic scans off.
          ND_SCANNER_SCHEDULE: "@every 1h"
        # /data is a docker volume, NOT a bind mount, and that is load-bearing.
        # SQLite needs working POSIX locks and a shared -shm mapping; over
        # OrbStack's virtiofs bind mount neither is reliable, and two writers
        # (the server plus the reconcile below, or anything run from macOS)
        # zero out pages. Living inside the VM's own filesystem makes ordinary
        # concurrent access safe again. Never open this database from the mac:
        # use `docker exec navidrome sqlite3 /data/navidrome.db`.
        volumes:
          - ${cfg.libraryDir}:/music
          - navidrome-data:/data
          - ${stackDir}/navidrome-backup:/backup
          - ${stackDir}/navidrome-plugins:/plugins
          # macOS keeps the real zoneinfo tree here; /usr/share/zoneinfo is a
          # symlink to it, and a symlink is not what the bind mount wants.
          - /var/db/timezone/zoneinfo:/usr/share/zoneinfo:ro
        ports:
          - "${toString cfg.port}:4533"
        restart: unless-stopped

      lidarr:
        image: lscr.io/linuxserver/lidarr:latest
        container_name: lidarr
        environment:
          - PUID=${uid}
          - PGID=${gid}
          - TZ=Atlantic/Canary
        volumes:
          - ${stackDir}/lidarr:/config
          - ${cfg.libraryDir}:/music
          - ${cfg.downloadDir}:/downloads
        ports:
          - "8686:8686"
        restart: unless-stopped

      slskd:
        image: slskd/slskd:latest
        container_name: slskd
        user: "${uid}:${gid}"
        environment:
          - TZ=Atlantic/Canary
        volumes:
          - ${stackDir}/slskd:/app
          - ${cfg.downloadDir}:/downloads
          - ${incompleteDir}:/incomplete
        ports:
          - "5030:5030"
        restart: unless-stopped

      soularr:
        image: mrusse08/soularr:latest
        container_name: soularr
        user: "${uid}:${gid}"
        environment:
          - TZ=Atlantic/Canary
          - SCRIPT_INTERVAL=300
          - WEBUI_ENABLED=true
        volumes:
          - ${cfg.downloadDir}:/downloads
          - ${stackDir}/soularr:/data
        ports:
          - "8265:8265"
        depends_on:
          - lidarr
          - slskd
        restart: unless-stopped

      # Navidrome posts here instead of straight to ListenBrainz, so listens
      # survive the network being down and a second target (Maloja, say) is one
      # `clients` entry away. It also polled Spotify until that subscription
      # was cancelled, which was the original reason for it.
      multi-scrobbler:
        image: foxxmd/multi-scrobbler:latest
        container_name: multi-scrobbler
        environment:
          - TZ=Atlantic/Canary
          - PUID=${uid}
          - PGID=${gid}
          - BASE_URL=http://127.0.0.1:9078
        volumes:
          - ${stackDir}/multi-scrobbler:/config
        ports:
          - "9078:9078"
        restart: unless-stopped

      # Downloads the ListenBrainz weekly-exploration tracks the library lacks,
      # the one thing the daily-playlist plugin cannot do: it only matches what
      # is already on disk. Soulseek is the only download source on purpose:
      # the youtube source would seed lossy rips into a FLAC library. Explo's
      # wizard and settings UI write back into the seeded .env, so it follows
      # the same contract as the other seeds: nix writes it once, never again.
      explo:
        image: ghcr.io/lumepart/explo:latest
        container_name: explo
        environment:
          - TZ=Atlantic/Canary
          - PUID=${uid}
          - PGID=${gid}
          - WEB_UI=true
        volumes:
          - ${stackDir}/explo/.env:/opt/explo/.env
          - ${stackDir}/explo/config:/opt/explo/config
          - ${cfg.libraryDir}/explo:/data
          - ${cfg.downloadDir}:/slskd
        ports:
          - "7288:7288"
        depends_on:
          - navidrome
          - slskd
        restart: unless-stopped

      # AudioMuse analyses the audio itself (tempo, timbre, energy) and answers
      # the "sounds like this" questions ListenBrainz cannot: it needs no
      # MusicBrainz ID, no listening history and no upstream batch job, which is
      # what makes it the discovery path that works on a Soulseek library.
      # Postgres and redis are its own, unpublished: only the UI on 8000 is
      # reachable from the host, and the mac already runs postgres elsewhere.
      audiomuse-redis:
        image: redis:7-alpine
        container_name: audiomuse-redis
        environment:
          - TZ=Atlantic/Canary
        volumes:
          - audiomuse-redis:/data
        restart: unless-stopped

      audiomuse-postgres:
        image: postgres:15-alpine
        container_name: audiomuse-postgres
        environment:
          - TZ=Atlantic/Canary
          - POSTGRES_DB=audiomusedb
        env_file:
          - ${stackDir}/audiomuse/audiomuse.env
        volumes:
          - audiomuse-postgres:/var/lib/postgresql/data
        restart: unless-stopped

      audiomuse-flask:
        image: ghcr.io/neptunehub/audiomuse-ai:latest
        container_name: audiomuse-flask
        environment:
          - SERVICE_TYPE=flask
          - TZ=Atlantic/Canary
          - POSTGRES_DB=audiomusedb
          - POSTGRES_HOST=audiomuse-postgres
          - POSTGRES_PORT=5432
          - REDIS_URL=redis://audiomuse-redis:6379/0
          - TEMP_DIR=/app/temp_audio
          - MEDIASERVER_TYPE=navidrome
          - NAVIDROME_URL=http://navidrome:4533
        env_file:
          - ${stackDir}/audiomuse/audiomuse.env
        volumes:
          - audiomuse-temp-flask:/app/temp_audio
          - audiomuse-plugins-flask:/app/plugin/installed
        ports:
          - "8000:8000"
        depends_on:
          - audiomuse-redis
          - audiomuse-postgres
        restart: unless-stopped

      # ONNX threads across every core it is given, so uncapped this one
      # container took 746% CPU and put the machine at load 17. Six of the VM's
      # ten leaves the mac usable over SSH while analysis runs; it only ever
      # costs wall-clock on a job that is already measured in hours.
      audiomuse-worker:
        image: ghcr.io/neptunehub/audiomuse-ai:latest
        container_name: audiomuse-worker
        cpus: 6
        environment:
          - SERVICE_TYPE=worker
          - TZ=Atlantic/Canary
          - POSTGRES_DB=audiomusedb
          - POSTGRES_HOST=audiomuse-postgres
          - POSTGRES_PORT=5432
          - REDIS_URL=redis://audiomuse-redis:6379/0
          - TEMP_DIR=/app/temp_audio
          - MEDIASERVER_TYPE=navidrome
          - NAVIDROME_URL=http://navidrome:4533
        env_file:
          - ${stackDir}/audiomuse/audiomuse.env
        volumes:
          - audiomuse-temp-worker:/app/temp_audio
          - audiomuse-plugins-worker:/app/plugin/installed
        depends_on:
          - audiomuse-redis
          - audiomuse-postgres
        restart: unless-stopped

    volumes:
      navidrome-data:
      audiomuse-redis:
      audiomuse-postgres:
      audiomuse-temp-flask:
      audiomuse-temp-worker:
      audiomuse-plugins-flask:
      audiomuse-plugins-worker:
  '';

  # All three seeds hold state that outlives the store path (credentials, API
  # keys, whatever the web UIs write back), so nix writes them once and never
  # rewrites them (same contract as DMS settings.json). @SLSKD_KEY@ and
  # @LIDARR_KEY@ are filled in by the launcher on first seed.
  lidarrSeed = pkgs.writeText "lidarr-seed.xml" ''
    <Config>
      <BindAddress>*</BindAddress>
      <Port>8686</Port>
      <UrlBase></UrlBase>
      <ApiKey>@LIDARR_KEY@</ApiKey>
      <AuthenticationMethod>External</AuthenticationMethod>
      <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
      <Branch>master</Branch>
      <LogLevel>info</LogLevel>
      <InstanceName>Lidarr</InstanceName>
    </Config>
  '';

  slskdSeed = pkgs.writeText "slskd-seed.yml" ''
    directories:
      downloads: /downloads
      incomplete: /incomplete
    shares:
      directories:
        - /downloads
    soulseek:
      username: CHANGEME
      password: CHANGEME
    web:
      port: 5030
      authentication:
        api_keys:
          soularr:
            key: @SLSKD_KEY@
            role: readwrite
            cidr: 0.0.0.0/0,::/0
  '';

  soularrSeed = pkgs.writeText "soularr-seed.ini" ''
    [Lidarr]
    api_key = @LIDARR_KEY@
    host_url = http://lidarr:8686
    download_dir = /downloads

    [Slskd]
    api_key = @SLSKD_KEY@
    host_url = http://slskd:5030
    download_dir = /downloads
    delete_searches = False
    stalled_timeout = 3600

    [Release Settings]
    use_most_common_tracknum = True
    allow_multi_disc = True
    accepted_countries = Europe,United Kingdom,United States,Worldwide
    accepted_formats = CD,Digital Media,Vinyl

    [Search Settings]
    # Milliseconds, not seconds: this is handed straight to slskd's search API.
    # Anything under a second returns TimedOut with zero responses.
    search_timeout = 5000
    maximum_peer_queue = 50
    minimum_peer_upload_speed = 0
    minimum_filename_match_ratio = 0.5
    allowed_filetypes = flac,mp3
    # Defaults to false upstream, which searches for the bare album title:
    # "Currents" alone matches nothing useful on Soulseek.
    album_prepend_artist = True
    search_type = incrementing_page
    number_of_albums_to_grab = 10

    [Logging]
    level = INFO
  '';

  # A source scrobbles to every client unless told otherwise, so the Navidrome
  # endpoint reaches ListenBrainz with no further wiring. The ListenBrainz user
  # token is the one value nix cannot generate. @MSLZ_KEY@ is what Navidrome
  # authenticates with: it replaces the real ListenBrainz token in Navidrome's
  # per-user link dialog.
  #
  # There was a Spotify source here too, polling the account because Spotify
  # cannot push plays anywhere. The subscription was cancelled on 2026-08-11 and
  # it went with it; everything is played through Navidrome now. The history it
  # collected lives on in ListenBrainz, which is what music-stack-listens reads.
  msSeed = pkgs.writeText "multi-scrobbler-seed.json" ''
    {
      "sources": [
        {
          "name": "navidrome",
          "enable": true,
          "type": "endpointlz",
          "data": {
            "token": "@MSLZ_KEY@"
          }
        }
      ],
      "clients": [
        {
          "name": "listenbrainz",
          "enable": true,
          "type": "listenbrainz",
          "data": {
            "token": "CHANGEME",
            "username": "CHANGEME",
            "url": "https://api.listenbrainz.org"
          }
        }
      ]
    }
  '';

  # Explo needs a real Navidrome login (playlists are created as that user),
  # the personal ListenBrainz account token, and web UI credentials of its
  # own (none of which nix can generate). Everything else the wizard asks for
  # is pre-answered here.
  exploSeed = pkgs.writeText "explo-seed.env" ''
    UI_USERNAME=CHANGEME
    UI_PASSWORD=CHANGEME

    LISTENBRAINZ_USER=CHANGEME
    LISTENBRAINZ_USER_TOKEN=CHANGEME

    EXPLO_SYSTEM=subsonic
    SYSTEM_URL=http://navidrome:4533
    SYSTEM_USERNAME=CHANGEME
    SYSTEM_PASSWORD=CHANGEME

    DOWNLOAD_SERVICES=slskd
    SLSKD_URL=http://slskd:5030
    SLSKD_API_KEY=@SLSKD_KEY@
    MIGRATE_DOWNLOADS=true
    RENAME_TRACK=true
  '';

  # Shared by the postgres container and both app containers, so the database
  # password only has to agree with itself. The Navidrome login is a real user
  # account (AudioMuse streams every track through the Subsonic API to analyse
  # it), which is why it cannot be generated here.
  audiomuseSeed = pkgs.writeText "audiomuse-seed.env" ''
    POSTGRES_USER=audiomuse
    POSTGRES_PASSWORD=@AUDIOMUSE_PG@
    NAVIDROME_USER=CHANGEME
    NAVIDROME_PASSWORD=CHANGEME
  '';

  # Lidarr's rename toggle and Navidrome's per-client transcoding both live in
  # application databases, not config files, so a stack rebuilt from scratch
  # silently reverts to defaults (unrenamed files dumped flat into the artist
  # folder, and raw 24-bit FLAC streamed to phones). Reapplied on a timer
  # rather than at seed time because Navidrome only creates a player row when
  # that client first connects, which can be days later.
  reconcile = pkgs.writeShellScript "music-stack-reconcile" ''
    set -uo pipefail
    export PATH="/usr/local/bin:/run/current-system/sw/bin:/usr/bin:/bin"

    # `compose up` can race a container still shutting down from the previous
    # agent run: it reads that container as present, leaves it alone, and the
    # container then exits on its own. `restart: unless-stopped` will not bring
    # back something that was stopped explicitly, so the stack keeps running
    # short one service. slskd lost that race during a rebuild on 2026-08-09
    # and stayed down for twenty minutes while soularr crash-looped on DNS.
    # `start` is a no-op for anything already running, so this runs first, and
    # ahead of the early exits below that a stopped Lidarr would trigger.
    docker compose -f ${compose} -p music-stack start >/dev/null 2>&1 || true

    [ -f "${stackDir}/.api-keys" ] || exit 0
    # shellcheck disable=SC1090
    . "${stackDir}/.api-keys"

    # Lidarr: without renameTracks the configured folder format is ignored
    # entirely and every album lands loose in the artist directory.
    naming=$(curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/config/naming) || exit 0
    if [ "$(printf '%s' "$naming" | jq -r '.renameTracks')" != "true" ]; then
      printf '%s' "$naming" | jq '.renameTracks=true' \
        | curl -sf -X PUT -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" \
            -d @- http://localhost:8686/api/v1/config/naming >/dev/null \
        && echo "reconcile: enabled Lidarr track renaming"
    fi

    # An add with the stock root-folder default monitors every release
    # MusicBrainz lists for the artist, so one liked song queues a whole
    # discography onto the wanted list. "none" leaves the add inert and
    # `music-want.sh` turns on the one album that was actually wanted. It
    # unmonitors the artist row too, which the script puts back; do not reach
    # for it by hand.
    root=$(curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/rootfolder \
      | jq -c '.[0] // empty')
    rootWant=$(printf '%s' "$root" | jq -c '.defaultMonitorOption = "none"
      | .defaultNewItemMonitorOption = "none"')
    if [ -n "$root" ] && [ "$rootWant" != "$root" ]; then
      printf '%s' "$rootWant" \
        | curl -sf -X PUT -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" -d @- \
            "http://localhost:8686/api/v1/rootfolder/$(printf '%s' "$root" | jq -r .id)" >/dev/null \
        && echo "reconcile: Lidarr adds now monitor nothing by default"
    fi

    # The janitor's opt-out. Tagging an artist `keep` in Lidarr exempts them
    # from both the wanted-list trim and the quarantine; the tag has to exist
    # before it can be applied in the UI.
    curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/tag \
      | jq -e 'map(select(.label == "keep")) | length > 0' >/dev/null \
      || curl -sf -X POST -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" \
           -d '{"label":"keep"}' http://localhost:8686/api/v1/tag >/dev/null

    # Nothing else in the stack puts cover art on disk: Navidrome only reads
    # art from the album folder or from the file's own tags, and a Soulseek
    # download carries embedded art only if whoever uploaded it bothered. The
    # Kodi consumer writes folder.jpg into every album folder from Lidarr's own
    # metadata, which is first in Navidrome's CoverArtPriority. The .nfo
    # sidecars are turned off (Navidrome ignores them).
    meta=$(curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/metadata) || exit 0
    xbmc=$(printf '%s' "$meta" | jq -c 'map(select(.implementation=="XbmcMetadata"))[0] // empty')
    want=$(printf '%s' "$xbmc" | jq -c '.enable = true
      | .fields |= map(.value = (.name == "artistImages" or .name == "albumImages"))')
    if [ -n "$xbmc" ] && [ "$want" != "$xbmc" ]; then
      printf '%s' "$want" \
        | curl -sf -X PUT -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" -d @- \
            "http://localhost:8686/api/v1/metadata/$(printf '%s' "$xbmc" | jq -r .id)" >/dev/null \
        && echo "reconcile: enabled Lidarr album/artist images"

      # Album art is written on import and on refresh, so anything already in
      # the library needs one refresh to catch up.
      for aid in $(curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/artist | jq -r '.[].id'); do
        curl -sf -X POST -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" \
          -d "{\"name\":\"RefreshArtist\",\"artistId\":$aid}" \
          http://localhost:8686/api/v1/command >/dev/null
      done
    fi

    # Lidarr models a standalone single as a one-track album, but the stock
    # "Standard" metadata profile disallows primary types Single and EP, so a
    # singles-led artist surfaces only their albums. Build a profile that keeps
    # them and pin the named artists to it. Not enabled globally: on an
    # album-oriented artist it pulls dozens of single releases that just
    # duplicate album tracks.
    profiles=$(curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/metadataprofile) || exit 0
    singles_id=$(printf '%s' "$profiles" | jq -r '(map(select(.name=="Singles and Albums"))[0].id) // empty')

    if [ -z "$singles_id" ]; then
      singles_id=$(printf '%s' "$profiles" \
        | jq 'map(select(.name=="Standard"))[0] | del(.id) | .name="Singles and Albums"
              | .primaryAlbumTypes |= map(if (.albumType.name=="Single" or .albumType.name=="EP") then .allowed=true else . end)' \
        | curl -sf -X POST -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" -d @- \
            http://localhost:8686/api/v1/metadataprofile | jq -r '.id // empty')
      [ -n "$singles_id" ] && echo "reconcile: created 'Singles and Albums' metadata profile"
    fi

    # Every profile cloned from Standard denies the secondary type Soundtrack,
    # so a film credit stays invisible even on an artist pinned to the singles
    # profile above (Diplo & Oliver Tree's ULTRAMAN, from Ultraman: Rising).
    # Allowing it on that profile instead would refresh all 130-odd artists
    # sharing it, and the ones still carrying monitorNewItems=all would monitor
    # whatever the refresh turned up.
    soundtracks_id=$(printf '%s' "$profiles" | jq -r '(map(select(.name=="Singles, Albums and Soundtracks"))[0].id) // empty')

    if [ -z "$soundtracks_id" ] && [ -n "$singles_id" ]; then
      soundtracks_id=$(printf '%s' "$profiles" \
        | jq --argjson s "$singles_id" 'map(select(.id==$s))[0] | del(.id)
              | .name="Singles, Albums and Soundtracks"
              | .secondaryAlbumTypes |= map(if .albumType.name=="Soundtrack" then .allowed=true else . end)' \
        | curl -sf -X POST -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" -d @- \
            http://localhost:8686/api/v1/metadataprofile | jq -r '.id // empty')
      [ -n "$soundtracks_id" ] && echo "reconcile: created 'Singles, Albums and Soundtracks' metadata profile"
    fi

    artists=""
    pin_artists() {
      pid=$1 label=$2
      shift 2
      [ -n "$pid" ] || return 0
      if [ -z "$artists" ]; then
        artists=$(curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/artist) || return 0
      fi
      for want in "$@"; do
        aid=$(printf '%s' "$artists" | jq -r --arg n "$want" '(map(select(.artistName==$n))[0].id) // empty')
        cur=$(printf '%s' "$artists" | jq -r --arg n "$want" '(map(select(.artistName==$n))[0].metadataProfileId) // empty')
        [ -n "$aid" ] || continue
        [ "$cur" = "$pid" ] && continue

        printf '%s' "$artists" \
          | jq --arg n "$want" --argjson p "$pid" 'map(select(.artistName==$n))[0] | .metadataProfileId=$p' \
          | curl -sf -X PUT -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" -d @- \
              "http://localhost:8686/api/v1/artist/$aid" >/dev/null || continue

        # The profile change alone does not surface the newly allowed releases;
        # Lidarr only re-reads them on a refresh.
        curl -sf -X POST -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" \
          -d "{\"name\":\"RefreshArtist\",\"artistId\":$aid}" \
          http://localhost:8686/api/v1/command >/dev/null
        echo "reconcile: pinned $want to '$label'"
      done
      return 0
    }

    pin_artists "$singles_id" "Singles and Albums" ${lib.escapeShellArgs cfg.singlesArtists}
    pin_artists "$soundtracks_id" "Singles, Albums and Soundtracks" ${lib.escapeShellArgs cfg.soundtrackArtists}

    # The Kodi consumer only writes the artist poster while reacting to a cover
    # download, so an artist whose covers Lidarr already cached never gets one
    # and Navidrome falls back to the grey placeholder. Pulling the poster from
    # Lidarr's own cache is what makes this reproducible on a rebuilt stack.
    # artist.jpg rather than folder.jpg: that is what ArtistArtPriority looks
    # for first, with no Navidrome config change needed.
    curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/artist \
      | jq -r '.[] | select(.images | any(.coverType == "poster")) | "\(.id)\t\(.path)"' \
      | while IFS="$(printf '\t')" read -r aid apath; do
          dir="${cfg.libraryDir}/''${apath#/music/}"
          [ -d "$dir" ] || continue
          [ -e "$dir/artist.jpg" ] && continue
          curl -sf -o "$dir/artist.jpg" -H "X-Api-Key: $LIDARR_KEY" \
            "http://localhost:8686/api/v1/mediacover/artist/$aid/poster.jpg" \
            && echo "reconcile: wrote artist.jpg for $apath"
        done

    # Navidrome: transcoding profile ids are generated per install, so match the
    # profile by name rather than hardcoding one. Applied unconditionally, which
    # means playerProfiles below is authoritative: a profile changed by hand in
    # the web UI is reverted within ten minutes.
    ${lib.concatMapStringsSep "\n" (p: ''
      docker exec navidrome sqlite3 /data/navidrome.db "
        update player
        set transcoding_id = ${
          if p.profile == null then
            sqlEmpty
          else
            "coalesce((select id from transcoding where name = '${p.profile}'), ${sqlEmpty})"
        },
            max_bit_rate = ${toString p.bitrate}
        where name like '${p.match}';" 2>/dev/null
    '') cfg.playerProfiles}

    # A playlist imported from an .m3u carries sync = 1, and Navidrome then
    # rebuilds it from the file on every scan, so a track added in the app
    # disappears at the next one. Clearing the flag hands the playlist to the
    # app for good; the matcher already skips these names, so the file it
    # leaves behind is only a starting point.
    ${lib.optionalString (cfg.frozenPlaylists != [ ]) ''
      docker exec navidrome sqlite3 /data/navidrome.db "
        update playlist set sync = 0
        where sync = 1 and name in (${
          lib.concatMapStringsSep ", " (p: "'${lib.replaceStrings [ "'" ] [ "''" ] p}'") cfg.frozenPlaylists
        });" 2>/dev/null
    ''}

    # slskd only indexes shares at startup or on demand, so a freshly downloaded
    # album is not offered back to the network until something asks for a
    # rescan. Left alone the share count stays at whatever it was on boot, the
    # account keeps looking like a leech, and Soulseek peers reject transfers,
    # which fails whole albums, since Soularr needs every track from one peer.
    if [ -n "''${SLSKD_KEY:-}" ]; then
      shared=$(curl -sf -H "X-API-Key: $SLSKD_KEY" http://localhost:5030/api/v0/application \
        | jq -r '.shares.files // 0')
      ondisk=$(find "${cfg.downloadDir}" -type f \( -name '*.flac' -o -name '*.mp3' \) 2>/dev/null | wc -l | tr -d ' ')
      if [ "''${ondisk:-0}" -gt "''${shared:-0}" ]; then
        curl -sf -X PUT -H "X-API-Key: $SLSKD_KEY" http://localhost:5030/api/v0/shares >/dev/null \
          && echo "reconcile: rescanning slskd shares ($shared indexed, $ondisk on disk)"
      fi
    fi

    # Kopuz registers a fresh player row on every reconnect rather than reusing
    # one, so the table grows without bound (423 rows inside a morning). Keep
    # the most recent row per client name and drop the rest.
    docker exec navidrome sqlite3 /data/navidrome.db "
      delete from player where id not in (
        select id from player p1
        where last_seen = (select max(last_seen) from player p2 where p2.name = p1.name)
      );" 2>/dev/null

    # AudioMuse schedules analysis and clustering in its own postgres, not in a
    # config file, so a toggle made in its web UI outlives every rebuild.
    # Clustering is what writes the `*_automatic` playlists: with it off,
    # analysis keeps running nightly and produces nothing anyone can see, which
    # is the state the stack sat in from 2026-08-09. Credentials come from the
    # seeded env file, so nothing lands in the store.
    if [ -f "${stackDir}/audiomuse/audiomuse.env" ]; then
      # shellcheck disable=SC1090
      . "${stackDir}/audiomuse/audiomuse.env"
      docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" audiomuse-postgres \
        psql -qtAX -U "$POSTGRES_USER" -d audiomusedb \
        -c "update cron set enabled = true where task_type = 'clustering' and not enabled;" \
        2>/dev/null | grep -q "UPDATE 1" \
        && echo "reconcile: re-enabled AudioMuse clustering"
    fi

    # Navidrome 0.63 gave every plugin an `enabled` flag and defaults a newly
    # discovered one to off, so the launcher re-staging .ndp files is no longer
    # enough to have them run. Every file staged above is one this config asked
    # for, which makes "discovered but off" drift rather than a choice: with
    # audiomuseai off, ND_AGENTS falls straight through to lastfm and a
    # similar-songs lookup goes from 30ms to tens of seconds, which is invisible
    # from the server side because the fallback still answers. Plugin ids match
    # the staged filenames. The registry is only read at startup, so restart
    # once, and only if something actually changed.
    pluginsEnabled=0
    for ndp in "${stackDir}/navidrome-plugins"/*.ndp; do
      [ -e "$ndp" ] || continue
      id=$(basename "$ndp" .ndp)
      docker exec navidrome navidrome plugin list -f json -n 2>/dev/null \
        | jq -e --arg id "$id" \
            'map(select(.id == $id and .enabled == false)) | length > 0' >/dev/null \
        || continue
      # A plugin that touches libraries refuses to enable until it is told
      # which ones; granting all of them matches the single-library setup.
      docker exec navidrome navidrome plugin edit "$id" --all-libraries --write-access \
        >/dev/null 2>&1 || true
      docker exec navidrome navidrome plugin enable "$id" >/dev/null 2>&1 \
        && pluginsEnabled=1 \
        && echo "reconcile: enabled navidrome plugin $id"
    done
    if [ "$pluginsEnabled" = 1 ]; then
      docker restart navidrome >/dev/null 2>&1 \
        && echo "reconcile: restarted navidrome to load newly enabled plugins"
    fi
  '';

  # Navidrome only counts what it played itself, which was 175 plays over 80 of
  # 5063 tracks while ListenBrainz held 21k listens from the Spotify years.
  # Everything that ranks by play count reads that 80-track pool: Navidrome's
  # own most-played, and NaviBeat, whose mixes fall back to "your most played"
  # until it has logged `minEventsForAffinity` plays of its own. That is why the
  # morning, afternoon, evening and night mixes came out with an identical 30
  # tracks. This pulls the ListenBrainz history back down into Navidrome's
  # annotations so the ranking has the whole history behind it.
  #
  # Keyed by listen identity (recording MBID, else artist and title) rather than
  # by track id, and rematched in full every run, so the ~two thirds of listens
  # that name music not yet on disk land the moment Soularr imports them. Title
  # matching reuses the progressive suffix stripping the Spotify playlist
  # matcher needs for the same reason: a Soulseek rip rarely carries the exact
  # title a streaming service showed.
  listens = pkgs.writeScript "music-stack-listens" ''
    #!${pkgs.python3}/bin/python3
    import http.client
    import json
    import re
    import subprocess
    import sys
    import time
    import unicodedata
    import urllib.error
    import urllib.request

    STATE = "${stackDir}/.listens-state.json"
    MS_CONF = "${stackDir}/multi-scrobbler/config.json"
    API = "https://api.listenbrainz.org/1"
    DRY = "--dry-run" in sys.argv

    NOISE = re.compile(
        r"\s*[-(\[]\s*(slowed|super slowed|sped up.*|hardstyle|hardtekk|edit|"
        r"remix|vip|extended mix|radio edit|club mix|bassline club mix|"
        r"slowed & reverb|slowed and reverb|slowed -pitch|the dark triad|"
        r"viral version.*|feat\..*|ft\..*|with .*)\s*[)\]]?\s*$",
        re.I)


    def listenbrainz_user():
        """The account multi-scrobbler forwards to. It owns the username, so
        nix does not carry a second copy of it."""
        try:
            with open(MS_CONF) as fh:
                conf = json.load(fh)
        except (OSError, ValueError):
            return None
        for client in conf.get("clients", []):
            if client.get("type") != "listenbrainz":
                continue
            name = client.get("data", {}).get("username")
            return name if name and name != "CHANGEME" else None
        return None


    def norm(s):
        s = unicodedata.normalize("NFKD", s or "")
        s = "".join(c for c in s if not unicodedata.combining(c))
        s = s.replace("’", "'").replace("&", "and")
        return re.sub(r"[^a-z0-9]", "", s.lower())


    def variants(title):
        """Progressively stripped forms of a title, most specific first."""
        out, t = [], title
        for _ in range(4):
            out.append(t)
            stripped = NOISE.sub("", t).strip(" -–")
            if stripped == t or not stripped:
                break
            t = stripped
        out.append(re.sub(r"\s*\(.*?\)\s*", " ", title).strip())
        return [v for v in dict.fromkeys(out) if v]


    def artist_forms(artist):
        """An artist credit and each collaborator named in it."""
        out = [artist]
        out += re.split(r"\s*(?:,|&|feat\.|ft\.|with|•|/|\bx\b)\s*", artist)
        return [a for a in dict.fromkeys(out) if a.strip()]


    def sql(query):
        # Same rule as the playlist matcher: sqlite3 runs inside the container,
        # because reading navidrome.db from macOS across virtiofs destroys it.
        r = subprocess.run(["docker", "exec", "navidrome", "sqlite3",
                            "-separator", "\x1f", "/data/navidrome.db", query],
                           capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(0)
        return [l.split("\x1f") for l in r.stdout.splitlines() if l]


    def fetch(user, since):
        """Every listen newer than `since`, walking back a page at a time."""
        out, max_ts = [], None
        while True:
            url = "%s/user/%s/listens?count=500" % (API, user)
            if max_ts:
                url += "&max_ts=%d" % max_ts
            req = urllib.request.Request(url, headers={"User-Agent": "music-stack/1"})
            # A first run walks the whole history and listenbrainz.org stalls on
            # some of those pages. Retry rather than abandon the run: the high
            # water mark only moves on success, so giving up here would make the
            # next run start over from the same page.
            page = None
            for attempt in range(5):
                try:
                    page = json.load(urllib.request.urlopen(req, timeout=60))
                    break
                except urllib.error.HTTPError as err:
                    if err.code not in (429, 500, 502, 503, 504):
                        raise
                    time.sleep(5 * (attempt + 1))
                except (OSError, http.client.HTTPException):
                    time.sleep(5 * (attempt + 1))
            if page is None:
                break
            page = page["payload"]["listens"]
            if not page:
                break
            oldest = min(l["listened_at"] for l in page)
            out += [l for l in page if l["listened_at"] > since]
            if oldest <= since:
                break
            max_ts = oldest - 1
        return out


    def listen_key(listen):
        meta = listen["track_metadata"]
        mbid = (meta.get("mbid_mapping") or {}).get("recording_mbid") \
            or (meta.get("additional_info") or {}).get("recording_mbid")
        title, artist = meta["track_name"], meta["artist_name"]
        key = "m:" + mbid.lower() if mbid else \
            "t:%s\x1f%s" % (norm(title), norm(artist))
        return key, [0, 0, (mbid or "").lower(), title, artist]


    user = listenbrainz_user()
    if not user:
        sys.exit(0)

    try:
        with open(STATE) as fh:
            state = json.load(fh)
    except (OSError, ValueError):
        state = {"last_ts": 0, "plays": {}}

    listens = fetch(user, state["last_ts"])
    for listen in listens:
        key, blank = listen_key(listen)
        entry = state["plays"].get(key) or blank
        entry[0] += 1
        entry[1] = max(entry[1], listen["listened_at"])
        state["plays"][key] = entry
    if listens:
        state["last_ts"] = max(l["listened_at"] for l in listens)
        with open(STATE, "w") as fh:
            json.dump(state, fh)

    by_mbid, by_pair = {}, {}
    for mid, title, artist, album_artist, mbid in sql(
            "select id, title, artist, album_artist, coalesce(mbz_recording_id,${sqlEmpty}) "
            "from media_file where missing = 0;"):
        if mbid:
            by_mbid.setdefault(mbid.lower(), mid)
        for v in variants(title):
            for a in artist_forms(artist) + artist_forms(album_artist):
                by_pair.setdefault((norm(v), norm(a)), mid)

    counts, dates, matched, unmatched = {}, {}, 0, {}
    for count, ts, mbid, title, artist in state["plays"].values():
        mid = by_mbid.get(mbid)
        if not mid:
            for v in variants(title):
                for a in artist_forms(artist):
                    mid = by_pair.get((norm(v), norm(a)))
                    if mid:
                        break
                if mid:
                    break
        if not mid:
            unmatched[artist + " - " + title] = count
            continue
        matched += count
        counts[mid] = counts.get(mid, 0) + count
        dates[mid] = max(dates.get(mid, 0), ts)

    total = sum(e[0] for e in state["plays"].values())
    print("listens: %d new, %d known, %d matched (%.0f%%) onto %d library tracks"
          % (len(listens), total, matched, 100.0 * matched / max(total, 1), len(counts)))
    if DRY:
        for k, v in sorted(unmatched.items(), key=lambda x: -x[1])[:15]:
            print("  unmatched %4dx %s" % (v, k))
        sys.exit(0)
    if not counts:
        sys.exit(0)

    owner = sql("select id from user where user_name = '%s';"
                % user.replace("'", "${sqlEmpty}")) or sql("select id from user;")
    if len(owner) != 1:
        sys.exit(0)
    uid = owner[0][0]


    def stamp(ts):
        return time.strftime("%Y-%m-%d %H:%M:%S+00:00", time.gmtime(ts))


    # max() rather than a running total, so this is idempotent: the counts are
    # recomputed from the whole history every run, and a play Navidrome recorded
    # that ListenBrainz never saw is never lowered.
    UPSERT = """
    insert into annotation (user_id, item_id, item_type, play_count, play_date)
    %s
    on conflict (user_id, item_id, item_type) do update set
        play_count = max(annotation.play_count, excluded.play_count),
        play_date  = max(coalesce(annotation.play_date, ${sqlEmpty}), excluded.play_date);
    """

    values = ",".join(
        "('%s','%s','media_file',%d,'%s')" % (uid, mid, n, stamp(dates[mid]))
        for mid, n in counts.items())

    # Album and artist counts roll up from the annotation table rather than from
    # `counts`, so plays Navidrome recorded on its own are included too.
    script = UPSERT % ("values " + values) + UPSERT % """
    select a.user_id, mf.album_id, 'album', sum(a.play_count), max(a.play_date)
    from annotation a join media_file mf on mf.id = a.item_id
    where a.item_type = 'media_file' and a.play_count > 0 and mf.album_id <> ${sqlEmpty}
    group by a.user_id, mf.album_id
    """ + UPSERT % """
    select a.user_id, mfa.artist_id, 'artist', sum(a.play_count), max(a.play_date)
    from annotation a
    join media_file_artists mfa on mfa.media_file_id = a.item_id and mfa.role = 'artist'
    where a.item_type = 'media_file' and a.play_count > 0
    group by a.user_id, mfa.artist_id
    """

    r = subprocess.run(["docker", "exec", "-i", "navidrome", "sqlite3",
                        "/data/navidrome.db"],
                       input=script, capture_output=True, text=True)
    if r.returncode != 0:
        print("annotation write failed: %s" % r.stderr.strip(), file=sys.stderr)
        sys.exit(1)
    print("play counts written for %d tracks (%d plays)" % (len(counts), matched))
  '';

  # The Spotify export is a one-off dump, but the library it gets matched
  # against grows for weeks while Soularr works through Lidarr's wanted list, so
  # a playlist is only ever as complete as the last run. Re-matching on a timer
  # means a track added to the library shows up in its playlist within the hour.
  # `playlists.json` is hand-picked runtime data (which exported playlists to
  # keep, in Spotify's title/artists shape), not something nix writes.
  playlists = pkgs.writeScript "music-stack-playlists" ''
    #!${pkgs.python3}/bin/python3
    import json
    import os
    import re
    import subprocess
    import sys
    import unicodedata

    DATA = "${stackDir}/playlists.json"
    LIB = "${cfg.libraryDir}"
    # Playlists that have outgrown the export. The matcher can only ever
    # rebuild them from the Spotify snapshot, so once one is being curated in
    # the app, rewriting its .m3u would throw away every track added since.
    FROZEN = ${builtins.toJSON cfg.frozenPlaylists}

    # Suffixes Spotify puts on a title that the released file usually lacks.
    NOISE = re.compile(
        r"\s*[-(\[]\s*(slowed|super slowed|sped up.*|hardstyle|hardtekk|edit|"
        r"remix|vip|extended mix|radio edit|club mix|bassline club mix|"
        r"slowed & reverb|slowed and reverb|slowed -pitch|the dark triad|"
        r"viral version.*|feat\..*|mit .*|with .*)\s*[)\]]?\s*$",
        re.I)


    def norm(s):
        s = unicodedata.normalize("NFKD", s)
        s = "".join(c for c in s if not unicodedata.combining(c))
        s = s.replace("’", "'").replace("&", "and")
        return re.sub(r"[^a-z0-9]", "", s.lower())


    def variants(title):
        """Progressively stripped forms of a title, most specific first."""
        out, t = [], title
        for _ in range(4):
            out.append(t)
            stripped = NOISE.sub("", t).strip(" -–")
            if stripped == t or not stripped:
                break
            t = stripped
        # Drop a trailing " x Something" mashup half, and any parenthetical.
        out.append(re.sub(r"\s*\(.*?\)\s*", " ", title).strip())
        return [v for v in dict.fromkeys(out) if v]


    def sql(q):
        # sqlite3 runs inside the container on purpose: reading navidrome.db from
        # macOS across OrbStack's virtiofs boundary destroys it (see docs/music.md).
        r = subprocess.run(["docker", "exec", "navidrome", "sqlite3",
                            "-separator", "\x1f", "/data/navidrome.db", q],
                           capture_output=True, text=True)
        if r.returncode != 0:
            # Stack down or still starting. Leave the playlists alone and retry
            # next run rather than rewriting them from an empty library.
            sys.exit(0)
        return [l.split("\x1f") for l in r.stdout.splitlines() if l]


    if not os.path.isdir(LIB) or not os.path.exists(DATA):
        sys.exit(0)

    rows = sql("select title, artist, album_artist, path from media_file;")
    by_title = {}
    for title, artist, aartist, path in rows:
        by_title.setdefault(norm(title), []).append((artist, aartist, path))

    playlists = json.load(open(DATA))
    report = {}
    for name, tracks in playlists.items():
        if name in FROZEN:
            continue
        lines, hits, misses = ["#EXTM3U", f"#PLAYLIST:{name}"], 0, []
        for t in tracks:
            want_artists = {norm(a) for a in t["artists"]}
            found = None
            for v in variants(t["title"]):
                for artist, aartist, path in by_title.get(norm(v), []):
                    if norm(artist) in want_artists or norm(aartist) in want_artists \
                            or any(w and w in norm(artist) for w in want_artists):
                        found = path
                        break
                if found:
                    break
            if found:
                # Navidrome resolves relative entries against the playlist's folder.
                lines.append(found.replace("/music/", "", 1))
                hits += 1
            else:
                misses.append(f'{t["artists"][0]} - {t["title"]}')
        report[name] = (hits, len(tracks), misses)

        fn = f"{LIB}/{name}.m3u"
        body = "\n".join(lines) + "\n"
        # Navidrome reimports a playlist whenever its mtime moves, so an
        # unchanged match must not touch the file.
        try:
            unchanged = open(fn).read() == body
        except OSError:
            unchanged = False
        if not unchanged:
            with open(fn, "w") as f:
                f.write(body)
            print(f"playlists: {name} {hits}/{len(tracks)} matched")

    if "--misses" in sys.argv:
        for name, (h, n, misses) in report.items():
            print(f"\n{name} missing ({len(misses)}):")
            for m in misses:
                print("  ", m)
  '';

  # Nothing between Soulseek and the player checks that a file holds the audio
  # its tags promise. A peer sharing a 30-second preview under the full track's
  # name gets imported as the real thing: Lidarr trusts the tags, Navidrome
  # trusts the header, and the first sign of trouble is the audio stopping
  # mid-song. Decoding is the only test that catches it, so this decodes
  # everything, keyed by size and mtime so a run only pays for what was
  # imported since the last one. It reports and never deletes: re-requesting
  # automatically would just pull the same bad copy from the same peer.
  verify = pkgs.writeScript "music-stack-verify" ''
    #!${pkgs.python3}/bin/python3
    import json
    import os
    import re
    import subprocess
    from concurrent.futures import ThreadPoolExecutor

    LIB = "${cfg.libraryDir}"
    STATE = "${stackDir}/.verify-state.json"
    REPORT = "${stackDir}/broken-tracks.txt"
    FFPROBE = "${pkgs.ffmpeg-headless}/bin/ffprobe"
    FFMPEG = "${pkgs.ffmpeg-headless}/bin/ffmpeg"
    EXTS = (".flac", ".mp3", ".m4a", ".ogg", ".opus")

    TIME = re.compile(rb"time=(\d+):(\d+):([\d.]+)")
    # Cover art decodes as its own stream, and a JPEG stored under a PNG
    # signature is a tag defect rather than a damaged track.
    IMAGE = re.compile(rb"^\[(png|mjpeg|jpeg|image)")

    if not os.path.isdir(LIB):
        raise SystemExit(0)


    def fingerprint(path):
        st = os.stat(path)
        return "{}:{}".format(st.st_size, int(st.st_mtime))


    def verdict(path):
        probe = subprocess.run(
            [FFPROBE, "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", path], capture_output=True, timeout=300)
        try:
            claimed = float(probe.stdout.strip())
        except ValueError:
            return "unreadable header"

        run = subprocess.run(
            [FFMPEG, "-v", "error", "-stats", "-i", path, "-map", "0:a",
             "-f", "null", "-"], capture_output=True, timeout=900)
        errors = [ln for ln in run.stderr.replace(b"\r", b"\n").split(b"\n")
                  if ln.strip()
                  and not ln.startswith((b"size=", b"frame="))
                  and not IMAGE.match(ln)]
        stamps = TIME.findall(run.stderr)
        decoded = (int(stamps[-1][0]) * 3600 + int(stamps[-1][1]) * 60
                   + float(stamps[-1][2])) if stamps else 0.0

        # A truncated rip keeps the full length in its header, so the gap
        # between that and where the audio actually ran out is the only tell.
        if abs(claimed - decoded) > 1.0:
            return "audio ends at {:.0f}s of {:.0f}s".format(decoded, claimed)
        if errors:
            return "{} decode errors".format(len(errors))
        return None


    try:
        with open(STATE) as fh:
            state = json.load(fh)
    except (OSError, ValueError):
        state = {}

    files = [os.path.join(d, n) for d, _, ns in os.walk(LIB) for n in ns
             if n.lower().endswith(EXTS)]
    for gone in set(state) - set(files):
        del state[gone]


    def check(path):
        seen = fingerprint(path)
        known = state.get(path)
        if known and known[0] == seen:
            return path, known
        try:
            return path, [seen, verdict(path)]
        except Exception as err:
            return path, [seen, "check failed: {}".format(err)]


    # Four at a time: the library lives on the SD card, which Navidrome is
    # reading from at the same time.
    with ThreadPoolExecutor(max_workers=4) as pool:
        for path, entry in pool.map(check, files):
            state[path] = entry

    with open(STATE, "w") as fh:
        json.dump(state, fh)

    broken = sorted(p for p, entry in state.items() if entry[1])
    with open(REPORT, "w") as fh:
        for path in broken:
            fh.write("{}\t{}\n".format(state[path][1], path))
    print("verify: {} of {} tracks broken, listed in {}".format(
        len(broken), len(files), REPORT))
  '';

  # Lidarr adds an artist by copying their whole MusicBrainz discography onto
  # the wanted list, which is how a library of one liked song becomes 206 GB of
  # music nobody has played. This drives the wanted list from the listening
  # history and the kept playlists instead: an album with no files and nothing
  # asking for it is unmonitored, so Soularr stops searching for it.
  #
  # The second half is the other direction. An artist whose every track has sat
  # unplayed for UNPLAYED_DAYS is moved to a dated folder under .trash, kept
  # there for TRASH_DAYS, and only then deleted, so a wrong call costs a
  # `music-gc --restore` rather than a re-download.
  gc = pkgs.writeScript "music-stack-gc" ''
    #!${pkgs.python3}/bin/python3
    import json
    import os
    import re
    import shutil
    import subprocess
    import sys
    import time
    import unicodedata
    import urllib.error
    import urllib.request

    LIB = "${cfg.libraryDir}"
    DOWNLOADS = "${cfg.downloadDir}"
    TRASH = "${trashDir}"
    STATE = "${stackDir}/.gc-state.json"
    LISTENS_STATE = "${stackDir}/.listens-state.json"
    PLAYLIST_DATA = "${stackDir}/playlists.json"
    KEYS = "${stackDir}/.api-keys"
    LIDARR = "http://localhost:8686/api/v1"
    SLSKD = "http://localhost:5030/api/v0"
    PINNED_PLAYLISTS = ${builtins.toJSON cfg.frozenPlaylists}

    # An artist has to have been around this long before their wanted list is
    # trimmed, so a discovery from last night finishes downloading first.
    GRACE_DAYS = 14
    # ... and their files unplayed this long before they are quarantined.
    UNPLAYED_DAYS = 60
    # Quarantined files are deleted for real this long after the move.
    TRASH_DAYS = 60
    # One run only ever quarantines this many artists, so a rule that goes wrong
    # stays small enough to walk back by hand.
    MAX_ARTISTS = 25

    DRY = "--dry-run" in sys.argv

    # Suffixes a streaming service puts on a title that the released file lacks.
    # Same set the playlist matcher and the listens importer strip.
    NOISE = re.compile(
        r"\s*[-(\[]\s*(slowed|super slowed|sped up.*|hardstyle|hardtekk|edit|"
        r"remix|vip|extended mix|radio edit|club mix|bassline club mix|"
        r"slowed & reverb|slowed and reverb|slowed -pitch|the dark triad|"
        r"viral version.*|feat\..*|ft\..*|mit .*|with .*)\s*[)\]]?\s*$",
        re.I)


    def norm(s):
        s = unicodedata.normalize("NFKD", s or "")
        s = "".join(c for c in s if not unicodedata.combining(c))
        s = s.replace("’", "'").replace("&", "and")
        return re.sub(r"[^a-z0-9]", "", s.lower())


    def variants(title):
        """Progressively stripped forms of a title, most specific first."""
        out, t = [], title
        for _ in range(4):
            out.append(t)
            stripped = NOISE.sub("", t).strip(" -–")
            if stripped == t or not stripped:
                break
            t = stripped
        out.append(re.sub(r"\s*\(.*?\)\s*", " ", title).strip())
        return [v for v in dict.fromkeys(out) if v]


    def sql(query):
        # sqlite3 runs inside the container on purpose: reading navidrome.db from
        # macOS across OrbStack's virtiofs boundary destroys it (see docs/music.md).
        r = subprocess.run(["docker", "exec", "navidrome", "sqlite3",
                            "-separator", "\x1f", "/data/navidrome.db", query],
                           capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(0)
        return [l.split("\x1f") for l in r.stdout.splitlines() if l]


    def key(name):
        try:
            with open(KEYS) as fh:
                m = re.search(name + r"=([a-f0-9]+)", fh.read())
        except OSError:
            return None
        return m.group(1) if m else None


    def api(base, path, hdr, method="GET", body=None):
        head = dict(hdr)
        if body is not None:
            head["Content-Type"] = "application/json"
        req = urllib.request.Request(
            base + path, method=method, headers=head,
            data=json.dumps(body).encode() if body is not None else None)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
            return json.loads(raw) if raw else None
        except (urllib.error.URLError, OSError, ValueError):
            return None


    def age_days(stamp):
        """Days since a timestamp. Navidrome writes nine fractional digits, which
        %z will not parse, and day granularity is all this needs."""
        m = re.match(r"(\d{4})-(\d{2})-(\d{2})", stamp or "")
        if not m:
            return None
        when = time.mktime((int(m.group(1)), int(m.group(2)), int(m.group(3)),
                            12, 0, 0, 0, 0, -1))
        return (time.time() - when) / 86400.0


    def load_state():
        try:
            with open(STATE) as fh:
                return json.load(fh)
        except (OSError, ValueError):
            return {"quarantined": []}


    def save_state(state):
        if not DRY:
            with open(STATE, "w") as fh:
                json.dump(state, fh, indent=1)


    def prune_empty(path):
        """Walk back up to LIB removing the directories a move emptied."""
        path = os.path.dirname(path)
        while path.startswith(LIB) and path != LIB:
            try:
                os.rmdir(path)
            except OSError:
                return
            path = os.path.dirname(path)


    def restore(name, hdr):
        state = load_state()
        kept, moved = [], 0
        for entry in state["quarantined"]:
            if entry["artist"].lower() != name.lower():
                kept.append(entry)
                continue
            for rel in entry["files"]:
                src = os.path.join(TRASH, entry["batch"], rel)
                if not os.path.exists(src):
                    continue
                dst = os.path.join(LIB, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(src, dst)
                moved += 1
            if entry.get("lidarr_id"):
                artist = api(LIDARR, "/artist/%d" % entry["lidarr_id"], hdr)
                if artist:
                    artist["monitored"] = True
                    api(LIDARR, "/artist/%d" % entry["lidarr_id"], hdr, "PUT", artist)
                    api(LIDARR, "/command", hdr, "POST",
                        {"name": "RefreshArtist", "artistId": entry["lidarr_id"]})
        state["quarantined"] = kept
        save_state(state)
        print("gc: restored %d files for %s" % (moved, name))


    def wants():
        """Every song the history or a kept playlist asks for, as recording MBIDs
        and as (artist, title) pairs. This is what the wanted list is allowed to
        hold: a MusicBrainz discography is a catalogue, not a request."""
        mbids, pairs = set(), set()
        try:
            with open(LISTENS_STATE) as fh:
                plays = json.load(fh).get("plays", {})
        except (OSError, ValueError):
            plays = {}
        for _count, _ts, mbid, title, artist in plays.values():
            if mbid:
                mbids.add(mbid.lower())
            for v in variants(title):
                pairs.add((norm(artist), norm(v)))
        try:
            with open(PLAYLIST_DATA) as fh:
                for tracks in json.load(fh).values():
                    for t in tracks:
                        for artist in t["artists"]:
                            for v in variants(t["title"]):
                                pairs.add((norm(artist), norm(v)))
        except (OSError, ValueError, KeyError):
            pass
        return mbids, pairs


    lidarr_key = key("LIDARR_KEY")
    if not lidarr_key:
        sys.exit(0)
    hdr = {"X-Api-Key": lidarr_key}

    if "--restore" in sys.argv:
        restore(sys.argv[sys.argv.index("--restore") + 1], hdr)
        sys.exit(0)

    if not os.path.isdir(LIB):
        sys.exit(0)

    want_mbids, want_pairs = wants()
    # Play counts and wants are only trustworthy once the ListenBrainz backfill has
    # run. Without it Navidrome knows a few hundred plays and every artist reads as
    # untouched, which would trim and quarantine the whole library.
    if not want_mbids:
        sys.exit(0)

    rows = sql("""
        select mf.album_artist, sum(coalesce(a.play_count, 0)), max(mf.created_at),
               count(*), sum(mf.size)
        from media_file mf
        left join annotation a on a.item_id = mf.id and a.item_type = 'media_file'
        where mf.missing = 0 and mf.album_artist <> ${sqlEmpty}
        group by mf.album_artist;
    """)
    # A scan caught mid-flight reports a library that is mostly missing, and every
    # artist in it would read as unplayed.
    if len(rows) < 50:
        sys.exit(0)
    library = {r[0]: {"plays": int(r[1] or 0), "newest": r[2],
                      "files": int(r[3]), "bytes": int(r[4] or 0)} for r in rows}

    # A track sitting in a playlist is a request, whether or not it has been
    # played yet, so its artist is never swept.
    pinned = {r[0] for r in sql("""
        select distinct mf.album_artist
        from playlist_tracks pt
        join playlist p on p.id = pt.playlist_id
        join media_file mf on mf.id = pt.media_file_id
        where p.sync = 1 or p.name in (%s);
    """ % ",".join("'%s'" % p.replace("'", "${sqlEmpty}") for p in PINNED_PLAYLISTS))}

    artists = api(LIDARR, "/artist", hdr) or []
    keep_tag = next((t["id"] for t in api(LIDARR, "/tag", hdr) or []
                     if t["label"] == "keep"), None)

    trimmed, kept_albums, doomed = 0, 0, []
    for artist in artists:
        name = artist["artistName"]
        lib = library.get(name)
        if keep_tag in (artist.get("tags") or []) or name in pinned:
            continue
        # Age from the newest file, or from the add for an artist still empty.
        age = age_days(lib["newest"]) if lib else age_days(artist.get("added"))
        if age is None or age < GRACE_DAYS:
            continue

        albums = api(LIDARR, "/album?artistId=%d" % artist["id"], hdr) or []
        missing = [a for a in albums if a.get("monitored")
                   and not (a.get("statistics") or {}).get("trackFileCount")]
        cut = 0
        for album in missing:
            tracks = api(LIDARR, "/track?albumId=%d" % album["id"], hdr) or []
            if any((t.get("foreignRecordingId") or "").lower() in want_mbids
                   or (norm(name), norm(t.get("title"))) in want_pairs
                   for t in tracks):
                kept_albums += 1
                continue
            cut += 1
            if not DRY:
                api(LIDARR, "/album/monitor", hdr, "PUT",
                    {"albumIds": [album["id"]], "monitored": False})
        trimmed += cut
        if cut:
            print("gc: %s, %d of %d missing albums unmonitored, nothing asked for them"
                  % (name, cut, len(missing)))

        if lib and lib["plays"] == 0 and age >= UNPLAYED_DAYS:
            doomed.append((name, artist, lib))

    # An artist Lidarr never knew about (Explo downloads, hand-added folders) is
    # swept on play count alone.
    for name, lib in library.items():
        if name in pinned or any(d[0] == name for d in doomed):
            continue
        if any(a["artistName"] == name for a in artists):
            continue
        age = age_days(lib["newest"])
        if lib["plays"] == 0 and age is not None and age >= UNPLAYED_DAYS:
            doomed.append((name, None, lib))

    doomed.sort(key=lambda d: -d[2]["bytes"])
    if len(doomed) > MAX_ARTISTS:
        print("gc: %d artists qualify, taking the %d largest this run"
              % (len(doomed), MAX_ARTISTS))
        doomed = doomed[:MAX_ARTISTS]

    state = load_state()
    batch = time.strftime("%Y-%m-%d")
    freed = 0
    for name, artist, lib in doomed:
        paths = [r[0] for r in sql(
            "select path from media_file where missing = 0 and album_artist = '%s';"
            % name.replace("'", "${sqlEmpty}"))]
        print("gc: quarantining %s, %d files, %.1f GB"
              % (name, len(paths), lib["bytes"] / 1e9))
        freed += lib["bytes"]
        if DRY:
            continue

        moved = []
        for path in paths:
            rel = path.replace("/music/", "", 1)
            src = os.path.join(LIB, rel)
            if not os.path.exists(src):
                continue
            dst = os.path.join(TRASH, batch, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(src, dst)
            prune_empty(src)
            moved.append(rel)

        # Lidarr keeps the artist, unmonitored and empty, so a restore is a
        # re-monitor rather than a re-add. music-forget-artists.sh removes it.
        if artist:
            albums = api(LIDARR, "/album?artistId=%d" % artist["id"], hdr) or []
            if albums:
                api(LIDARR, "/album/monitor", hdr, "PUT",
                    {"albumIds": [a["id"] for a in albums], "monitored": False})
            artist["monitored"] = False
            api(LIDARR, "/artist/%d" % artist["id"], hdr, "PUT", artist)

        # Soularr's downloads are a second copy, shared back to Soulseek, and
        # Lidarr's own delete never touches them. Same prefix match as
        # music-forget-artists.sh.
        for base in (DOWNLOADS, os.path.join(DOWNLOADS, "failed_imports")):
            for entry in os.listdir(base) if os.path.isdir(base) else []:
                if entry.lower().startswith(name.lower() + " - "):
                    shutil.rmtree(os.path.join(base, entry), ignore_errors=True)

        state["quarantined"].append({
            "artist": name, "batch": batch, "bytes": lib["bytes"],
            "lidarr_id": artist["id"] if artist else None, "files": moved,
        })
    save_state(state)

    # Anything that survived the trash window unmissed is gone for real.
    purged = 0
    if os.path.isdir(TRASH) and not DRY:
        for entry in sorted(os.listdir(TRASH)):
            old = age_days(entry)
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", entry) or old is None \
                    or old < TRASH_DAYS:
                continue
            shutil.rmtree(os.path.join(TRASH, entry), ignore_errors=True)
            purged += 1
        if purged:
            state = load_state()
            state["quarantined"] = [q for q in state["quarantined"]
                                    if os.path.isdir(os.path.join(TRASH, q["batch"]))]
            save_state(state)

    if doomed and not DRY:
        slskd_key = key("SLSKD_KEY")
        if slskd_key:
            # slskd advertises downloads/ to peers and only rescans on demand.
            api(SLSKD, "/shares", {"X-API-Key": slskd_key}, "PUT", {})

    print("gc: %d albums unmonitored, %d kept as requested, %d artists quarantined "
          "(%.1f GB), %d trash batches purged"
          % (trimmed, kept_albums, len(doomed), freed / 1e9, purged))
  '';

  launcher = pkgs.writeShellScript "music-stack-launch" ''
    set -euo pipefail

    # Without the SD card Navidrome would scan an empty folder and mark the
    # whole library deleted, so refuse to start and let launchd retry on
    # ThrottleInterval until the card is back.
    if [ ! -d "${cfg.libraryDir}" ]; then
      echo "music library ${cfg.libraryDir} not mounted, waiting" >&2
      exit 1
    fi

    # OrbStack starts as a login item, so on a fresh boot this agent can win
    # the race. Exit non-zero and retry rather than leaving a half-built stack.
    if ! docker info >/dev/null 2>&1; then
      echo "docker daemon not up yet, waiting" >&2
      exit 1
    fi

    mkdir -p "${stackDir}"/{navidrome-backup,navidrome-plugins,lidarr,slskd,soularr,multi-scrobbler,audiomuse,explo/config} "${incompleteDir}"
    # Explo downloads into a library subfolder so Navidrome picks its tracks up
    # on the ordinary scan; created here because the compose bind mount would
    # otherwise appear root-owned.
    mkdir -p "${cfg.libraryDir}/explo"

    # Re-staged every start so a nixpkgs plugin bump actually lands. Navidrome
    # unpacks each .ndp next to itself, so the folder must be writable (a
    # store symlink is not enough).
    rm -rf "${stackDir}/navidrome-plugins"/*
    ${lib.concatMapStringsSep "\n" (p: ''
      install -m 0644 ${p}/share/*.ndp "${stackDir}/navidrome-plugins/"
    '') pluginPkgs}

    # Lidarr and slskd both accept a pre-seeded API key, so generating both
    # here is what lets Soularr be wired up automatically instead of the usual
    # copy-a-key-out-of-two-web-UIs step. Generated once and kept, because the
    # web UIs write the same values back into their own configs.
    keyFile="${stackDir}/.api-keys"
    if [ ! -f "$keyFile" ]; then
      umask 077
      {
        echo "SLSKD_KEY=$(${pkgs.openssl}/bin/openssl rand -hex 16)"
        echo "LIDARR_KEY=$(${pkgs.openssl}/bin/openssl rand -hex 16)"
      } > "$keyFile"
    fi
    # shellcheck disable=SC1090
    . "$keyFile"

    # Appended rather than folded into the block above, so a stack seeded before
    # multi-scrobbler existed gets a key instead of an empty one.
    if [ -z "''${MSLZ_KEY:-}" ]; then
      echo "MSLZ_KEY=$(${pkgs.openssl}/bin/openssl rand -hex 16)" >> "$keyFile"
      # shellcheck disable=SC1090
      . "$keyFile"
    fi
    if [ -z "''${AUDIOMUSE_PG:-}" ]; then
      echo "AUDIOMUSE_PG=$(${pkgs.openssl}/bin/openssl rand -hex 16)" >> "$keyFile"
      # shellcheck disable=SC1090
      . "$keyFile"
    fi

    seed() {
      [ -f "$2" ] && return 0
      sed -e "s|@SLSKD_KEY@|$SLSKD_KEY|g" -e "s|@LIDARR_KEY@|$LIDARR_KEY|g" \
          -e "s|@MSLZ_KEY@|$MSLZ_KEY|g" -e "s|@AUDIOMUSE_PG@|$AUDIOMUSE_PG|g" "$1" > "$2"
      chmod 600 "$2"
    }

    seed ${lidarrSeed} "${stackDir}/lidarr/config.xml"
    seed ${slskdSeed} "${stackDir}/slskd/slskd.yml"
    seed ${soularrSeed} "${stackDir}/soularr/config.ini"
    seed ${msSeed} "${stackDir}/multi-scrobbler/config.json"
    seed ${audiomuseSeed} "${stackDir}/audiomuse/audiomuse.env"
    seed ${exploSeed} "${stackDir}/explo/.env"

    exec docker compose -f ${compose} -p music-stack up --remove-orphans
  '';
in
{
  options.kyan.music = {
    enable = lib.mkEnableOption "self-hosted music stack (Navidrome, Lidarr, slskd, Soularr)";

    libraryDir = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/Music/library";
      description = "Tagged, final music library. Only beets and Lidarr write here.";
    };

    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/Music/downloads";
      description = "slskd completed downloads, watched by Soularr for Lidarr import.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4533;
      description = "Navidrome HTTP port, published on the tailnet.";
    };

    singlesArtists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "Niko B" ];
      description = ''
        Artists pinned to a metadata profile that allows Single and EP releases,
        matched on exact Lidarr artist name. Use for artists whose output is
        singles-led, where the stock profile would show almost nothing.
      '';
    };

    soundtrackArtists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Artists pinned to a metadata profile that additionally allows the
        secondary type Soundtrack, matched on exact Lidarr artist name. Use for
        an artist whose wanted release is a film credit; every other profile
        drops those.
      '';
    };

    frozenPlaylists = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "G Y M"
        "G Y M 2"
        "Chill Focus"
      ];
      description = ''
        Playlists the Spotify matcher stops rewriting, matched on exact name.
        Their `.m3u` is left as it was and Navidrome's sync flag is cleared, so
        the copy in the app becomes the real one and edits made there stick.
        A track in one of these also pins its artist against the janitor.
      '';
    };

    playerProfiles = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            match = lib.mkOption {
              type = lib.types.str;
              description = "SQL LIKE pattern matched against the Navidrome player name.";
            };
            profile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Navidrome transcoding profile name, or null to stream the original file untouched.";
            };
            bitrate = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = "Max bitrate in kbps; 0 means unlimited.";
            };
          };
        }
      );
      default = [
        # Transcoded, this buffers: NaviBeat prefetches by opening several
        # streams at once, each spawning its own ffmpeg, and they contend until
        # the track actually playing starves (logged as "broken pipe" when the
        # client gives up). Serving the original is a static file read, so range
        # requests work and seeking behaves. 1.7 Mbps is nothing on 5G, and the
        # AirPods re-encode to AAC over Bluetooth regardless, so transcoding was
        # never buying quality here: only cellular data.
        { match = "%NaviBeat%"; }
        # Kopuz reaches the server from the linux laptops over the tailnet, not
        # from this machine, so bit-perfect is not free: on a slow link a FLAC
        # track took about a minute to load. Opus is safe here: kopuz decodes
        # it through symphonia-adapter-libopus.
        {
          match = "%kopuz%";
          profile = "opus audio";
          bitrate = 128;
        }
        {
          match = "%NavidromeUI%";
          profile = "opus audio";
          bitrate = 128;
        }
      ];
      description = "Per-client transcoding, reapplied on a timer since Navidrome stores it in its database.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.music-stack = {
      serviceConfig = {
        Label = "kyan.music-stack";
        ProgramArguments = [ "${launcher}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 60;
        StandardOutPath = "${home}/Library/Logs/music-stack.log";
        StandardErrorPath = "${home}/Library/Logs/music-stack.log";
      };
    };

    launchd.user.agents.music-stack-reconcile = {
      serviceConfig = {
        Label = "kyan.music-stack-reconcile";
        ProgramArguments = [ "${reconcile}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        RunAtLoad = true;
        StartInterval = 600;
        StandardOutPath = "${home}/Library/Logs/music-stack.log";
        StandardErrorPath = "${home}/Library/Logs/music-stack.log";
      };
    };

    # Hourly, same as the playlist matcher and for the same reason: the answer
    # changes when the library grows, not only when new listens arrive.
    launchd.user.agents.music-stack-listens = {
      serviceConfig = {
        Label = "kyan.music-stack-listens";
        ProgramArguments = [ "${listens}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        RunAtLoad = true;
        StartInterval = 3600;
        StandardOutPath = "${home}/Library/Logs/music-stack.log";
        StandardErrorPath = "${home}/Library/Logs/music-stack.log";
      };
    };

    launchd.user.agents.music-stack-playlists = {
      serviceConfig = {
        Label = "kyan.music-stack-playlists";
        ProgramArguments = [ "${playlists}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        RunAtLoad = true;
        StartInterval = 3600;
        StandardOutPath = "${home}/Library/Logs/music-stack.log";
        StandardErrorPath = "${home}/Library/Logs/music-stack.log";
      };
    };

    # Reachable by hand because the interesting runs are the manual ones:
    # `music-gc --dry-run` before trusting it, `music-gc --restore "<artist>"`
    # to undo one.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "music-gc" ''exec ${gc} "$@"'')
    ];

    # Daily, and not at load: every window it applies is measured in weeks, so
    # a run per rebuild would only be a way to hit a bad rule sooner.
    launchd.user.agents.music-stack-gc = {
      serviceConfig = {
        Label = "kyan.music-stack-gc";
        ProgramArguments = [ "${gc}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        StartInterval = 86400;
        StandardOutPath = "${home}/Library/Logs/music-stack.log";
        StandardErrorPath = "${home}/Library/Logs/music-stack.log";
      };
    };

    # Daily rather than hourly: only newly imported files are decoded after the
    # first pass, but that first pass reads the whole library off the SD card.
    launchd.user.agents.music-stack-verify = {
      serviceConfig = {
        Label = "kyan.music-stack-verify";
        ProgramArguments = [ "${verify}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        RunAtLoad = true;
        StartInterval = 86400;
        StandardOutPath = "${home}/Library/Logs/music-stack.log";
        StandardErrorPath = "${home}/Library/Logs/music-stack.log";
      };
    };

  };
}
