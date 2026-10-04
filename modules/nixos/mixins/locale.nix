{ lib, pkgs, ... }:
{
  # Timezone follows our location: tzupdate geolocates the public IP and hands
  # the zone to systemd-timedated. Both laptops travel, so a pinned zone means a
  # wrong clock every trip. The clock itself is chrony's job, below.
  #
  # Not automatic-timezoned: it goes through geoclue and beaconDB, which knows
  # few access points outside Europe and then answers from DB-IP Lite. In
  # Marrakesh (2026-10-04) that put a Maroc Telecom IP near Heathrow, so the
  # zone flipped between Europe/London and Africa/Casablanca on every reconnect.
  #
  # The module sets `time.timeZone = null` at normal priority, which beats the
  # mkDefault below, so the Canary Islands value is only the fallback for when
  # tzupdate is turned off.
  services.tzupdate.enable = true;
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
