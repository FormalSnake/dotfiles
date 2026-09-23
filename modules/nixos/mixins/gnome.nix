{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.desktop.gnome;
in
{
  options.kyan.desktop.gnome.enable = lib.mkEnableOption
    "a stock GNOME session next to Hyprland, for checking apps against default Adwaita";

  config = lib.mkIf cfg.enable {
    # Shell, session and settings daemons only. SDDM stays the greeter and
    # lists GNOME next to Hyprland; the apps come from home-manager as before.
    services.desktopManager.gnome.enable = true;
    services.gnome.core-apps.enable = false;
    environment.gnome.excludePackages = [ pkgs.gnome-tour pkgs.gnome-user-docs ];

    # core-shell and core-os-services extras nobody asked for: first-login
    # wizard, DLNA and remote desktop servers, the file indexer (heavy on the
    # e1504g), and ibus, whose GTK_IM_MODULE would leak into Hyprland too.
    services.gnome.gnome-initial-setup.enable = false;
    services.gnome.gnome-browser-connector.enable = false;
    services.gnome.gnome-remote-desktop.enable = false;
    services.gnome.gnome-user-share.enable = false;
    services.gnome.rygel.enable = false;
    services.gnome.localsearch.enable = false;
    services.gnome.tinysparql.enable = false;
    services.dleyna.enable = false;
    i18n.inputMethod.enable = false;

    # The gnome module turns the demo agent off because gnome-shell brings its
    # own, but FormalShell's location under Hyprland depends on it. In GNOME,
    # gnome-shell registers later and replaces it as the user's agent.
    services.geoclue2.enableDemoAgent = lib.mkForce true;

    # DCONF_PROFILE for the GNOME session (set by gnome-stock-session in
    # users/kyandesutter/mixins/gnome.nix). Locking a key with no value in
    # the locking database makes dconf skip the user db for it, so GSettings
    # falls through to the schema default (Adwaita, Adwaita Sans, the stock
    # cursor) instead of what FormalShell wrote to the shared user db.
    # color-scheme and accent-color stay writable so GNOME's own toggles work.
    programs.dconf.profiles.gnome-stock.databases = [
      {
        locks = map (key: "/org/gnome/desktop/interface/${key}") [
          "gtk-theme"
          "icon-theme"
          "cursor-theme"
          "cursor-size"
          "font-name"
          "document-font-name"
          "monospace-font-name"
        ] ++ [ "/org/gnome/desktop/wm/preferences/button-layout" ];
      }
    ];
  };
}
