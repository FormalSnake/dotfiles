{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Wi-Fi first, IP second. The nearby access points go to beaconDB with its
  # IP fallback switched off, so it either answers from Wi-Fi or 404s; a fix
  # tighter than 10 km is mapped to a zone offline by timezonefinder. Anything
  # else (no Wi-Fi, an unknown neighbourhood, a fix at sea) falls through to
  # tzupdate's IP lookup.
  #
  # Neither source is enough alone. Spanish mobile and CGNAT addresses
  # geolocate to Madrid wherever the phone is, so on Lanzarote (2026-10-09) IP
  # alone said Europe/Madrid, an hour out. beaconDB knows few access points
  # outside Europe, and geoclue (automatic-timezoned) then quietly uses
  # beaconDB's own DB-IP fallback: in Marrakesh (2026-10-04) that put a Maroc
  # Telecom IP near Heathrow, flipping Europe/London and Africa/Casablanca. With
  # the fallback off, Marrakesh lands on tzupdate, whose IP answer was right.
  locateZone =
    pkgs.writers.writePython3Bin "tz-locate"
      {
        libraries = [ pkgs.python3Packages.timezonefinder ];
        flakeIgnore = [ "E501" ];
      }
      ''
        import json
        import subprocess
        import urllib.request

        from timezonefinder import TimezoneFinder

        MAX_ACCURACY_M = 10_000


        def access_points():
            out = subprocess.run(
                ["${lib.getExe' config.networking.networkmanager.package "nmcli"}", "-t", "-e", "no",
                 "-f", "BSSID,SIGNAL,SSID", "device", "wifi", "list"],
                capture_output=True, text=True, check=True,
            ).stdout
            aps = []
            for line in out.splitlines():
                bssid, signal, ssid = line[:17], *line[18:].split(":", 1)
                # The opt-out every Wi-Fi location service honours.
                if ssid.endswith("_nomap"):
                    continue
                # nmcli reports 0..100; ichnaea wants dBm.
                aps.append({"macAddress": bssid.lower(), "signalStrength": int(signal) // 2 - 100})
            return aps


        def wifi_zone():
            aps = access_points()
            if len(aps) < 2:
                print(f"wifi: {len(aps)} access points, beaconDB needs two")
                return None
            body = json.dumps({
                "considerIp": False,
                "fallbacks": {"ipf": False, "lacf": False},
                "wifiAccessPoints": aps,
            }).encode()
            req = urllib.request.Request(
                "https://api.beacondb.net/v1/geolocate", data=body,
                headers={"Content-Type": "application/json"},
            )
            try:
                with urllib.request.urlopen(req, timeout=15) as resp:
                    fix = json.load(resp)
            except Exception as e:
                print(f"wifi: beaconDB gave no fix from {len(aps)} access points ({e})")
                return None
            lat, lon = fix["location"]["lat"], fix["location"]["lng"]
            accuracy = fix.get("accuracy", float("inf"))
            if "fallback" in fix or accuracy > MAX_ACCURACY_M:
                print(f"wifi: rejected fix {lat:.4f},{lon:.4f} accuracy {accuracy} m fallback {fix.get('fallback')}")
                return None
            zone = TimezoneFinder().timezone_at(lat=lat, lng=lon)
            print(f"wifi: fix {lat:.4f},{lon:.4f} accuracy {accuracy} m from {len(aps)} access points: {zone}")
            return zone


        def ip_zone():
            out = subprocess.run(
                ["${lib.getExe config.services.tzupdate.package}", "--print-only"],
                capture_output=True, text=True,
            )
            zone = out.stdout.strip()
            print(f"ip: tzupdate says {zone or 'nothing'}")
            return zone or None


        try:
            zone = wifi_zone()
        except Exception as e:
            print(f"wifi: {e}")
            zone = None
        zone = zone or ip_zone()
        if zone:
            print(f"setting timezone to {zone}")
            subprocess.run(["timedatectl", "set-timezone", zone], check=True)
      '';
in
{
  # Timezone follows our location: see locateZone above. Both laptops travel,
  # so a pinned zone means a wrong clock every trip. The clock itself is
  # chrony's job, below.
  #
  # The tzupdate module still provides the unit, its boot and hourly timer, and
  # `time.timeZone = null` at normal priority, which beats the mkDefault below,
  # so the Canary Islands value is only the fallback for when it is turned off.
  services.tzupdate.enable = true;
  systemd.services.tzupdate.script = lib.mkForce (lib.getExe locateZone);
  time.timeZone = lib.mkDefault "Atlantic/Canary";

  # The module only runs at boot and hourly; re-check as soon as a network comes
  # up, which is when a new country first shows.
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "tzupdate-on-connect" ''
        case "$2" in
          up|connectivity-change) systemctl start --no-block tzupdate.service ;;
        esac
      '';
    }
  ];

  # chrony rather than the default systemd-timesyncd. timesyncd is an SNTP
  # client: one server at a time, no source selection, and it only slews, so a
  # clock that came back from suspend well out of step takes a long time to
  # converge. chrony polls several pool servers, drops the ones that disagree,
  # steps an offset that large instead of crawling to it, and resyncs as soon as
  # the link is back. Both laptops suspend constantly and change timezone.
  # The module force-disables timesyncd, so the two never race.
  services.chrony.enable = true;

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "en_GB.UTF-8";
      LC_MONETARY = "es_ES.UTF-8";
      LC_PAPER = "es_ES.UTF-8";
      LC_MEASUREMENT = "es_ES.UTF-8";
    };
  };

  # Spanish (ISO) keyboard: matches the G815LP's physical ES layout.
  # Applies to the TTY console and to greetd/X11; the Hyprland Wayland session
  # sets its own kb_layout in users/kyandesutter/mixins/hyprland.nix.
  console.keyMap = "es";

  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };
}
