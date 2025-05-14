{
  config,
  pkgs,
  lib,
  ...
}: {
  # Host-specific dock settings
  system.defaults.dock.persistent-apps = [
    "/Applications/Brave Browser.app"
    "/System/Applications/Calendar.app"
    "/Applications/Equibop.app"
    "/Applications/Spotify.app"
    "/Applications/Ghostty.app"
  ];

  # Any host-specific overrides can be placed here
  networking.hostName = "macbook";
  
  # You can override any module settings here
}