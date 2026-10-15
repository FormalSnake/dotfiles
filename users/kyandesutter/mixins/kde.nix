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

  # Baloo crawls the NTFS game libraries and its extractor leaked 12.9 GB into
  # swap mid-game, filling zram and stalling Forza on I/O. Baloo writes its own
  # keys to baloofilerc, so set the one key instead of owning the file.
  home.activation.disableBaloo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file baloofilerc \
      --group "Basic Settings" --key Indexing-Enabled false
  '';

  # Adaptive sync on every connected output. KWin keeps the policy in
  # kwinoutputconfig.json, which it rewrites itself, so set it per login
  # through kscreen-doctor rather than owning the file.
  systemd.user.services.kwin-vrr = {
    Unit = {
      Description = "Set adaptive sync to automatic on every output";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=KDE";
      After = [ "plasma-kwin_wayland.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "kwin-vrr";
        runtimeInputs = [ pkgs.kdePackages.libkscreen pkgs.jq ];
        text = ''
          for o in $(kscreen-doctor -j | jq -r '.outputs[] | select(.connected) | .name'); do
            kscreen-doctor "output.$o.vrrpolicy.automatic"
          done
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
