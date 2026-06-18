{ inputs, ... }:
{
  # NordVPN — laptop privacy/geo VPN exit ONLY. The device mesh to the macbook
  # is Tailscale, kept on a separate job so NordVPN's killswitch can't sever it.
  # This community flake provides the package + the nordvpnd systemd service,
  # the `nordvpn` group, and the firewall rules (TCP 443 / UDP 1194).
  #
  # Runtime (owner): `nordvpn login` with SERVICE credentials, then
  # `nordvpn allowlist add subnet 100.64.0.0/10` so the killswitch never blocks
  # Tailscale. See docs/remote-server.md.
  imports = [ inputs.nordvpn-flake.nixosModules.default ];

  services.nordvpn = {
    enable = true;
    users = [ "kyandesutter" ];
  };
}
