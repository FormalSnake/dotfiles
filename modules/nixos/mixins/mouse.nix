{ config, lib, ... }:
{
  # Logitech MX Master 3S (046d:b034 over Bluetooth). niri binds keys, never
  # mouse buttons, so the three thumb buttons are remapped in the kernel keymap
  # to keys niri can bind. The values on the right are HID usages the buttons
  # report as MSC_SCAN, read off the device with evtest.
  #
  # The gesture button becomes Meta, so it IS niri's Mod: every Mod bind is
  # reachable with the mouse alone (see the wheel binds in
  # users/kyandesutter/mixins/niri.nix). Back/forward become F13/F14, which no
  # physical key here emits, and drive column focus; niri's own scroll axis
  # can't take the thumb wheel instead, because a wheel bind with no modifier
  # locks up the vertical wheel for applications (niri-wm/niri#1584).
  #
  # niri binds those two as XF86Tools and XF86Launch5, not F13/F14: binds match
  # keysyms, and that is what the es layout puts on those keycodes.
  #
  # systemd's 60-evdev.rules runs the hwdb lookup and the `keyboard` builtin on
  # every event device with no ID_INPUT_KEY gate, so a pointer-only device is
  # remapped at device-add, before niri opens it. The match is deliberately cut
  # before the `-e...` capability suffix, which changes once the remap lands.
  options.kyan.mouse.enable = lib.mkEnableOption "MX Master 3S thumb button remap" // {
    default = config.kyan.desktop.enable;
  };

  config = lib.mkIf config.kyan.mouse.enable {
    services.udev.extraHwdb = ''
      evdev:input:b0005v046DpB034*
        KEYBOARD_KEY_90004=f13
        KEYBOARD_KEY_90005=f14
        KEYBOARD_KEY_90006=leftmeta
    '';
  };
}
