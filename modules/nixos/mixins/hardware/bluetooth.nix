{ config, lib, ... }:
{
  # Bluetooth (BlueZ). Defaults to the desktop profile since it's the laptop's
  # graphical stack that needs it, but is its own flag so a host can override.
  # DMS has no bluetooth daemon of its own: its bluetooth widget talks to
  # BlueZ over D-Bus, so without `hardware.bluetooth` there is no `org.bluez`
  # service to query and the widget does nothing. Enabling this is what makes
  # bluetooth appear/work in DMS.
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
      # BlueZ 5.86 refuses HID on a classic-only device that bonded without
      # MITM protection: `hidp_add_connection() Rejected connection from
      # !bonded device`. The DualSense pairs Just Works, so it connects but
      # never gets an input device. Cost is an unauthenticated classic HID link
      # can be spoofed (CVE-2023-45866 keystroke injection) while the adapter
      # is connectable.
      input.General.ClassicBondedOnly = false;
    };
  };
}
