{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.desktop;
in
{
  options.kyan.desktop.enable = lib.mkEnableOption "Hyprland desktop (system side)";

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true; # session managed by uwsm (clean env / systemd target)
      xwayland.enable = true;
    };

    # xdg portals: hyprland portal + gtk fallback (file pickers, screenshare).
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # greetd + tuigreet: minimal login that launches the Hyprland uwsm session.
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };

    # polkit agent + secrets/keyring so GUI auth prompts and saved logins work.
    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;

    # Fonts caelestia/Hyprland expect (Material Symbols, a Nerd Font, emoji).
    fonts.packages = with pkgs; [
      material-symbols
      nerd-fonts.caskaydia-cove
      nerd-fonts.blex-mono
      noto-fonts
      noto-fonts-color-emoji
    ];

    environment.systemPackages = with pkgs; [
      brightnessctl
      ddcutil # external-monitor brightness (caelestia uses it)
      playerctl
      wl-clipboard
      grim
      slurp
    ];
  };
}
