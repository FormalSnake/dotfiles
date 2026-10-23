{ config, lib, pkgs, osConfig ? { }, ... }:
let
  # nix-darwin leaves networking.hostName null, so the sole darwin host falls
  # back to its flake attribute (same rule as mixins/dev/claude-code.nix).
  osHostName = (osConfig.networking or { }).hostName or null;
  host = if osHostName == null || osHostName == "" then "macbook" else osHostName;

  # Values are right-aligned to this width; the box borders are sized from it.
  width = 24;
  bar = lib.concatStrings (lib.genList (_: "━") (width + 13));

  pad = n: v: "{${v}>${toString n}}";

  # fastfetch can't strip "Intel(R) Core(TM)" or "Max-Q / Mobile" and `>`
  # truncates instead, so known hosts get fixed labels. The g815's iGPU only idles behind the MUX,
  # so its GPU row is the RTX alone.
  hardware = {
    macbook = { cpu = "M1 Pro"; gpu = "M1 Pro"; };
    g815 = { cpu = "Core Ultra 9 275HX"; gpu = "GeForce RTX 5070"; };
    e1504g = { cpu = "Core i3-N305"; gpu = "UHD Graphics"; };
  };
  hwRow = type: label:
    if hardware ? ${host}
    then row { type = "custom"; inherit label; value = lib.fixedWidthString width " " hardware.${host}.${type}; }
    else row { inherit type label; value = pad width "name"; };

  row = { type, label, value, ... }@extra:
    builtins.removeAttrs (extra // {
      inherit type;
      key = "┃   ${label}${lib.fixedWidthString (7 - lib.stringLength label) " " ""}";
      format = "${value} ┃";
    }) [ "label" "value" ];

  # The packages module validates its cache with three `nix-store --query`
  # calls through the daemon on every run, which stall for seconds while the
  # daemon is busy (the g815 builds for the e1504g). The row shows the last
  # count instead, refreshed in the background after fastfetch has drawn.
  pkgsCount = "${config.xdg.cacheHome}/fastfetch/pkgs-count";
  refreshPkgsCount = pkgs.writeShellScript "fastfetch-pkgs-count" ''
    n=$(${lib.getExe config.programs.fastfetch.package} -c none -s packages --format json \
      | ${lib.getExe pkgs.jq} -r '.[0].result.all') || exit 0
    mkdir -p "${config.xdg.cacheHome}/fastfetch"
    tmp=$(mktemp "${pkgsCount}.XXXXXX") && echo "$n" > "$tmp" && mv "$tmp" "${pkgsCount}"
  '';
in
{
  # Interactive shells only, and not the ones an agent opens for itself.
  programs.fish.interactiveShellInit = lib.mkAfter ''
    if not set -q CLAUDECODE
      fastfetch
      ${refreshPkgsCount} &
      disown
    end
  '';

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
      (row { type = "command";  label = "user";   value = pad width "1"; text = "echo $USER@${host}"; })
      (row { type = "os";       label = "distro"; value = pad width "name"; })
      (row { type = "kernel";   label = "kernel"; value = pad width "release"; })
      (row { type = "wm";       label = "wm";     value = pad width "pretty-name"; })
      (row { type = "shell";    label = "shell";  value = pad width "pretty-name"; })
      (row { type = "uptime";   label = "uptime"; value = "${pad 15 "days"}d ${pad 2 "hours"}h ${pad 2 "minutes"}m"; })
      (hwRow "cpu" "cpu")
      (hwRow "gpu" "gpu")
      (row { type = "memory";   label = "mem";    value = "${pad 12 "used"} / ${pad 9 "total"}"; })
      (row { type = "command";  label = "pkgs";   value = pad width "1"; text = "cat ${pkgsCount} 2>/dev/null || echo -"; })
      { type = "custom"; key = "┗${bar}┛"; }
      "break"
    ];
  };
}
