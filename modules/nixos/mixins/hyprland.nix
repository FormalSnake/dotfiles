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

    # GNOME/GTK desktop plumbing the apps and file manager rely on:
    #   • gvfs:  Nautilus trash, removable-drive / network mounting, MTP.
    #   • tumbler (+ ffmpegthumbnailer): thumbnails, including video, in Nautilus.
    #   • dconf: the settings backend every GTK/GNOME app reads and writes.
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    programs.dconf.enable = true;

    # Nautilus is installed via home-manager (home.packages), so it isn't wrapped
    # with the GNOME GIO module environment the NixOS gnome session would provide.
    # Without gvfs's client module (libgvfsdbus.so) on GIO_EXTRA_MODULES, GIO only
    # knows local backends — so `trash://` is unavailable and Nautilus reports
    # "Trash locations are not supported" when you open Trash. Put gvfs's gio
    # modules on the session search path (this list merges with dconf's, which is
    # already there) so the trash backend (gvfsd-trash) loads and D-Bus-activates.
    environment.sessionVariables.GIO_EXTRA_MODULES = [ "${pkgs.gvfs}/lib/gio/modules" ];

    # UPower: the D-Bus power daemon caelestia reads battery state from. Enable
    # it explicitly — relying on D-Bus auto-activation made battery detection
    # in the caelestia bar flaky.
    services.upower.enable = true;

    # Fonts caelestia/Hyprland expect (Material Symbols, a Nerd Font, emoji).
    # System UI font is Geist; monospace is GeistMono patched with Nerd Font
    # glyphs (terminal/caelestia mono + powerline icons). The rest are general
    # coverage fonts so apps don't fall back to Geist (which carries no emoji,
    # CJK, or serif glyphs) for anything outside basic Latin.
    fonts.packages = with pkgs; [
      material-symbols
      geist-font # "Geist" (sans) + "Geist Mono"
      nerd-fonts.geist-mono # "GeistMono Nerd Font"

      # Broad Latin/symbol coverage + metric-compatible Arial/Times/Courier
      # replacements (lots of web/office content references these by name).
      noto-fonts # "Noto Sans" / "Noto Serif" — huge Unicode coverage
      liberation_ttf # "Liberation Sans/Serif/Mono" (Arial/Times/Courier metrics)
      dejavu_fonts # "DejaVu Sans/Serif/Sans Mono" — last-resort wide coverage

      # CJK (Chinese/Japanese/Korean) so those scripts render instead of tofu.
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif

      # Emoji.
      noto-fonts-color-emoji # "Noto Color Emoji" — color glyphs
      noto-fonts-monochrome-emoji # "Noto Emoji" — monochrome fallback
    ];

    # Make Geist / GeistMono the default sans/monospace for the whole system
    # (GTK apps, anything resolving the generic sans-serif/monospace families).
    # Noto Serif fills the serif generic, and "Noto Color Emoji" is appended to
    # every family so emoji render even in apps that don't consult fontconfig's
    # emoji generic directly (which is why emoji weren't showing up before).
    fonts.fontconfig.defaultFonts = {
      sansSerif = [ "Geist" "Noto Sans" "Noto Color Emoji" ];
      serif = [ "Noto Serif" "Noto Color Emoji" ];
      monospace = [ "GeistMono Nerd Font" "Noto Sans Mono" "Noto Color Emoji" ];
      emoji = [ "Noto Color Emoji" ];
    };

    # Backlight permissions: let the `video` group (which kyandesutter is in)
    # write the panel brightness node so `brightnessctl` works without root.
    # brightnessctl ships its own udev rule, but it hardcodes `/bin/chgrp`,
    # which doesn't exist on NixOS — so spell the rule out with store paths.
    # %S%p is the device's sysfs path; the writable attribute is .../brightness.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video %S%p/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w %S%p/brightness"
    '';

    # External-monitor brightness over DDC/CI (ddcutil). Loads the i2c-dev
    # module, creates the `i2c` group and grants it access to /dev/i2c-*.
    # kyandesutter is added to that group in ../mixins/users.nix.
    hardware.i2c.enable = true;

    environment.systemPackages = with pkgs; [
      brightnessctl
      ddcutil # external-monitor brightness (caelestia uses it)
      playerctl
      wl-clipboard
      grim
      slurp
      ffmpegthumbnailer # video thumbnails for tumbler/Nautilus
    ];
  };
}
