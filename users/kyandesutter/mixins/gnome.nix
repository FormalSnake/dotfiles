{ config, lib, pkgs, osConfig ? { }, ... }:
let
  enabled = ((((osConfig.kyan or { }).desktop or { }).gnome or { }).enable or false);
  systemctl = "${pkgs.systemd}/bin/systemctl";
in
lib.mkIf enabled {
  # Stock theming for the GNOME session (modules/nixos/mixins/gnome.nix). Runs
  # before gnome-shell and the settings daemons, so all of them and every app
  # they spawn read dconf through the gnome-stock lock profile, and GTK finds
  # an empty session.css instead of the Hyprland palette imports.
  systemd.user.services.gnome-stock-session = {
    Unit = {
      Description = "Stock theming for the GNOME session";
      Before = [ "gnome-session-pre.target" "gnome-session-manager.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "gnome-session-pre.target" ];
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = toString (pkgs.writeShellScript "gnome-stock-session" ''
        ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DCONF_PROFILE=gnome-stock
        for dir in "${config.xdg.configHome}"/gtk-3.0 "${config.xdg.configHome}"/gtk-4.0; do
          ${pkgs.coreutils}/bin/rm -f "$dir/session.css"
          ${pkgs.coreutils}/bin/touch "$dir/session.css"
        done
      '');
      ExecStop = "${systemctl} --user unset-environment DCONF_PROFILE";
    };
  };
}
