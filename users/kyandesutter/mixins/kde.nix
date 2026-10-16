{ config, lib, pkgs, osConfig, ... }:
let
  gaming = osConfig.kyan.gaming.enable;
  hasNvidia = osConfig.kyan.nvidia.enable or false;

  # Same layout and scale as the hl.monitor rules in mixins/hyprland.nix. The
  # panel's connector name follows the driver (eDP-1 or eDP-2 behind the MUX),
  # so it is matched by prefix. VRR stays automatic, like Hyprland's vrr = 3.
  outputArgs = if hasNvidia then ''
    case "$o" in
      HDMI-A-1) set -- position.0,0 scale.1 vrrpolicy.automatic ;;
      eDP-*) set -- position.2560,0 scale.1.25 vrrpolicy.automatic ;;
      *) continue ;;
    esac
  '' else ''
    case "$o" in
      eDP-*) set -- scale.1 ;;
      *) continue ;;
    esac
  '';
in
lib.mkIf osConfig.kyan.desktop.kde.enable (lib.mkMerge [
{
  # Baloo crawls the NTFS game libraries and its extractor leaked 12.9 GB into
  # swap mid-game, filling zram and stalling Forza on I/O. Baloo writes its own
  # keys to baloofilerc, so set the one key instead of owning the file.
  #
  # The edge barrier holds the cursor at a screen edge shared with another
  # output until it is pushed further. KWin rewrites kwinrc itself, so the
  # keys are set rather than the file owned.
  home.activation.kdeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file baloofilerc \
      --group "Basic Settings" --key Indexing-Enabled false
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc \
      --group EdgeBarrier --key EdgeBarrier 0
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc \
      --group EdgeBarrier --key CornerBarrier --type bool false
  '';

  # KWin keeps the output layout in kwinoutputconfig.json, which it rewrites
  # itself, so set it per login through kscreen-doctor rather than owning the
  # file.
  systemd.user.services.kwin-outputs = {
    Unit = {
      Description = "Match the KWin output layout and scale to Hyprland";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=KDE";
      After = [ "plasma-kwin_wayland.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "kwin-outputs";
        runtimeInputs = [ pkgs.kdePackages.libkscreen pkgs.jq ];
        text = ''
          for o in $(kscreen-doctor -j | jq -r '.outputs[] | select(.connected) | .name'); do
            ${outputArgs}
            kscreen-doctor "''${@/#/output.$o.}"
          done
        '';
      });
    };
  };

  # SteamOS keeps "Return to Gaming Mode" on the Plasma desktop; this is the
  # way back to Hyprland (modules/nixos/mixins/kde).
  home.file."Desktop/switch-to-hyprland.desktop".source = config.lib.file.mkOutOfStoreSymlink
    "/run/current-system/sw/share/applications/session-switch-hyprland-uwsm.desktop";
}
(lib.mkIf gaming {
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
})
])
