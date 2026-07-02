{ pkgs, ... }:
{
  # librepods — AirPods on Linux: Apple's proprietary AACP protocol reimplemented
  # so noise-control modes, battery, ear-detection, etc. work off-Apple. It ships
  # its own Qt system-tray app (the tray icon is hosted by noctalia's `tray`
  # widget), which is the whole UI — no separate bar widget is needed. The daemon
  # is autostarted at login as a systemd user service in mixins/autostart.nix
  # (that file is the home for DE-agnostic login tray apps). g815-only: macOS
  # handles AirPods natively, so this lives in the Linux-only home module.
  #
  # Requires BlueZ `Experimental = true` for the AAP L2CAP channel — already set
  # in modules/nixos/mixins/bluetooth.nix. AirPods must be paired first.
  home.packages = [ pkgs.librepods ];
}
