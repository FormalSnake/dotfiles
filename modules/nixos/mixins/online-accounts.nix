{ config, lib, pkgs, ... }:
{
  # GNOME Online Accounts + Evolution Data Server, wired purely as a
  # credential/sync backend for DankCalendar's `evolution` provider (see
  # users/kyandesutter/mixins/dankcal.nix). GOA does the Google login with
  # GNOME's own registered OAuth client — no personal Google Cloud project and
  # nothing published, which is the only live route left when a Workspace admin
  # has disabled the secret iCal address. GOA feeds the calendar to EDS; dcal
  # reads EDS over D-Bus. Both daemons are D-Bus-activated per user session, so
  # no extra autostart is needed; the token is stored in gnome-keyring (already
  # enabled in mixins/niri.nix).
  #
  # gnome-online-accounts-gtk is the standalone account-add window (avoids
  # pulling in all of gnome-control-center). Run it once to sign in, tick
  # Calendar, then `dcal account add evolution`:
  #   gnome-online-accounts-gtk
  config = lib.mkIf config.kyan.desktop.enable {
    services.gnome.gnome-online-accounts.enable = true;
    services.gnome.evolution-data-server.enable = true;

    environment.systemPackages = [ pkgs.gnome-online-accounts-gtk ];
  };
}
