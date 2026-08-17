{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.dualsense;

  # hid-playstation publishes the lightbar as an RGB multicolor LED and the
  # five player indicators as plain LEDs, all root-owned. udev's MODE/OWNER
  # only reach device nodes, and a sysfs attribute isn't one, so the group
  # write bit is set by a RUN helper the same way the backlight rules do it.
  #
  # This is the only interface that reaches the controller over Bluetooth.
  # dualsensectl writes hidraw output reports directly: they exit 0 and never
  # arrive while hid-playstation owns the device (verified 2026-08-17, a
  # `lightbar 255 0 0` did nothing while the same colour through
  # multi_intensity worked). It stays installed for the triggers, mic and
  # speaker, which have no kernel interface at all.
  ledPerms = pkgs.writeShellScript "dualsense-led-perms" ''
    for attr in brightness multi_intensity; do
      [ -e "$1/$attr" ] || continue
      ${pkgs.coreutils}/bin/chgrp users "$1/$attr"
      ${pkgs.coreutils}/bin/chmod g+w "$1/$attr"
    done
  '';
in
{
  options.kyan.dualsense.enable =
    lib.mkEnableOption "DualSense LED access for the session user" // {
      default = config.kyan.desktop.enable;
    };

  config = lib.mkIf cfg.enable {
    # DRIVERS matches the parent hid device, which is where the playstation
    # driver binds; the LED nodes themselves carry no driver. %p is the
    # devpath, so /sys%p is the directory holding the attributes.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="leds", DRIVERS=="playstation", RUN+="${ledPerms} /sys%p"
    '';
  };
}
