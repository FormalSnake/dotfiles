{ config, ... }:
let
  home = config.users.users.kyandesutter.home;
  flakeDir = "${home}/.config/nix";
in
{
  # Free-text note inbox: text typed into the vault's Inbox/index.md is filed
  # into notes by headless Claude once it ends with a "done" signal. The script
  # lives in the repo (live-editable without a rebuild — same pattern as the
  # scan watcher). Pure 5-minute poll (no WatchPaths): each tick short-circuits
  # unless the freeform changed, so a parked draft costs nothing. Self-locking,
  # so overlapping ticks are harmless.
  launchd.user.agents.obsidian-note-watcher = {
    serviceConfig = {
      Label = "kyan.obsidian-note-watcher";
      ProgramArguments = [
        "/bin/bash"
        "-lc"
        "${flakeDir}/scripts/obsidian-note-watcher.sh"
      ];
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/kyandesutter/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StartInterval = 300;
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/obsidian-note-watcher.log";
      StandardErrorPath = "${home}/Library/Logs/obsidian-note-watcher.log";
    };
  };
}
