{ lib, ... }:
{
  # Timezone follows our location: automatic-timezoned watches geoclue2 (already
  # on for the desktop, mixins/geolocation.nix) and hands the zone to
  # systemd-timedated. Both laptops travel, so a pinned zone means a wrong clock
  # every trip. The clock itself was already automatic (systemd-timesyncd is on
  # by default).
  #
  # The service sets `time.timeZone = null` at normal priority, which beats the
  # mkDefault below — so the Canary Islands value is only the fallback if
  # automatic-timezoned is ever turned off. Raising its priority again would
  # abort the build rather than silently pin the zone.
  services.automatic-timezoned.enable = true;
  time.timeZone = lib.mkDefault "Atlantic/Canary";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "en_GB.UTF-8";
      LC_MONETARY = "es_ES.UTF-8";
      LC_PAPER = "es_ES.UTF-8";
      LC_MEASUREMENT = "es_ES.UTF-8";
    };
  };

  # Spanish (ISO) keyboard — matches the G815LP's physical ES layout.
  # Applies to the TTY console and to greetd/X11; the niri Wayland session
  # sets its own kb_layout in users/kyandesutter/mixins/niri.nix.
  console.keyMap = "es";

  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };
}
