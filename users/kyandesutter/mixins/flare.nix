{ pkgs, ... }:
{
  # Signal through Flare (GTK4/libadwaita), linked as a secondary device to the
  # phone. It has no calls; the official Signal Desktop is Electron.
  home.packages = [ pkgs.flare-signal ];
}
