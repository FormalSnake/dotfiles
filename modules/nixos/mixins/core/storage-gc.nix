{ config, pkgs, ... }:
let
  home = config.users.users.kyandesutter.home;
in
{
  # Daily disk reclaim, the Linux twin of modules/darwin/mixins/core/storage-gc.nix:
  # stale zig/cargo/swift/node build output under ~/Developer and the agent
  # worktree dirs, plus package-manager caches. Nix generations stay with
  # nix.gc (modules/nixos/mixins/core/nix.nix), the script skips them here. Below
  # 30 GB free on / the script cuts every age cutoff to a quarter.
  #
  # The script runs from the repo checkout so cutoffs and scan roots tune
  # without a rebuild. The e1504g gets this unit through a closure built on the
  # g815; it only runs the script, nothing is built there.
  #
  # Not persistent, with a boot run 30 minutes in: same reasoning as nix-gc.
  # A catch-up run right after boot walks ~/Developer while the login storm is
  # still pushing the 8 GB e1504g into swap.
  systemd.services.kyan-storage-gc = {
    description = "Reclaim stale build output and package caches";
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.git
      pkgs.procps
      "/run/current-system/sw"
      "/etc/profiles/per-user/kyandesutter"
      "${home}/.cargo"
    ];
    environment.HOME = home;
    serviceConfig = {
      Type = "oneshot";
      User = "kyandesutter";
      ExecStart = "${pkgs.bash}/bin/bash ${home}/.config/nix/scripts/storage-gc.sh --apply --prune-worktrees";
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
      Nice = 19;
      MemoryHigh = "1G";
    };
  };

  systemd.timers.kyan-storage-gc = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "30min";
      Persistent = false;
    };
  };
}
