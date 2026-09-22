{ config, lib, ... }:
let
  cfg = config.kyan.oomd;
in
{
  options.kyan.oomd.enable = lib.mkEnableOption "systemd-oomd with Fedora's desktop policy";

  config = lib.mkIf cfg.enable {
    # systemd-oomd already runs on every host (nixpkgs enables the daemon by
    # default), but with nothing configured it is a no-op: every cgroup sits at
    # ManagedOOMSwap=auto / ManagedOOMMemoryPressure=auto, and `auto` means
    # "monitor this only if an ancestor opted in". Nothing opts in, so the
    # daemon watches zero cgroups (verified on the e1504g 2026-09-01:
    # `systemctl show -p ManagedOOMMemoryPressure -- -.slice user.slice
    # user@1000.service` returned auto for all three).
    #
    # This does not replace earlyoom (mixins/boot.nix), it covers the case
    # earlyoom structurally cannot. earlyoom polls free RAM *and* free swap and
    # only fires when both are under their thresholds, so a host whose swap tier
    # dwarfs its RAM never reaches the swap condition (see the
    # freeSwapThreshold=70 override in systems/e1504g/default.nix, and it still
    # does not trip). oomd keys off per-cgroup memory PSI, which measures the
    # stall itself, so the size of the swap tier is irrelevant to it.
    #
    # Kill scope is the user manager's app.slice only. uwsm runs Hyprland in
    # session.slice and launched apps in app.slice, so scoping pressure-kill
    # to app.slice keeps the compositor out of reach. Fedora's user.slice-wide
    # policy lets oomd pick session.slice, i.e. the whole desktop.
    #
    # Written out rather than using nixpkgs' `enableUserSlices`, which scopes
    # to user.slice at an 80% pressure limit. 80% PSI sustained for 20 s is a
    # session that has already stopped responding; Fedora ships 50%
    # (10-oomd-user-service-defaults.conf) and that is the number this matches.
    systemd.user.units."app.slice" = {
      text = ''
        [Slice]
        ManagedOOMMemoryPressure=kill
        ManagedOOMMemoryPressureLimit=50%
      '';
      overrideStrategy = "asDropin";
    };

    # Fedora's 10-oomd-root-slice-defaults.conf. Deliberately NOT nixpkgs'
    # `enableRootSlice`: that applies memory-pressure kill to -.slice, which
    # pulls system.slice into scope. Fedora watches the swap tier there
    # instead, which is the safe system-wide signal.
    systemd.slices."-".sliceConfig.ManagedOOMSwap = "kill";

    # Fedora's 10-oomd-defaults.conf. Pressure has to hold for 20 s before
    # oomd acts, so a build or a burst of page-ins does not cost a process.
    systemd.oomd.settings.OOM.DefaultMemoryPressureDurationSec = "20s";
  };
}
