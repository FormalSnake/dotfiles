{ config, lib, ... }:
{
  # Bluetooth (BlueZ). Gated on the desktop profile since it's the laptop's
  # graphical stack that needs it. noctalia's shell has no daemon of its own —
  # its bluetooth widget / `noctalia msg bluetooth-toggle` talk to BlueZ over
  # D-Bus, so without `hardware.bluetooth` there is no `org.bluez` service to
  # query and the toggle does nothing. Enabling this is what makes bluetooth
  # appear/work in noctalia.
  config = lib.mkIf config.kyan.desktop.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        # Show battery level for connected devices (earbuds, controllers) and
        # prefer fast, low-latency reconnection.
        Experimental = true;
        FastConnectable = true;
      };
    };
  };
}
