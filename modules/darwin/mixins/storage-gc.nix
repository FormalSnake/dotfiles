{ config, ... }:
let
  home = config.users.users.kyandesutter.home;
  flakeDir = "${home}/.config/nix";
in
{
  # Daily disk reclaim: stale build artifacts, package-manager caches, Xcode
  # derived data, nix generations older than two weeks. 12:00, two hours after
  # the Saturday flake update agent so the two never overlap. Weekly was not
  # enough: agent worktrees can regrow 90 GB of cargo output between runs.
  # launchd fires on the next wake if the machine was asleep.
  #
  # The script lives in the repo rather than the store so the cutoffs and the
  # scan roots can be tuned without a rebuild, same as auto-update.nix. It is a
  # dry run unless given --apply.
  launchd.user.agents.kyan-storage-gc = {
    serviceConfig = {
      Label = "kyan.storage-gc";
      ProgramArguments = [
        "/bin/bash"
        "-lc"
        "${flakeDir}/scripts/mac-storage-gc.sh --apply"
      ];
      EnvironmentVariables = {
        # The tool sweeps reach for brew, npm, cargo, bun, pnpm and go; launchd
        # starts with none of them, and each one is skipped silently when it is
        # not on PATH, so a short PATH here means a quiet no-op instead of an
        # error.
        PATH = "/run/current-system/sw/bin:/run/current-system/sw/sbin:/etc/profiles/per-user/kyandesutter/bin:${home}/.cargo/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        HOME = home;
      };
      StartCalendarInterval = [
        { Hour = 12; Minute = 0; }
      ];
      RunAtLoad = false;
      # Truncated by the next run's redirect, so it stays one day of output.
      StandardOutPath = "${home}/Library/Logs/kyan-storage-gc.log";
      StandardErrorPath = "${home}/Library/Logs/kyan-storage-gc.log";
    };
  };
}
