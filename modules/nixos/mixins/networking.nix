{
  networking.networkmanager = {
    enable = true;
    # The MT7925 module (imported in systems/g815) recommends iwd as the wifi
    # backend and disables powersave; it sets wifi.backend itself.
  };

  # Hostname is set per-host in systems/g815/default.nix.

  networking.firewall = {
    enable = true;
    # Steam/gamescope ports are opened by programs.steam.*.openFirewall (gaming.nix).
  };
}
