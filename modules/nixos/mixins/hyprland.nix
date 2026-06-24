{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.desktop;

  # sddm-astronaut with the "pixel_sakura" preset, used as-is with no overrides:
  # the bundled pixel_sakura.conf (animated pixel_sakura.gif background + the
  # theme's own colors) applies unchanged.
  sddmAstronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "pixel_sakura";
  };

  # weston.ini for the SDDM Wayland greeter compositor. Mirrors what the NixOS
  # sddm module generates by default — keyboard from the xkb config, the module's
  # libinput defaults — so behaviour is unchanged except that we hand weston a
  # fixed config path while the wrapper below varies only the --drm-device.
  sddmWestonIni = pkgs.writeText "sddm-weston.ini" ''
    [keyboard]
    keymap_layout=${config.services.xserver.xkb.layout}
    keymap_model=${config.services.xserver.xkb.model}
    keymap_options=${config.services.xserver.xkb.options}
    keymap_variant=${config.services.xserver.xkb.variant}

    [libinput]
    enable-tap=true
    left-handed=false
  '';

  # SDDM Wayland greeter compositor launcher.
  #
  # HDMI-A-1 (the desk monitor) is wired to the NVIDIA dGPU, whose DRM card is a
  # different device from the Intel iGPU that drives the internal eDP-1 panel —
  # and the iGPU (boot_vga) is the card weston picks by default. The iGPU cannot
  # see the HDMI port, so to show the login screen on HDMI we must point weston
  # at the card that actually owns the connected HDMI connector:
  #
  #   • HDMI connected -> run weston on that connector's card (the dGPU); the
  #                       greeter appears on the desk monitor.
  #   • HDMI absent    -> no --drm-device, weston falls back to boot_vga (the
  #                       iGPU) and the greeter appears on the internal panel.
  #
  # cardN numbering isn't stable across boots, so we resolve the card fresh from
  # the connected connector's sysfs path every time the greeter starts — which is
  # every boot AND every logout, since SDDM respawns the greeter each time. That
  # makes log-out/log-in behave exactly like a fresh boot.
  sddmGreeterCompositor = pkgs.writeShellScript "sddm-greeter-compositor" ''
    set -u
    drmarg=""
    for status in /sys/class/drm/card*-HDMI*/status; do
      [ -e "$status" ] || continue
      if [ "$(cat "$status")" = "connected" ]; then
        conn=$(basename "$(dirname "$status")")   # e.g. card0-HDMI-A-1
        drmarg="--drm-device=''${conn%%-*}"        # e.g. --drm-device=card0
        break
      fi
    done
    exec ${pkgs.weston}/bin/weston --shell=kiosk -c ${sddmWestonIni} $drmarg
  '';
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
      # Pick the greeter compositor's GPU based on whether HDMI is connected, so
      # the login screen lands on the desk monitor (dGPU) when docked and falls
      # back to the internal panel (iGPU) otherwise. See `sddmGreeterCompositor`.
      wayland.compositorCommand = toString sddmGreeterCompositor;
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
