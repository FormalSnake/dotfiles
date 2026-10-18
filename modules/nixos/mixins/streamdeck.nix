{ config, lib, pkgs, ... }:
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
    # (users/kyandesutter/mixins/streamdeck.nix) runs as. The tag only works
    # from a file that sorts before 73-seat-late.rules, so this can't go in
    # services.udev.extraRules (99-local.rules).
    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/70-streamdeck.rules" ''
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
      '')
    ];
  };
}
