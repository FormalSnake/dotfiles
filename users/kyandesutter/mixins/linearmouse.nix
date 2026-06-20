{ config, ... }:

{
  xdg.configFile."linearmouse/linearmouse.json".text = builtins.toJSON {
    "$schema" = "https://schema.linearmouse.app/0.11.2";
    schemes = [
      {
        buttons.universalBackForward = true;
        "if".device = {
          category = "mouse";
          productID = "0xc54d";
          productName = "USB Receiver";
          serialNumber = "335D376D3135"; # Logitech USB Receiver (external mouse)
          vendorID = "0x46d";
        };
        pointer.disableAcceleration = true;
        scrolling.reverse = {
          vertical = true;
          horizontal = false;
        };
      }
      {
        "if".device = {
          category = "trackpad";
          productID = "0x343";
          productName = "Apple Internal Keyboard / Trackpad";
          serialNumber = "FM7148604WZNX0QA8+RMZ"; # Apple Internal Trackpad (built-in)
          vendorID = "0x5ac";
        };
        pointer.disableAcceleration = false;
        scrolling.reverse = {
          vertical = true;
          horizontal = true;
        };
      }
    ];
  };
}
