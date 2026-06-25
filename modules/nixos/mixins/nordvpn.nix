{ inputs, pkgs, ... }:
let
  # Absolute path into the system profile (same pattern as power-source) — the
  # upstream module puts the nordvpn binary in environment.systemPackages.
  nordvpn = "/run/current-system/sw/bin/nordvpn";
in
{
  # NordVPN — laptop privacy/geo VPN exit ONLY. The device mesh to the macbook
  # is Tailscale, kept on a separate job so NordVPN's killswitch can't sever it.
  # This community flake provides the package + the nordvpnd systemd service,
  # the `nordvpn` group, and the firewall rules (TCP 443 / UDP 1194).
  #
  # Runtime (owner): `nordvpn login` with SERVICE credentials. The allowlist and
  # lan-discovery settings are enforced declaratively by nordvpn-settings below;
  # only login stays manual (account credentials, deliberately not in this repo).
  imports = [ inputs.nordvpn-flake.nixosModules.default ];

  services.nordvpn = {
    enable = true;
    users = [ "kyandesutter" ];
  };

  # The upstream module only exposes `enable`/`users`. Everything else
  # (`allowlist`, `lan-discovery`, …) lives in NordVPN's own vault under
  # /var/lib/nordvpn and is settable only through the `nordvpn` CLI at runtime,
  # so it silently vanishes on a fresh install / vault reset. This oneshot
  # re-applies the settings the Tailscale mesh depends on once the daemon is up.
  # Both are pre-login settings (no account needed). Each is applied only when
  # not already in the desired state — the "already set" path returns exit 1, so
  # checking first keeps the unit idempotent while letting a real `set` failure
  # surface instead of being swallowed by `|| true`.
  systemd.services.nordvpn-settings = {
    description = "Enforce declarative NordVPN settings (allowlist, LAN discovery)";
    after = [ "nordvpn.service" ];
    requires = [ "nordvpn.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.gnugrep pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Group = "nordvpn";
      # The nordvpn CLI calls os.UserHomeDir() (for its per-user config) and
      # aborts with "cannot get user home dir" when $HOME is unset — which it is
      # for a root oneshot. Give it one so every `nordvpn` call below works.
      Environment = "HOME=/root";
    };
    script = ''
      # Wait for the daemon to accept CLI commands (it starts NonBlocking).
      for _ in $(seq 1 30); do
        ${nordvpn} settings >/dev/null 2>&1 && break
        sleep 1
      done

      settings=$(${nordvpn} settings 2>/dev/null || true)

      # Tailscale's CGNAT range (100.64.0.0/10) must bypass NordVPN so the
      # killswitch/routing can never sever the device mesh to the macbook.
      echo "$settings" | grep -q '100.64.0.0/10' \
        || ${nordvpn} allowlist add subnet 100.64.0.0/10

      # LAN discovery lets Tailscale take its direct path to same-network peers
      # (e.g. the macbook on 192.168.x); without it NordVPN firewalls the local
      # subnet and the WireGuard handshake never completes.
      echo "$settings" | grep -qi 'LAN Discovery: enabled' \
        || ${nordvpn} set lan-discovery enable
    '';
  };
}
