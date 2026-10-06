{ lib, osConfig ? { }, ... }:
let
  # nix-darwin leaves networking.hostName null, so the sole darwin host falls
  # back to its flake attribute (same rule as mixins/claude-code.nix).
  osHostName = (osConfig.networking or { }).hostName or null;
  host = if osHostName == null || osHostName == "" then "macbook" else osHostName;

  # Values are right-aligned to this width; the box borders are sized from it.
  width = 24;
  bar = lib.concatStrings (lib.genList (_: "━") (width + 13));

  pad = n: v: "{${v}>${toString n}}";

  row = { type, label, value, ... }@extra:
    builtins.removeAttrs (extra // {
      inherit type;
      key = "┃   ${label}${lib.fixedWidthString (7 - lib.stringLength label) " " ""}";
      format = "${value} ┃";
    }) [ "label" "value" ];
in
{
  programs.fastfetch.settings = {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

    logo = {
      type = "file";
      source = ./logos + "/${host}.txt";
      color."1" = "white";
      padding = { top = 1; left = 1; right = 2; };
    };

    display = {
      separator = "  ";
      color = "white";
    };

    modules = [
      "break"
      { type = "custom"; key = "┏${bar}┓"; }
      (row { type = "command";  label = "user";   value = pad width "1"; text = "echo $USER"; })
      (row { type = "custom";   label = "host";   value = lib.fixedWidthString width " " host; })
      (row { type = "os";       label = "distro"; value = pad width "name"; })
      (row { type = "kernel";   label = "kernel"; value = pad width "release"; })
      (row { type = "wm";       label = "wm";     value = pad width "pretty-name"; })
      (row { type = "shell";    label = "shell";  value = pad width "pretty-name"; })
      (row { type = "uptime";   label = "uptime"; value = "${pad 15 "days"}d ${pad 2 "hours"}h ${pad 2 "minutes"}m"; })
      (row { type = "memory";   label = "mem";    value = "${pad 12 "used"} / ${pad 9 "total"}"; })
      (row { type = "packages"; label = "pkgs";   value = pad width "all"; })
      { type = "custom"; key = "┗${bar}┛"; }
      "break"
    ];
  };
}
