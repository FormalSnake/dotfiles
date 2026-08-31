{ lib, ... }:
{
  # Timezone follows our location: automatic-timezoned watches geoclue2 (already
  # on for the desktop, mixins/geolocation.nix) and hands the zone to
  # systemd-timedated. Both laptops travel, so a pinned zone means a wrong clock
  # every trip. The clock itself is chrony's job, below.
  #
  # The service sets `time.timeZone = null` at normal priority, which beats the
  # mkDefault below, so the Canary Islands value is only the fallback for when
  # automatic-timezoned is turned off. Raising its priority again aborts the
  # build rather than silently pinning the zone.
  services.automatic-timezoned.enable = true;
  time.timeZone = lib.mkDefault "Atlantic/Canary";

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
