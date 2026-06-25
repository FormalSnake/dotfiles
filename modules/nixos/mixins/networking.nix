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

  networking.firewall = {
    enable = true;
    # Steam/gamescope ports are opened by programs.steam.*.openFirewall (gaming.nix).
  };
}
