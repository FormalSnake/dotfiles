{ pkgs, ... }:
let
  # Absolute path into the system profile (same pattern as the system-side
  # nordvpn mixin) — the upstream module puts the CLI in environment.systemPackages.
  nordvpn = "/run/current-system/sw/bin/nordvpn";

  # NordVPN's per-user norduserd registers its system-tray StatusNotifierItem on
  # *two* D-Bus connections (an upstream double-registration bug), so two
  # identical "NordVPN" entries appear in the tray — the watcher can't dedup
  # them because they share an Id but sit on different bus names. We drive
  # NordVPN entirely via the CLI + the declarative system nordvpn-settings
  # oneshot, so the tray icon serves no purpose; disable it.
  #
  # `Tray` is per-user state (norduserd's config), unlike the daemon-global
  # allowlist/lan-discovery the system oneshot enforces, so it must be set as
  # this user. Like those, it lives in NordVPN's own vault and silently vanishes
  # on a fresh install / vault reset, so re-apply it each session.
  disableTray = pkgs.writeShellScript "nordvpn-tray-off" ''
    # Wait for the per-user daemon to accept CLI commands (it starts NonBlocking).
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      ${nordvpn} settings >/dev/null 2>&1 && break
      ${pkgs.coreutils}/bin/sleep 1
    done

    # Flip only when currently enabled — the "already disabled" path returns
    # exit 1, so checking first keeps the unit idempotent while letting a real
    # `set` failure surface instead of being swallowed by `|| true`.
    ${nordvpn} settings 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qi 'Tray: enabled' \
      && ${nordvpn} set tray off \
      || true
  '';
in
{
  systemd.user.services.nordvpn-tray-off = {
    Unit = {
      Description = "Disable the NordVPN system-tray icon (upstream double-registers it)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Leave an already-applied setting untouched across `nixos-rebuild switch`
      # rather than re-running the oneshot on every rebuild (matches autostart).
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${disableTray}";
    };
  };
}
