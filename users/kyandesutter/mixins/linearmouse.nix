{ config, ... }:

{
  xdg.configFile."linearmouse/linearmouse.json".text = builtins.toJSON {
    "$schema" = "https://app.linearmouse.org/schema/0.7.2";
    schemes = [
      {
        pointer = {
          acceleration = "unset";
          speed = "unset";
        };
        scrolling.reverse = {
          vertical = true;
          horizontal = false;
        };
      }
    ];
  };
}
