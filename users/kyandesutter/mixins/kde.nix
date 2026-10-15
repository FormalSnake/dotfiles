{ config, lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.kyan.desktop.kde.enable {
  # The Steamed global theme and the olive Steam wallpaper (both from
  # modules/nixos/mixins/kde), applied once: after that the look is
  # Plasma's own settings, so changing it in System Settings sticks.
  systemd.user.services.steamed-theme = {
    Unit = {
      Description = "Apply the Steamed theme and wallpaper once";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=KDE";
      After = [ "plasma-plasmashell.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "steamed-theme";
        runtimeInputs = [ pkgs.kdePackages.kconfig pkgs.kdePackages.plasma-workspace ];
        text = ''
          [ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" = Steamed ] && exit 0
          plasma-apply-lookandfeel --apply Steamed
          plasma-apply-wallpaperimage /run/current-system/sw/share/wallpapers/steam-classic.png
        '';
      });
    };
  };

  # SteamOS keeps "Return to Gaming Mode" on the Plasma desktop; this is the
  # way back to Hyprland (modules/nixos/mixins/kde).
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
