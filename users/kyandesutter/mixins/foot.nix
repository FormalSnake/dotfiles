{ config, lib, pkgs, ... }:
let
  p = import ./flexoki/palette.nix;
  strip = lib.removePrefix "#";
  # Static Flexoki dark: the pre-palette fallback, same role as Hyprland's
  # `general.col`. Foot 1.28 only knows [colors-dark]/[colors-light] and starts
  # in dark; the rendered palette lands in the dark section too, since its
  # `.default` tokens already follow the mode. RRGGBB, no hash. `cursor` takes two
  # values, text colour then cursor colour.
  flexokiColors = {
    background = strip p.dark.bg;
    foreground = strip p.dark.fg;
    cursor = "${strip p.dark.bg} ${strip p.dark.cursor}";
    selection-background = strip p.dark.selection;
    selection-foreground = strip p.dark.fg;
  }
  // lib.listToAttrs (lib.imap0 (i: c: { name = "regular${toString i}"; value = strip c; }) (lib.take 8 p.dark.ansi))
  // lib.listToAttrs (lib.imap0 (i: c: { name = "bright${toString i}"; value = strip c; }) (lib.drop 8 p.dark.ansi));

  matugenIni = "${config.xdg.configHome}/foot/matugen.ini";
in
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        # Same face, size and cut as ghostty (mixins/ghostty.nix); fontconfig
        # pattern syntax, and the Nerd Font family keeps its wide icons.
        font = "GeistMono Nerd Font:size=10:weight=medium";
        shell = "${config.programs.fish.package}/bin/fish";
        # Wallpaper palette, rendered by matugen (see mixins/dms.nix). Parsed
        # after the static [colors-dark] below, so its section wins. A missing
        # include is a config error, hence the seed in home.activation.
        include = matugenIni;
      };
      colors-dark = flexokiColors;
      cursor = {
        style = "block";
        blink = "no";
      };
      mouse.hide-when-typing = "yes";
      # shift+enter as a plain ESC CR, the same helper ghostty binds.
      text-bindings."\\x1b\\r" = "Shift+Return";
    };
  };

  # The matugen output only exists once a wallpaper palette has been rendered;
  # foot refuses to start on a missing include, so seed the file with the
  # Flexoki fallback and let the next matugen run overwrite it.
  home.activation.footMatugenSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${matugenIni}" ]; then
      run cp ${pkgs.writeText "foot-matugen-seed.ini" (lib.generators.toINI { } { colors-dark = flexokiColors; })} "${matugenIni}"
      run chmod 644 "${matugenIni}"
    fi
  '';
}
