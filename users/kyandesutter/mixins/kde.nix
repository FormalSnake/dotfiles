{ config, lib, pkgs, osConfig ? { }, ... }:
let
  enabled = (osConfig.kyan or { }).desktop.kde.enable or false;
  gaming = (osConfig.kyan or { }).gaming.enable or false;
  loginExec = cmd: "${pkgs.bash}/bin/bash -lc 'exec ${cmd}'";
  kdeLoginItem = description: cmd: {
    Unit = {
      Description = description;
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=KDE";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec cmd;
    };
  };
in
lib.mkIf enabled {
  # The Plasma session is the gaming desktop: Steam on the main monitor,
  # Discord open on the internal panel. Hyprland keeps its own Discord unit
  # (autostart.nix), minimized to the tray.
  systemd.user.services = {
    discord-kde = kdeLoginItem "Discord" "Discord";
  } // lib.optionalAttrs gaming {
    steam = kdeLoginItem "Steam" "steam";
  };

  # SteamOS keeps "Return to Gaming Mode" on the Plasma desktop; this is the
  # way back to Hyprland (modules/nixos/mixins/kde.nix).
  home.file."Desktop/switch-to-hyprland.desktop".source = config.lib.file.mkOutOfStoreSymlink
    "/run/current-system/sw/share/applications/session-switch-hyprland-uwsm.desktop";

  # Discord opens on the internal panel. KWin numbers screens by its own
  # output order, so screen 1 is the second output it enumerated.
  # Rule type 3 is "Apply Initially": Discord can still be dragged elsewhere.
  xdg.configFile."kwinrulesrc".text = lib.generators.toINI { } {
    General = {
      count = 1;
      rules = "discord-panel";
    };
    discord-panel = {
      Description = "Discord on the internal panel";
      wmclass = "discord";
      wmclassmatch = 1;
      screen = 1;
      screenrule = 3;
    };
  };
}
