{ pkgs, ... }:
{
  # Network diagnostic tools.
  environment.systemPackages = with pkgs; [
    iw # wifi link/PHY-rate/retry inspection
    traceroute
    mtr # per-hop latency/loss
  ];

  networking.networkmanager = {
    enable = true;
    # The g815's Wi-Fi is an Intel BE200 (iwlwifi/iwlmld). Its latency/powersave
    # tuning (power_save=0, power_scheme=1, NetworkManager wifi.powersave=false)
    # is host-specific and handled in systems/g815/default.nix.

    # Force Google DNS (8.8.8.8 / 8.8.4.4) for every connection, overriding the
    # DNS servers handed out by DHCP. NetworkManager global-dns applies to all
    # connections (incl. Wi-Fi) regardless of the active profile.
    settings."global-dns-domain-*".servers = "8.8.8.8,8.8.4.4";
  };

  # Hostname is set per-host in systems/g815/default.nix.

  # Reach the macbook over Tailscale by name on a DNS-hostile host. Tailscale
  # Serve / MagicDNS names (e.g. the macbook's `*.ts.net` dev URLs on :8443)
  # resolve only via the tailnet resolver 100.100.100.100 — but this host forces
  # Google DNS (above) AND NordVPN overwrites /etc/resolv.conf when connected,
  # so both bypass MagicDNS and the names won't resolve. Pin them to the
  # macbook's stable Tailscale IP via /etc/hosts (nsswitch `files` is consulted
  # before DNS, so it survives both). This is the single source of truth for the
  # macbook's tailnet IP — ssh/mosh/curl/browser all resolve the name through it.
  # One entry covers every Serve port/path since they share the hostname; the
  # TLS cert stays valid because SNI/Host is still the `.ts.net` name.
  networking.hosts."100.75.60.102" = [
    "macbook-pro-2.tailb24294.ts.net"
    "macbook-pro-2"
  ];

  networking.firewall = {
    enable = true;
    # Steam/gamescope ports are opened by programs.steam.*.openFirewall (gaming.nix).
  };
}
