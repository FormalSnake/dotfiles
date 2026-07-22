{ config, lib, ... }:
{
  # System location via geoclue2, WiFi-BSSID positioning against beaconDB
  # (nixpkgs' default geoProviderUrl — no API key). DMS's Go core prefers
  # GeoClue2 over D-Bus and only IP-geolocates when the service is absent;
  # Firefox-family browsers (Zen) consume it natively via
  # geo.provider.use_geoclue. Chromium/Helium can't: Chromium has no Linux
  # location provider and ungoogled builds dead-end the Google endpoint.
  #
  # Apps not allowlisted here (the module pre-authorizes firefox) get a Yes/No
  # prompt from the geoclue demo agent, delivered as an actionable notification
  # through DMS's notifd. submitData stays off: without a GPS source,
  # submissions derived from beaconDB's own answers are circular.
  config = lib.mkIf config.kyan.desktop.enable {
    services.geoclue2 = {
      enable = true;
      appConfig = {
        dms = {
          isAllowed = true;
          isSystem = false;
        };
        zen = {
          isAllowed = true;
          isSystem = false;
        };
      };
    };
  };
}
