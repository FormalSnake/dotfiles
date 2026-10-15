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

  # The 2003 Steam / GoldSrc VGUI look: colour scheme, Plasma style, Aurorae
  # window decoration and the bitmap Tahoma, as one global theme. Applied in
  # the session by users/kyandesutter/mixins/kde.nix.
  steamed = pkgs.stdenvNoCC.mkDerivation {
    pname = "steamed-kde-theme";
    version = "0-unstable-2026-01-24";
    src = pkgs.fetchFromGitHub {
      owner = "UNATCO-JCDenton";
      repo = "Steamed";
      rev = "14e8a1c0db188870ab3ac2059dbf941fad9c3065";
      hash = "sha256-DonoMblcHEZ0oYdWdq78HeZTctf/O7pT6TU7Ce+7osM=";
    };
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp -r color-schemes aurorae plasma $out/share/
      cp fonts/WineTahomaBit.ttf $out/share/fonts/truetype/
    '';
  };

  # Valve's own Steam cog wallpaper (from the SteamOS 1.0 archive), recoloured
  # from Steam blue to the VGUI olive of the theme above.
  steamClassicWallpaper = pkgs.runCommand "steam-classic-wallpaper" {
    nativeBuildInputs = [ pkgs.dpkg pkgs.imagemagick ];
    src = pkgs.fetchurl {
      url = "https://repo.steampowered.com/steamos/pool/main/v/valve-wallpapers/valve-wallpapers_0.7%2Bbsos2_all.deb";
      hash = "sha256-D8riXwbAfDAEkXZEs085OD6Wln5WVTPvn3CxCL2o6qM=";
    };
  } ''
    dpkg-deb -x $src deb
    mkdir -p $out/share/wallpapers
    magick deb/usr/share/backgrounds/cog.png -colorspace Gray -auto-level \
      +level-colors "#1f2419","#5a6a50" $out/share/wallpapers/steam-classic.png
  '';

  desktopItems =lib.mapAttrsToList (session: label: pkgs.makeDesktopItem {
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

    environment.systemPackages = [ session-switch steamed steamClassicWallpaper ] ++ desktopItems;
    fonts.packages = [ steamed ];
  };
}
