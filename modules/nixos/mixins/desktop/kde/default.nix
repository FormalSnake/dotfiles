{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.desktop.kde;
  gaming = config.kyan.gaming.enable;
  user = "kyandesutter";

  # SteamOS-style session switching. The switch makes the target the
  # FormalShell greeter's remembered pick and ends the session, so the greeter
  # comes back on it and a password logs straight in; greetd has no one-shot
  # autologin to borrow.
  greeterHome = config.services.formalshell-greeter.stateDir;
  greeterSessions = "${greeterHome}/.local/state/formalshell/sessions";
  sessions = {
    plasma = if gaming then "Gaming Mode" else "Switch to Plasma";
    hyprland-uwsm = "Switch to Hyprland";
  };

  session-switch = pkgs.writeShellApplication {
    name = "session-switch";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      case "''${1:-}" in
        ${lib.concatStringsSep "|" (lib.attrNames sessions)}) ;;
        *) echo "usage: session-switch {${lib.concatStringsSep "|" (lib.attrNames sessions)}}" >&2; exit 2 ;;
      esac
      exec systemctl start --no-block "session-switch@$1.service"
    '';
  };

  # Applied in the session by users/kyandesutter/mixins/desktop/kde.nix.
  steamed = pkgs.callPackage ./steamed-theme.nix { };
  steamClassicWallpaper = pkgs.callPackage ./steam-classic-wallpaper.nix { };

  desktopItems = lib.mapAttrsToList (session: label: pkgs.makeDesktopItem {
    name = "session-switch-${session}";
    desktopName = label;
    exec = "${lib.getExe session-switch} ${session}";
    icon = if session != "plasma" then "hyprland" else if gaming then "steam" else "kde";
    categories = [ "System" ];
  }) sessions;
in
{
  options.kyan.desktop.kde.enable = lib.mkEnableOption
    "a KDE Plasma session next to Hyprland (the gaming desktop on hosts with kyan.gaming, as on SteamOS)";

  config = lib.mkIf cfg.enable {
    # The greeter lists Plasma next to Hyprland.
    services.desktopManager.plasma6.enable = true;
    environment.plasma6.excludePackages = [
      pkgs.kdePackages.elisa
      pkgs.kdePackages.khelpcenter
      pkgs.kdePackages.krdp
    ];

    systemd.services."session-switch@" = {
      description = "Log into the %i session through the greeter";
      serviceConfig.Type = "oneshot";
      scriptArgs = "%i";
      path = [ pkgs.coreutils pkgs.systemd ];
      script = ''
        install -d -o greeter -g greeter -m 0700 ${greeterHome}/.local ${greeterHome}/.local/state \
          ${greeterHome}/.local/state/formalshell ${greeterSessions}
        for f in ${greeterSessions}/${user} ${greeterSessions}/.last; do
          printf '%s\n' "$1" > "$f"
          chown greeter:greeter "$f"
        done
        session=$(loginctl show-user ${user} -p Display --value)
        # The session's user units outlive its logind session, and uwsm will
        # not start Hyprland while graphical-session.target is still active.
        systemctl --user -M ${user}@ stop graphical-session.target || true
        [ -n "$session" ] && loginctl terminate-session "$session"
      '';
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${user}" &&
            [${lib.concatMapStringsSep ", " (s: ''"session-switch@${s}.service"'') (lib.attrNames sessions)}]
              .indexOf(action.lookup("unit")) >= 0 &&
            action.lookup("verb") == "start") {
          return polkit.Result.YES;
        }
      });
    '';

    # graphical-session.target is StopWhenUnneeded, but xdg-desktop-portal and
    # uwsm's fumon hold it with Requisite=, so it outlives plasma-workspace.target
    # at logout. kwin, plasmashell and the rest are PartOf it and keep running,
    # the logind session never finishes closing, and the next uwsm login exits.
    systemd.user.services.plasma-end-graphical-session = {
      description = "Stop graphical-session.target when the Plasma workspace stops";
      partOf = [ "plasma-workspace.target" ];
      wantedBy = [ "plasma-workspace.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${pkgs.systemd}/bin/systemctl --user --no-block stop graphical-session.target";
      };
    };

    environment.systemPackages = [ session-switch steamed steamClassicWallpaper ] ++ desktopItems;
    fonts.packages = [ steamed ];
  };
}
