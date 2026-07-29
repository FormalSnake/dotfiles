{ config, pkgs, ... }:
let
  libraryDir = "/Volumes/Music/library";
  purchasesDir = "/Volumes/Music/purchases";

  # The ListenBrainz daily-playlist plugin resolves tracks by MBID and nothing
  # else, so an untagged album is invisible to every discovery playlist even
  # though it plays fine. beets is what guarantees the MBIDs are there;
  # acoustid fingerprinting is what rescues releases whose tags are wrong.
  beetsConfig = {
    directory = libraryDir;
    library = "${config.home.homeDirectory}/.local/share/beets/library.db";

    plugins = [
      "chroma"
      "fetchart"
      "embedart"
      "lyrics"
      "replaygain"
      "scrub"
      "mbsync"
      "duplicates"
      "info"
    ];

    import = {
      move = true;
      write = true;
      # Anything beets cannot match confidently is parked rather than guessed
      # at: a wrong MBID is worse than none, because mbsync will keep it.
      quiet_fallback = "skip";
      log = "${config.home.homeDirectory}/.local/share/beets/import.log";
    };

    paths = {
      default = "$albumartist/$album%aunique{}/$track $title";
      singleton = "Non-Album/$artist/$title";
      comp = "Compilations/$album%aunique{}/$track $title";
    };

    musicbrainz.extra_tags = [
      "year"
      "catalognum"
      "country"
      "media"
    ];

    replaygain.backend = "ffmpeg";
    scrub.auto = true;
    fetchart.auto = true;
    embedart.auto = true;
    # LRCLib is the only backend that returns timestamped lyrics, and beets
    # ignores them unless asked. Matches what the stack's own fetcher writes as
    # .lrc for everything Lidarr imports.
    lyrics.synced = true;
  };
in
{
  home.packages = [
    pkgs.beets
    pkgs.chromaprint
    pkgs.picard
  ];

  xdg.configFile."beets/config.yaml".text = builtins.toJSON beetsConfig;

  # beets refuses to run at all if the database directory is missing, and it
  # only offers to create it interactively.
  home.file.".local/share/beets/.keep".text = "";

  # Purchased albums land in purchases/ and get pulled in by hand: beets is
  # interactive when a match is ambiguous, so this is deliberately not a
  # watcher.
  home.shellAliases.music-import = "beet import ${purchasesDir}";
}
