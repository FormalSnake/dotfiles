{ config, lib, ... }:
{
  # Bluetooth (BlueZ). Defaults to the desktop profile since it's the laptop's
  # graphical stack that needs it, but is its own flag so a host can override.
  # noctalia's shell has no daemon of its own — its bluetooth widget /
  # `noctalia msg bluetooth-toggle` talk to BlueZ over D-Bus, so without
  # `hardware.bluetooth` there is no `org.bluez` service to query and the toggle
  # does nothing. Enabling this is what makes bluetooth appear/work in noctalia.
  options.kyan.bluetooth.enable = lib.mkEnableOption "Bluetooth (BlueZ)" // {
    default = config.kyan.desktop.enable;
  };

  config = lib.mkIf config.kyan.bluetooth.enable {
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
