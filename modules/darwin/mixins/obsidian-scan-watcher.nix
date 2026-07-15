{ config, ... }:
let
  home = config.users.users.kyandesutter.home;
  flakeDir = "${home}/.config/nix";
in
{
  # Notebook-scan pipeline: images synced into the vault's scan inbox are
  # transcribed to notes by headless Claude. The script lives in the repo
  # (live-editable without a rebuild — same pattern as auto-update.nix).
  # WatchPaths fires on any change under the dir; the script is idempotent
  # (processed/failed images are moved out) and self-locks, so extra fires
  # are harmless. StartInterval is the safety net for missed events / the
  # dir not existing at agent load time.
  launchd.user.agents.obsidian-scan-watcher = {
    serviceConfig = {
      Label = "kyan.obsidian-scan-watcher";
      ProgramArguments = [
        "/bin/bash"
        "-lc"
        "${flakeDir}/scripts/obsidian-scan-watcher.sh"
      ];
      EnvironmentVariables = {
        PATH = "/etc/profiles/per-user/kyandesutter/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      WatchPaths = [ "${home}/Notes/_inbox/scans" ];
      StartInterval = 600;
      ThrottleInterval = 15;
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/obsidian-scan-watcher.log";
      StandardErrorPath = "${home}/Library/Logs/obsidian-scan-watcher.log";
    };
  };
}
