{ config, ... }:
let
  home = config.users.users.kyandesutter.home;
  flakeDir = "${home}/.config/nix";
in
{
  # Weekly: pull the CI-validated flake.lock from origin/main (pushed by
  # .github/workflows/update.yml), build-test, then prompt to rebuild.
  # The orchestrator script lives in the repo so it can be tweaked without a
  # rebuild. Schedule: Saturdays at 10:00 local time, two hours after the
  # 08:00 UTC CI update run. launchd will fire on the next wake if the
  # machine was asleep.
  launchd.user.agents.kyan-nix-weekly-update = {
    serviceConfig = {
      Label = "kyan.nix-weekly-update";
      ProgramArguments = [
        "/bin/bash"
        "-lc"
        "${flakeDir}/scripts/nix-weekly-update.sh"
      ];
      EnvironmentVariables = {
        PATH = "/run/current-system/sw/bin:/run/current-system/sw/sbin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        FLAKE_DIR = flakeDir;
      };
      StartCalendarInterval = [
        { Weekday = 6; Hour = 10; Minute = 0; }
      ];
      RunAtLoad = false;
      StandardOutPath = "${home}/Library/Logs/kyan-nix-weekly-update.log";
      StandardErrorPath = "${home}/Library/Logs/kyan-nix-weekly-update.log";
    };
  };
}
