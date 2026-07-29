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

  # nixpkgs' navidrome is `broken = stdenv.hostPlatform.isDarwin`, so the whole
  # stack runs in Docker (OrbStack) rather than half launchd, half container.
  # The plugin derivations are plain .ndp data files and still build here, so
  # plugin versions stay pinned by the flake even though the server does not.
  pluginPkgs = with pkgs.navidromePlugins; [ listenbrainz-daily-playlist ];

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

          # Keeps cellular listening usable: library stays FLAC, clients that
          # ask for less get Opus.
          ND_ENABLETRANSCODINGCONFIG: "true"
          ND_TRANSCODINGCACHESIZE: 2GB

          ND_SCANNER_WATCHERWAIT: 10s
          ND_SCANSCHEDULE: "@every 1h"
        volumes:
          - ${cfg.libraryDir}:/music
          - ${stackDir}/navidrome:/data
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

    # Navidrome: transcoding profile ids are generated per install, so match the
    # profile by name rather than hardcoding one. Applied unconditionally, which
    # means playerProfiles below is authoritative — a profile changed by hand in
    # the web UI is reverted within ten minutes.
    ${lib.concatMapStringsSep "\n" (p: ''
      docker exec navidrome sqlite3 /data/navidrome.db "
        update player
        set transcoding_id = ${
          if p.profile == null then "NULL" else "(select id from transcoding where name = '${p.profile}')"
        },
            max_bit_rate = ${toString p.bitrate}
        where name like '${p.match}';" 2>/dev/null
    '') cfg.playerProfiles}
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

    mkdir -p "${stackDir}"/{navidrome,navidrome-plugins,lidarr,slskd,soularr} "${incompleteDir}"

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

    seed() {
      [ -f "$2" ] && return 0
      sed -e "s|@SLSKD_KEY@|$SLSKD_KEY|g" -e "s|@LIDARR_KEY@|$LIDARR_KEY|g" "$1" > "$2"
      chmod 600 "$2"
    }

    seed ${lidarrSeed} "${stackDir}/lidarr/config.xml"
    seed ${slskdSeed} "${stackDir}/slskd/slskd.yml"
    seed ${soularrSeed} "${stackDir}/soularr/config.ini"

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
        # AirPods cap out at AAC over Bluetooth, so lossless never reaches the
        # ear. AAC rather than Opus purely for native Apple decoding.
        {
          match = "%NaviBeat%";
          profile = "aac audio";
          bitrate = 256;
        }
        # Same machine as the server and wired speakers, so bit-perfect costs
        # nothing.
        { match = "%kopuz%"; }
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
  };
}
