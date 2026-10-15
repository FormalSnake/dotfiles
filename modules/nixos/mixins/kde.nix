{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.desktop.kde;
  user = "kyandesutter";

  # SteamOS-style session switching. SDDM only reads its config when it
  # starts, and autologin runs once per start, so the switch writes a one-shot
  # autologin file, restarts SDDM (which ends the current session) and removes
  # the file once SDDM has logged into the target. The greeter is back for the
  # next logout. The file lives in /run behind a symlink in /etc/sddm.conf.d,
  # so a switch cut off by a power loss cannot autologin the next boot; SDDM
  # skips the dangling link.
  sessions = {
    plasma = "Gaming Mode";
    hyprland-uwsm = "Switch to Hyprland";
  };
  switchConf = "/run/sddm-session-switch.conf";

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

  desktopItems = lib.mapAttrsToList (session: label: pkgs.makeDesktopItem {
    name = "session-switch-${session}";
    desktopName = label;
    exec = "${lib.getExe session-switch} ${session}";
    icon = if session == "plasma" then "steam" else "hyprland";
    categories = [ "System" ];
  }) sessions;
in
{
  options.kyan.desktop.kde.enable = lib.mkEnableOption
    "a KDE Plasma session next to Hyprland, the gaming desktop (as on SteamOS)";

  config = lib.mkIf cfg.enable {
    # SDDM stays the greeter and lists Plasma next to Hyprland.
    services.desktopManager.plasma6.enable = true;
    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      elisa
      khelpcenter
      krdp
    ];

    systemd.services."session-switch@" = {
      description = "Log into the %i session through SDDM";
      serviceConfig.Type = "oneshot";
      scriptArgs = "%i";
      path = [ pkgs.coreutils pkgs.systemd ];
      script = ''
        printf '[Autologin]\nUser=${user}\nSession=%s.desktop\n' "$1" > ${switchConf}
        systemctl restart display-manager.service
        sleep 20
        rm -f ${switchConf}
      '';
    };
    environment.etc."sddm.conf.d/zz-session-switch.conf".source = switchConf;

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

    environment.systemPackages = [ session-switch ] ++ desktopItems;
  };
}
