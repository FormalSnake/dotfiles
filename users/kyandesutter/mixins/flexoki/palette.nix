# Flexoki palette (github.com/kepano/flexoki, stephango.com/flexoki) as pure Nix
# data. Importable from anywhere (`import ./flexoki/palette.nix`) — home-manager
# mixins and, if ever needed, system modules — so every consumer derives its
# colours from one place. This replaces the old `config.catppuccin.*` surface.
#
# Values are the canonical palette, cross-checked against Ghostty's bundled
# "Flexoki Light"/"Flexoki Dark" ANSI mappings. The `light`/`dark` sub-attrsets
# are the ready-to-use terminal views: the 16 ANSI slots, background/foreground,
# selection, and a base00..base0F map (used to render bat's tmThemes). The rule
# Flexoki follows: the 600-series (darker) accents sit on light backgrounds, the
# 400-series (brighter) accents on dark backgrounds.
rec {
  # Base tones (paper → black).
  base = {
    paper = "#FFFCF0";
    b50 = "#F2F0E5";
    b100 = "#E6E4D9";
    b150 = "#DAD8CE";
    b200 = "#CECDC3";
    b300 = "#B7B5AC";
    b400 = "#9F9D96";
    b500 = "#878580";
    b600 = "#6F6E69";
    b700 = "#575653";
    b800 = "#403E3C";
    b850 = "#343331";
    b900 = "#282726";
    b950 = "#1C1B1A";
    black = "#100F0F";
  };

  # Chromatic accents. `l` is the light-mode stop (600), `d` the dark-mode stop
  # (400) — the two used by the terminal theme; the full ramps are kept for any
  # consumer that wants them.
  accents = {
    red = { d = "#D14D41"; l = "#AF3029"; };
    orange = { d = "#DA702C"; l = "#BC5215"; };
    yellow = { d = "#D0A215"; l = "#AD8301"; };
    green = { d = "#879A39"; l = "#66800B"; };
    cyan = { d = "#3AA99F"; l = "#24837B"; };
    blue = { d = "#4385BE"; l = "#205EA6"; };
    purple = { d = "#8B7EC8"; l = "#5E409D"; };
    magenta = { d = "#CE5D97"; l = "#A02F6F"; };
  };

  # Accent used for window-manager borders / keyboard aura. Flexoki's UI palette
  # doesn't surface purple, so the accent is blue (the colour Flexoki's own site
  # uses for links). `deep` is the more saturated blue-600 stop that reads as blue
  # on washed-out keyboard LEDs (the asus Aura fallback).
  accent = {
    light = accents.blue.l; # #205EA6
    dark = accents.blue.d; # #4385BE
    deep = accents.blue.l; # #205EA6
  };

  dark = {
    bg = base.black;
    fg = base.b200;
    cursor = base.b200;
    selection = base.b800;
    # 0-7 normal, 8-15 bright.
    ansi = [
      base.black
      accents.red.d
      accents.green.d
      accents.yellow.d
      accents.blue.d
      accents.magenta.d
      accents.cyan.d
      base.b500
      base.b700
      accents.red.l
      accents.green.l
      accents.yellow.l
      accents.blue.l
      accents.magenta.l
      accents.cyan.l
      base.b200
    ];
    base16 = {
      base00 = base.black;
      base01 = base.b950;
      base02 = base.b900;
      base03 = base.b700;
      base04 = base.b500;
      base05 = base.b200;
      base07 = base.b100;
      base08 = accents.red.d;
      base09 = accents.orange.d;
      base0A = accents.yellow.d;
      base0B = accents.green.d;
      base0C = accents.cyan.d;
      base0D = accents.blue.d;
      base0E = accents.purple.d;
      base0F = accents.magenta.d;
    };
  };

  light = {
    bg = base.paper;
    fg = base.black;
    cursor = base.black;
    selection = base.b200;
    ansi = [
      base.black
      accents.red.l
      accents.green.l
      accents.yellow.l
      accents.blue.l
      accents.magenta.l
      accents.cyan.l
      base.b600
      base.b300
      accents.red.d
      accents.green.d
      accents.yellow.d
      accents.blue.d
      accents.magenta.d
      accents.cyan.d
      base.b200
    ];
    base16 = {
      base00 = base.paper;
      base01 = base.b50;
      base02 = base.b100;
      base03 = base.b300;
      base04 = base.b600;
      base05 = base.black;
      base07 = base.b900;
      base08 = accents.red.l;
      base09 = accents.orange.l;
      base0A = accents.yellow.l;
      base0B = accents.green.l;
      base0C = accents.cyan.l;
      base0D = accents.blue.l;
      base0E = accents.purple.l;
      base0F = accents.magenta.l;
    };
  };
}
