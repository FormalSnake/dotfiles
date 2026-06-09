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

  console.keyMap = "us";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
