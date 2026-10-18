{ config, lib, ... }:
let
  cfg = config.kyan.streamdeck;
in
{
  options.kyan.streamdeck.enable =
    lib.mkEnableOption "Elgato Stream Deck access for the session user" // {
      default = config.kyan.desktop.enable;
    };

  config = lib.mkIf cfg.enable {
    # The hidraw nodes are root-only by default. uaccess hands them to whoever
    # owns the active seat, which is what the streamdeck-keys user service
    # (users/kyandesutter/mixins/streamdeck.nix) runs as.
    services.udev.extraRules = ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
    '';
  };
}
