{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.kyan.desktop;

  # dms binary (same package the home-manager user service runs), used by the
  # lock-before-sleep hook below.
  dms = inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Lock the session before the machine suspends. Runs as kyandesutter and talks
  # to the running DMS daemon over its IPC socket in the user's XDG_RUNTIME_DIR.
  # `ipc call lock lock` shows DMS's lock screen without suspending — the
  # suspend itself is driven by systemd-suspend.service, ordered after this via
  # sleep.target.
  #
  # Unlike noctalia's per-Wayland-display socket (which needed a glob-and-guess
  # dance), DMS's socket lives directly in the user's XDG_RUNTIME_DIR — the `dms`
  # CLI finds it itself once that env var is set, no $WAYLAND_DISPLAY needed.
  # Always exit 0: a lock failure (no session, DMS down) must never block the
  # suspend.
  lockBeforeSleep = pkgs.writeShellScript "lock-before-sleep" ''
    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    ${pkgs.coreutils}/bin/timeout 10 ${dms}/bin/dms ipc call lock lock || true
    exit 0
  '';

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
  options.kyan.desktop.enable = lib.mkEnableOption "niri desktop (system side)";

  config = lib.mkIf cfg.enable {
    # niri session (nixpkgs module): installs the package, registers the
    # Wayland session for SDDM, wires portals (gnome for screencast + gtk
    # fallback) and gnome-keyring. niri is systemd-native (niri-session →
    # niri.service, BindsTo graphical-session.target) — no uwsm.
    programs.niri.enable = true;

    # xdg portals: niri routes screencast through xdg-desktop-portal-gnome and
    # the rest through gtk (programs.niri wires the packages; this pins the
    # routing). gnome-keyring's Secret portal is gated `UseIn=gnome`, and
    # $XDG_CURRENT_DESKTOP=niri bypasses it — keep the explicit pin so
    # sandboxed Flatpaks can reach the keyring.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };

    # SDDM (Qt6, Wayland) with the Keyitdev "sddm-astronaut" theme. SDDM lists
    # the niri session (niri.desktop, Exec=niri-session — installed by
    # programs.niri) from /run/current-system/sw/share/wayland-sessions.
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

    # Lock on suspend. logind's default HandleLidSwitch=suspend goes straight to
    # s2idle with no lock, so closing the lid used to resume into an unlocked
    # session. This oneshot raises DMS's lock screen and is ordered Before
    # sleep.target, so every suspend path — lid close, idle, and the
    # SUPER+SHIFT+Escape keybind — resumes on the lock screen. (The keybind's
    # `lock-and-suspend` still locks on its own too; this makes the lid path
    # match.)
    systemd.services.lock-before-sleep = {
      description = "Lock the DMS session before sleep";
      before = [ "sleep.target" ];
      wantedBy = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = config.users.users.kyandesutter.name;
        ExecStart = toString lockBeforeSleep;
        # Belt-and-braces: the script already exits 0 and times out its IPC call,
        # but suspend waits on this oneshot — cap it so sleep is never held up.
        TimeoutStartSec = 15;
      };
    };

    # GNOME/GTK desktop plumbing the apps and file manager rely on:
    #   • gvfs + wsdd: Nautilus trash, removable-drive / network mounting, MTP,
    #     and Windows-network discovery. gvfsd-network starts `wsdd` on its first
    #     activation; without it, Files waits for the failed automount and logs
    #     "Failed to spawn the wsdd daemon".
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

    # UPower: the D-Bus power daemon DMS's battery widget reads battery
    # state from. Enable it explicitly — relying on D-Bus auto-activation made
    # battery detection in the bar flaky.
    services.upower.enable = true;

    # Fonts DMS/niri expect (Material Symbols, a Nerd Font, emoji).
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

      # Font Awesome 6 (Brands) — the githubNotifier DankBar plugin renders the
      # GitHub logo from this family (mixins/dms.nix).
      font-awesome
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
      # SDDM "sddm-astronaut" theme, used as-is with its bundled pixel_sakura
      # preset (animated background + the preset's own colours — see the
      # `sddmAstronaut` let-binding; it's independent of the app theming).
      # Installed into the system profile so SDDM finds it under
      # .../share/sddm/themes/sddm-astronaut-theme.
      sddmAstronaut

      # X11 apps (Steam & co): niri ≥25.08 spawns xwayland-satellite on demand
      # and exports DISPLAY by itself — the binary just has to be on PATH.
      xwayland-satellite

      brightnessctl
      ddcutil # external-monitor brightness over DDC/CI — DMS's brightness backend (drives the slider + the XF86MonBrightness keybinds)
      playerctl
      wl-clipboard
      # grim/slurp: kept installed for DMS's screenshot subcommand (bound on
      # Print / Mod+Shift+S in users/kyandesutter/mixins/niri.nix), which
      # likely shells out to them for the actual capture.
      grim
      slurp
      ffmpegthumbnailer # video thumbnails for tumbler/Nautilus
      wsdd # GVFS's Windows-network discovery helper; prevents first-launch delay in Nautilus
    ];
  };
}
