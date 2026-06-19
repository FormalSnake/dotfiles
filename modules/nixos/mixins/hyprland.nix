{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.desktop;

  # The SDDM greeter runs as the unprivileged `sddm` user before any user logs
  # in, so it can't read the noctalia shell's wallpaper/theme. Instead we bake
  # both into the theme statically, mirroring what noctalia is configured with in
  # ../../../users/kyandesutter/mixins/noctalia.nix:
  #   • wallpaper → wallpapers/storm.jpg
  #   • theme     → Catppuccin (Mocha) dark
  # If either of those changes there, update them here too.

  # In-repo wallpaper, copied to the store as its own path. file:// so the
  # theme's QML (Main.qml) loads it as an absolute local file rather than
  # resolving it relative to the theme directory.
  loginWallpaper = "file://${../../../users/kyandesutter/wallpapers/storm.jpg}";

  # Catppuccin Mocha palette (subset used below). Mauve is the accent.
  mocha = {
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
    surface0 = "#313244";
    surface1 = "#45475a";
    text = "#cdd6f4";
    subtext0 = "#a6adc8";
    overlay0 = "#6c7086";
    mauve = "#cba6f7";
    red = "#f38ba8";
  };

  # sddm-astronaut, "pixel_sakura" layout, themed with the wallpaper + Mocha.
  # `themeConfig` is written to pixel_sakura.conf.user and merged over the
  # bundled pixel_sakura.conf, so unset keys keep their upstream defaults.
  sddmAstronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "pixel_sakura";
    themeConfig = {
      # Use our wallpaper instead of the bundled pixel_sakura.gif, cropped to
      # fill the screen. PartialBlur softens the area behind the login form so
      # the Mocha text stays legible over an arbitrary photo.
      Background = loginWallpaper;
      CropBackground = "true";
      DimBackground = "0.0";
      PartialBlur = "true";

      # Mocha colors.
      HeaderTextColor = mocha.text;
      DateTextColor = mocha.subtext0;
      TimeTextColor = mocha.text;

      BackgroundColor = mocha.base;
      FormBackgroundColor = mocha.mantle;
      DimBackgroundColor = mocha.crust;

      LoginFieldBackgroundColor = mocha.surface0;
      PasswordFieldBackgroundColor = mocha.surface0;
      LoginFieldTextColor = mocha.text;
      PasswordFieldTextColor = mocha.text;
      UserIconColor = mocha.subtext0;
      PasswordIconColor = mocha.subtext0;

      PlaceholderTextColor = mocha.overlay0;
      WarningColor = mocha.red;

      LoginButtonTextColor = mocha.base;
      LoginButtonBackgroundColor = mocha.mauve;
      SystemButtonsIconsColor = mocha.subtext0;
      SessionButtonTextColor = mocha.subtext0;
      VirtualKeyboardButtonTextColor = mocha.subtext0;

      DropdownTextColor = mocha.text;
      DropdownSelectedBackgroundColor = mocha.surface1;
      DropdownBackgroundColor = mocha.surface0;

      HighlightTextColor = mocha.text;
      HighlightBackgroundColor = mocha.mauve;
      HighlightBorderColor = "transparent";

      HoverUserIconColor = mocha.mauve;
      HoverPasswordIconColor = mocha.mauve;
      HoverSystemButtonsIconsColor = mocha.mauve;
      HoverSessionButtonTextColor = mocha.mauve;
      HoverVirtualKeyboardButtonTextColor = mocha.mauve;
    };
  };
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

    # SDDM (Qt6, Wayland) with the Keyitdev "sddm-astronaut" theme. SDDM lists the
    # Hyprland uwsm session from /run/current-system/sw/share/wayland-sessions, so
    # logging in launches the same hyprland-uwsm.desktop session greetd used to.
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      # Qt runtime the theme's QML needs (svg, multimedia for the animated
      # background, the on-screen virtual keyboard).
      extraPackages = with pkgs.kdePackages; [
        qtsvg
        qtmultimedia
        qtvirtualkeyboard
      ];
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

    # UPower: the D-Bus power daemon noctalia's battery service reads battery
    # state from. Enable it explicitly — relying on D-Bus auto-activation made
    # battery detection in the bar flaky.
    services.upower.enable = true;

    # Fonts noctalia/Hyprland expect (Material Symbols, a Nerd Font, emoji).
    # System UI font is Geist; monospace is GeistMono patched with Nerd Font
    # glyphs (terminal mono + powerline icons). The rest are general coverage
    # fonts so apps don't fall back to Geist (which carries no emoji, CJK, or
    # serif glyphs) for anything outside basic Latin.
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
      # SDDM "sddm-astronaut" theme (pixel_sakura layout, themed with our
      # wallpaper + Catppuccin Mocha — see the `sddmAstronaut` let-binding).
      # Installed into the system profile so SDDM finds it under
      # .../share/sddm/themes/sddm-astronaut-theme.
      sddmAstronaut

      brightnessctl
      ddcutil # external-monitor brightness (used by the monitor-brightness keybind script; also noctalia's optional [brightness] enable_ddcutil backend)
      playerctl
      wl-clipboard
      grim
      slurp
      ffmpegthumbnailer # video thumbnails for tumbler/Nautilus
    ];
  };
}
