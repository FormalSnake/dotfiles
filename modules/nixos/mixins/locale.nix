{
  # Canary Islands (matches the macbook / TZ used elsewhere).
  time.timeZone = "Atlantic/Canary";

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
  # Applies to the TTY console and to greetd/X11; the Hyprland Wayland session
  # sets its own kb_layout in users/kyandesutter/mixins/hyprland.nix.
  console.keyMap = "es";

  services.xserver.xkb = {
    layout = "es";
    variant = "";
  };
}
