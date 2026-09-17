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
  # Hash of the palette the running server loaded, so a matugen run that
  # renders the same colours (a shell restart, a re-pick) leaves it alone.
  loadedHash = "${config.xdg.stateHome}/foot/loaded-palette";
  recordPalette = pkgs.writeShellScript "foot-record-palette" ''
    mkdir -p "$(dirname "${loadedHash}")"
    ${pkgs.coreutils}/bin/sha256sum "${matugenIni}" > "${loadedHash}" || true
  '';

  # Matugen post_hook (mixins/dms.nix). The server reads its config once, so a
  # new palette means restarting it, which takes every footclient window down.
  # Before that, each window's cwd and foreground job are captured and reopened
  # afterwards, the job re-run inside an interactive fish so the window drops
  # back to a prompt when it exits. Windows come back on the focused workspace:
  # they all belong to the server process, so nothing maps one to its old spot.
  footReload = pkgs.writeShellApplication {
    name = "foot-reload";
    runtimeInputs = [ pkgs.coreutils pkgs.procps pkgs.systemd config.programs.foot.package ];
    text = ''
      sha256sum --status -c "${loadedHash}" 2>/dev/null && exit 0
      srv=$(systemctl --user show -p MainPID --value foot.service)
      [ "$srv" != 0 ] || exit 0

      # fish single quotes only unescape \\ and \'.
      fishq() { local s=''${1//\\/\\\\}; s=''${s//\'/\\\'}; printf "'%s' " "$s"; }

      dirs=() cmds=()
      for sh in $(pgrep -P "$srv"); do
        fg=$(ps -o tpgid= -p "$sh" | tr -d ' ')
        cwd=$(readlink "/proc/$sh/cwd") || continue
        cmd=""
        # A job's pgid is its first process, the one carrying the command line.
        # A job started by `fish -C` (a window this script reopened) runs before
        # fish takes the terminal, so it stays in fish's group: fall back to
        # the shell's oldest child.
        job=$fg
        [ "$job" != "$sh" ] || job=$(pgrep -o -P "$sh" || true)
        if [ -n "$job" ] && [ -r "/proc/$job/cmdline" ]; then
          cwd=$(readlink "/proc/$job/cwd") || cwd=$(readlink "/proc/$sh/cwd")
          mapfile -d "" args < "/proc/$job/cmdline"
          for a in "''${args[@]}"; do cmd+=$(fishq "$a"); done
        fi
        dirs+=("$cwd") cmds+=("$cmd")
      done

      systemctl --user restart foot.service

      for i in "''${!dirs[@]}"; do
        set -- footclient --no-wait --working-directory="''${dirs[$i]}"
        [ -z "''${cmds[$i]}" ] || set -- "$@" -- ${config.programs.fish.package}/bin/fish -C "''${cmds[$i]}"
        # The server socket shows up a moment after systemd reports it started.
        for _ in $(seq 50); do "$@" 2>/dev/null && break; sleep 0.1; done
      done
    '';
  };
in
{
  programs.foot = {
    enable = true;
    # Windows come from `footclient` (the Hyprland binds in mixins/hyprland.nix),
    # which skips loading fonts and config per window. The trade: every client
    # window lives in this one process and goes down with it.
    server.enable = true;
    settings = {
      main = {
        # The plain Nerd Font family, where the icons keep their drawn 1.5-2
        # cell width; fontconfig pattern syntax. Medium because Regular reads
        # thin at this size.
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
      # The default 1000 lines loses most of an agent session's history.
      scrollback.lines = 10000;
      # Shift+Return as a plain ESC CR, which agent TUIs read as a newline
      # rather than submit. Foot only takes \xNN escapes here, not \r.
      text-bindings."\\x1b\\x0d" = "Shift+Return";
    };
  };

  home.packages = [ footReload ];
  systemd.user.services.foot = {
    Service.ExecStartPre = "${recordPalette}";
    # A rebuild must not close every terminal; the hook owns restarts.
    Unit.X-RestartIfChanged = false;
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
