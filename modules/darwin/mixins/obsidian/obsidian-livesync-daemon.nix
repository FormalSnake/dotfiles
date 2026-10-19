{ config, ... }:
let
  home = config.users.users.kyandesutter.home;
  flakeDir = "${home}/.config/nix";
in
{
  # Headless LiveSync: a self-hosted-livesync CLI daemon keeps ~/Notes current
  # off CouchDB's _changes feed, so the scan + note watchers see synced edits
  # without the Obsidian GUI open (the GUI-only disk-flush was the note-inbox
  # sync gap). Long-running, so KeepAlive. The script lives in the repo (live-
  # editable) and self-throttles until the CLI is built and the agenix secret
  # exists. Build once: scripts/obsidian-livesync-cli-build.sh.
  launchd.user.agents.obsidian-livesync-daemon = {
    serviceConfig = {
      Label = "kyan.obsidian-livesync-daemon";
      ProgramArguments = [
        "/bin/bash"
        "-lc"
        "${flakeDir}/scripts/obsidian-livesync-daemon.sh"
      ];
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/kyandesutter/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      KeepAlive = true;
      RunAtLoad = true;
      ThrottleInterval = 30;
      StandardOutPath = "${home}/Library/Logs/obsidian-livesync-daemon.log";
      StandardErrorPath = "${home}/Library/Logs/obsidian-livesync-daemon.log";
    };
  };
}
