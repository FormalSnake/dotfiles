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
  pluginPkgs = with pkgs.navidromePlugins; [
    listenbrainz-daily-playlist
    audiomuseai
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
          ND_MUSICFOLDER: /music
          ND_DATAFOLDER: /data
          ND_CACHEFOLDER: /data/cache
          ND_PORT: "4533"

          ND_PLUGINS_ENABLED: "true"
          ND_PLUGINS_FOLDER: /plugins

          # Discovery: ListenBrainz supplies similar-artists and similar-songs
          # for Navidrome's own radio, and is what the daily-playlist plugin
          # reads for weekly-jams / daily-jams / weekly-exploration.
          ND_ENABLEEXTERNALSERVICES: "true"
          ND_LASTFM_ENABLED: "true"
          ND_LISTENBRAINZ_ENABLED: "true"
          ND_AGENTS: listenbrainz,lastfm,deezer

          # Scrobbles go through multi-scrobbler so Spotify plays and Navidrome
          # plays reach ListenBrainz as one history. Only submit-listens and
          # validate-token follow this URL; similar-artists, artist metadata and
          # popularity are hardcoded to listenbrainz.org in Navidrome's client,
          # so discovery keeps working while the stack is pointed here.
          ND_LISTENBRAINZ_BASEURL: http://multi-scrobbler:9078/1/

          # Without this, Subsonic's getArtist only counts albums an artist is
          # credited on as *album* artist, so a feature such as Majestic on
          # "Who's That What's That" is an artist with an empty page — the
          # track only reachable under Niko B. Navidrome splits the credit
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

      # Spotify cannot push plays anywhere, so this polls the account and
      # forwards them; Navidrome posts into the same instance, which is what
      # merges both into one ListenBrainz history. The redirect URI is bound to
      # 127.0.0.1 rather than localhost because Spotify stopped accepting
      # localhost redirects, and to a loopback address because everything
      # except loopback has to be https.
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
  # rewrites them — same contract as DMS settings.json. @SLSKD_KEY@ and
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
    # Defaults to false upstream, which searches for the bare album title —
    # "Currents" alone matches nothing useful on Soulseek.
    album_prepend_artist = True
    search_type = incrementing_page
    number_of_albums_to_grab = 10

    [Logging]
    level = INFO
  '';

  # A source scrobbles to every client unless told otherwise, so Spotify and the
  # Navidrome endpoint both reach ListenBrainz with no further wiring. The
  # Spotify app credentials and the ListenBrainz user token are the two values
  # nix cannot generate. @MSLZ_KEY@ is what Navidrome authenticates with: it
  # replaces the real ListenBrainz token in Navidrome's per-user link dialog.
  msSeed = pkgs.writeText "multi-scrobbler-seed.json" ''
    {
      "sources": [
        {
          "name": "spotify",
          "enable": true,
          "type": "spotify",
          "data": {
            "clientId": "CHANGEME",
            "clientSecret": "CHANGEME",
            "redirectUri": "http://127.0.0.1:9078/callback",
            "interval": 60
          }
        },
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

    # Nothing else in the stack puts cover art on disk: Navidrome only reads
    # art from the album folder or from the file's own tags, and a Soulseek
    # download carries embedded art only if whoever uploaded it bothered. The
    # Kodi consumer writes folder.jpg into every album folder from Lidarr's own
    # metadata, which is first in Navidrome's CoverArtPriority. The .nfo
    # sidecars are turned off — Navidrome ignores them.
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

    if [ -n "$singles_id" ]; then
      artists=$(curl -sf -H "X-Api-Key: $LIDARR_KEY" http://localhost:8686/api/v1/artist) || exit 0
      for want in ${lib.escapeShellArgs cfg.singlesArtists}; do
        aid=$(printf '%s' "$artists" | jq -r --arg n "$want" '(map(select(.artistName==$n))[0].id) // empty')
        cur=$(printf '%s' "$artists" | jq -r --arg n "$want" '(map(select(.artistName==$n))[0].metadataProfileId) // empty')
        [ -n "$aid" ] || continue
        [ "$cur" = "$singles_id" ] && continue

        printf '%s' "$artists" \
          | jq --arg n "$want" --argjson p "$singles_id" 'map(select(.artistName==$n))[0] | .metadataProfileId=$p' \
          | curl -sf -X PUT -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" -d @- \
              "http://localhost:8686/api/v1/artist/$aid" >/dev/null || continue

        # The profile change alone does not surface the newly allowed releases;
        # Lidarr only re-reads them on a refresh.
        curl -sf -X POST -H "X-Api-Key: $LIDARR_KEY" -H "Content-Type: application/json" \
          -d "{\"name\":\"RefreshArtist\",\"artistId\":$aid}" \
          http://localhost:8686/api/v1/command >/dev/null
        echo "reconcile: pinned $want to 'Singles and Albums'"
      done
    fi

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
    # means playerProfiles below is authoritative — a profile changed by hand in
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

    # slskd only indexes shares at startup or on demand, so a freshly downloaded
    # album is not offered back to the network until something asks for a
    # rescan. Left alone the share count stays at whatever it was on boot, the
    # account keeps looking like a leech, and Soulseek peers reject transfers —
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
  '';

  # Navidrome displays lyrics but never fetches them, and nothing upstream of it
  # writes any: Lidarr does not do lyrics at all and a Soulseek rip almost never
  # carries them. LRCLIB is the one free source with timestamped lyrics, and
  # .lrc sidecars are preferable to embedded tags here — they outrank `embedded`
  # in Navidrome's LyricsPriority and they leave Lidarr's files alone.
  lyrics = pkgs.writeShellScript "music-stack-lyrics" ''
    set -uo pipefail
    export PATH="/run/current-system/sw/bin:/usr/bin:/bin"

    [ -d "${cfg.libraryDir}" ] || exit 0

    # LRCLIB throttles clients that do not identify themselves, hard enough that
    # a first full sweep would return empty for most of the library.
    ua="music-stack (+https://github.com/FormalSnake/nix)"

    # Tracks LRCLIB has nothing for, so a scheduled run costs one request per
    # newly imported track instead of one per track in the library. Delete this
    # file to retry the whole library.
    misses="${stackDir}/.lyrics-misses"
    touch "$misses"

    ${pkgs.fd}/bin/fd -0 -e flac -e mp3 -e m4a -e ogg -e opus . "${cfg.libraryDir}" \
      | while IFS= read -r -d "" f; do
          lrc="''${f%.*}.lrc"
          [ -e "$lrc" ] && continue
          grep -qxF "$f" "$misses" && continue

          meta=$(${pkgs.ffmpeg-headless}/bin/ffprobe -v error -of json \
            -show_entries format=duration:format_tags=title,artist,album "$f") || continue

          # ffprobe echoes each tag key in the case the file used, which differs
          # between FLAC and MP4, so normalise before reading.
          tags=$(printf '%s' "$meta" | jq -c '.format.tags // {} | with_entries(.key |= ascii_downcase)')
          title=$(printf '%s' "$tags" | jq -r '.title // empty')
          album=$(printf '%s' "$tags" | jq -r '.album // empty')
          # A collaboration is tagged "A;B"; LRCLIB matches one name.
          artist=$(printf '%s' "$tags" | jq -r '.artist // empty' | cut -d';' -f1)
          dur=$(printf '%s' "$meta" | jq -r '.format.duration // 0 | tonumber | round')
          [ -n "$title" ] && [ -n "$artist" ] || continue

          got=$(curl -sG --max-time 20 -A "$ua" \
            --data-urlencode "artist_name=$artist" \
            --data-urlencode "track_name=$title" \
            --data-urlencode "album_name=$album" \
            --data-urlencode "duration=$dur" \
            https://lrclib.net/api/get \
            | jq -r '(.syncedLyrics // .plainLyrics) // empty' 2>/dev/null)

          # /api/get only matches when the album name and duration agree with
          # LRCLIB's copy, which a Soulseek rip frequently does not. Searching on
          # artist and title and re-checking the duration here rescues those.
          if [ -z "$got" ]; then
            got=$(curl -sG --max-time 20 -A "$ua" \
              --data-urlencode "artist_name=$artist" \
              --data-urlencode "track_name=$title" \
              https://lrclib.net/api/search \
              | jq -r --argjson d "$dur" '
                  [.[]? | select(((.duration // 0) - $d | fabs) <= 5)]
                  | (map(select(.syncedLyrics != null))[0] // .[0] // {})
                  | (.syncedLyrics // .plainLyrics) // empty' 2>/dev/null)
          fi

          if [ -n "$got" ]; then
            printf '%s\n' "$got" > "$lrc"
            echo "lyrics: $artist - $title"
          else
            printf '%s\n' "$f" >> "$misses"
          fi
          sleep 1
        done
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

    mkdir -p "${stackDir}"/{navidrome-backup,navidrome-plugins,lidarr,slskd,soularr,multi-scrobbler,audiomuse} "${incompleteDir}"

    # Re-staged every start so a nixpkgs plugin bump actually lands. Navidrome
    # unpacks each .ndp next to itself, so the folder must be writable — a
    # store symlink is not enough.
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
        # never buying quality here — only cellular data.
        { match = "%NaviBeat%"; }
        # Kopuz reaches the server from the linux laptops over the tailnet, not
        # from this machine, so bit-perfect is not free: on a slow link a FLAC
        # track took about a minute to load. Opus is safe here — kopuz decodes
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

    # Separate from the reconcile agent because a first sweep of an untouched
    # library runs for hours at LRCLIB's rate limit, and launchd will not start
    # a second copy of an agent that is still running.
    launchd.user.agents.music-stack-lyrics = {
      serviceConfig = {
        Label = "kyan.music-stack-lyrics";
        ProgramArguments = [ "${lyrics}" ];
        EnvironmentVariables = {
          PATH = "/usr/local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
        RunAtLoad = true;
        StartInterval = 3600;
        StandardOutPath = "${home}/Library/Logs/music-stack.log";
        StandardErrorPath = "${home}/Library/Logs/music-stack.log";
      };
    };
  };
}
