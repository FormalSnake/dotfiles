{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.kyan.nordvpn;
  # Absolute path into the system profile: the
  # upstream module puts the nordvpn binary in environment.systemPackages.
  nordvpn = "/run/current-system/sw/bin/nordvpn";
in
{
  # Per-host: the account/login lives on the g815 only, so other hosts (the
  # e1504g) leave this off. imports/disabledModules can't be conditional, so
  # only the service config below is gated.
  options.kyan.nordvpn.enable = lib.mkEnableOption "NordVPN daemon + declarative settings";
  # NordVPN: laptop privacy/geo VPN exit ONLY. The device mesh to the macbook
  # is Tailscale, kept on a separate job so NordVPN's killswitch can't sever it.
  # This community flake provides the package + the nordvpnd systemd service,
  # the `nordvpn` group, and the firewall rules (TCP 443 / UDP 1194).
  #
  # Runtime (owner): `nordvpn login` with SERVICE credentials. The allowlist and
  # lan-discovery settings are enforced declaratively by nordvpn-settings below;
  # only login stays manual (account credentials, deliberately not in this repo).
  imports = [ inputs.nordvpn-flake.nixosModules.default ];

  # nixpkgs ≥ 2026-07 ships its own services.nordvpn module declaring the same
  # options, it's not a drop-in (no `users`, daemon is `nordvpnd` running as an
  # unprivileged user against the same vault), so keep the flake's and disable
  # the upstream one.
  disabledModules = [ "services/networking/nordvpn.nix" ];

  # Disabling that module removes its page from the local NixOS manual, which
  # otherwise fails the manual's static-redirects consistency check
  # (module-services-nordvpn): skips only the check, not the manual.
  config.documentation.nixos.checkRedirects = false;

  config.services.nordvpn = {
    enable = cfg.enable;
    users = [ "kyandesutter" ];
  };

  # Allowlisting the CGNAT range keeps Tailscale's *overlay* off the tunnel,
  # but says nothing about its underlay: the control-plane, DERP and STUN
  # dials all go to public addresses. Tailscale marks those packets fwmark
  # 0x80000 and installs ip rules 5210/5230/5250 to send them to `main`, then
  # `default`, then unreachable, so they can't loop back through tailscale0.
  # NordVPN leaves `main` holding the LAN default and moves the real one into
  # table 205 (`default dev nordlynx`), so the marked packets leave outside
  # the tunnel, where nordvpnd's firewall drops them. Everything still looks
  # up: the daemon runs, the interface exists, `curl` reaches the internet,
  # and the node is simply never registered — control dials fail, netcheck
  # reports UDP blocked, and `tailscale status` says offline. Found on the
  # g815 2026-09-04, off the tailnet since boot, which is also why the
  # e1504g's builds had quietly stopped offloading to it.
  #
  # Send the marked traffic through the tunnel instead, at priorities ahead
  # of tailscaled's own three. Private destinations stay on `main` so a
  # direct WireGuard path to a same-subnet peer (the macbook) still works,
  # exactly as lan-discovery intends; everything else takes table 205, which
  # means Tailscale rides the privacy exit rather than bypassing it.
  #
  # Table 205 is NordVPN's, but the rules are ours: tailscaled recreates
  # 5210-5250 on restart without touching lower priorities, and a NordVPN
  # reconnect rewrites table 205's contents, not the rule that points at it.
  # `ip rule add` has no replace, so drop our priorities first (in a loop:
  # a crashed run can leave duplicates).
  config.systemd.services.tailscale-nordvpn-routing = lib.mkIf cfg.enable {
    description = "Route Tailscale's marked underlay through the NordVPN tunnel";
    after = [
      "nordvpn.service"
      "tailscaled.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script =
      let
        ip = "${pkgs.iproute2}/bin/ip";
        mark = "fwmark 0x80000/0xff0000";
        # Mirrors the private ranges tailscaled itself excepts at 32759-32763.
        direct = {
          "5190" = "169.254.0.0/16";
          "5191" = "192.168.0.0/16";
          "5192" = "172.16.0.0/12";
          "5193" = "10.0.0.0/8";
        };
      in
      ''
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (prio: net: ''
            while ${ip} rule del priority ${prio} 2>/dev/null; do :; done
            ${ip} rule add priority ${prio} ${mark} to ${net} lookup main
          '') direct
        )}

        while ${ip} rule del priority 5200 2>/dev/null; do :; done
        ${ip} rule add priority 5200 ${mark} lookup 205
      '';
  };

  # The upstream module only exposes `enable`/`users`. Everything else
  # (`allowlist`, `lan-discovery`, …) lives in NordVPN's own vault under
  # /var/lib/nordvpn and is settable only through the `nordvpn` CLI at runtime,
  # so it silently vanishes on a fresh install / vault reset. This oneshot
  # re-applies the settings the Tailscale mesh depends on once the daemon is up.
  # Both are pre-login settings (no account needed). Each is applied only when
  # not already in the desired state: the "already set" path returns exit 1, so
  # checking first keeps the unit idempotent while letting a real `set` failure
  # surface instead of being swallowed by `|| true`.
  config.systemd.services.nordvpn-settings = lib.mkIf cfg.enable {
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
      # aborts with "cannot get user home dir" when $HOME is unset (which it is
      # for a root oneshot). Give it one so every `nordvpn` call below works.
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

      # Auto-connect dials the fastest exit as soon as the daemon is up (once
      # logged in), so NordVPN comes back after every boot like Tailscale does.
      # Without it the daemon runs but leaves the tunnel Disconnected until a
      # manual `nordvpn connect`.
      echo "$settings" | grep -qi 'Auto-connect: enabled' \
        || ${nordvpn} set autoconnect enable
    '';
  };
}
