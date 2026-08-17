{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.kyan.desktop;

  # dms binary (same package the home-manager user service runs), used by the
  # lock-before-sleep hook below.
  dms = inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # FormalShell package, for the formalshell arm of the same hook.
  formalshell = inputs.formalshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Lock the session before the machine suspends. Runs as kyandesutter and talks
  # to the running shell over its IPC socket in the user's XDG_RUNTIME_DIR.
  # `ipc call lock lock` shows the lock screen without suspending — the suspend
  # itself is driven by systemd-suspend.service, ordered after this via
  # sleep.target. Always exit 0: a lock failure (no session, shell down) must
  # never block the suspend.
  #
  # PATH: `dms ipc` execs `qs` (quickshell) rather than speaking the socket
  # itself, and a system service has no user PATH — without this the hook dies
  # with `exec: "qs": executable file not found` and every suspend resumed into
  # an UNLOCKED session (caught on the e1504g 2026-07-22; the script's exit-0
  # masked it). The user profile holds the exact qs the session runs.
  lockBeforeSleep =
    if cfg.shell == "formalshell" then
      # formalshell-lock-before-sleep pins its own qs binary and is
      # exit-0-always by contract (FormalShell spec §8), so it only needs the
      # user's XDG_RUNTIME_DIR; the timeout is belt and braces on top.
      pkgs.writeShellScript "lock-before-sleep" ''
        export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
        ${pkgs.coreutils}/bin/timeout 10 ${formalshell}/bin/formalshell-lock-before-sleep || true
        exit 0
      ''
    else
      pkgs.writeShellScript "lock-before-sleep" ''
        export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
        export PATH="/etc/profiles/per-user/${config.users.users.kyandesutter.name}/bin:$PATH"
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
  # Imported unconditionally: everything in it is inert until
  # services.formalshell.enable flips on below.
  imports = [ inputs.formalshell.nixosModules.formalshell ];

  options.kyan.desktop = {
    enable = lib.mkEnableOption "Hyprland desktop (system side)";
    shell = lib.mkOption {
      type = lib.types.enum [ "dms" "formalshell" ];
      default = "dms";
      description = "Which desktop shell owns the session (bar, lock screen, notification daemon). Picks the lock-before-sleep hook here and gates the shell-facing binds and user services in users/kyandesutter/mixins/{hyprland,formalshell}.nix.";
    };
  };

  config = lib.mkIf cfg.enable {
    # System-side FormalShell prerequisites (the formalshell-lock PAM service,
    # geoclue; NetworkManager/bluetooth/UPower/PPD/pipewire are mkDefault'd in
    # the module and already owned by this profile).
    services.formalshell.enable = cfg.shell == "formalshell";

    # GOA/EDS calendar backend (M12): evolution-data-server serves calendar
    # data on the session bus (formalshell-eds reads it over one held D-Bus
    # connection) and gnome-online-accounts holds the Google account, tokens
    # in the keyring (gnome-keyring is wired below). gnome-control-center is
    # the only GOA sign-in UI outside GNOME: run
    # `XDG_CURRENT_DESKTOP=GNOME gnome-control-center online-accounts` once.
    services.gnome.evolution-data-server.enable = lib.mkIf (cfg.shell == "formalshell") true;
    services.gnome.gnome-online-accounts.enable = lib.mkIf (cfg.shell == "formalshell") true;

    # Hyprland session (nixpkgs module): installs the package, registers the
    # hyprland-uwsm Wayland session for SDDM, wires the portal and XWayland.
    #
    # withUWSM: uwsm owns the session as a systemd unit tree
    # (wayland-wm@Hyprland.service BindsTo graphical-session.target, which the
    # autostart user services in users/kyandesutter/mixins/autostart.nix hang
    # off). It is also what sources ~/.config/uwsm/env{,-hyprland} and imports
    # them into the systemd user manager, which is how the GPU device set and
    # the iGPU pins reach both the compositor and every user service — see
    # users/kyandesutter/mixins/hyprland.nix.
    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    # xdg portals: hyprland's own portal for screencast/screenshot, gtk for the
    # rest (file pickers). gnome-keyring's Secret portal is gated `UseIn=gnome`
    # and $XDG_CURRENT_DESKTOP=Hyprland bypasses it — keep the explicit pin so
    # sandboxed Flatpaks can reach the keyring.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };

    # SDDM (Qt6, Wayland) with the Keyitdev "sddm-astronaut" theme. SDDM lists
    # the Hyprland uwsm session (hyprland-uwsm.desktop, installed by
    # programs.hyprland) from /run/current-system/sw/share/wayland-sessions.
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
    # session. This oneshot raises the shell's lock screen and is ordered Before
    # sleep.target, so every suspend path — lid close, idle, and the
    # SUPER+SHIFT+Escape keybind — resumes on the lock screen. (The keybind
    # still locks on its own too; this makes the lid path match.)
    systemd.services.lock-before-sleep = {
      description = "Lock the session before sleep";
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

    # Electron/Chromium apps run native Wayland (moved here from nvidia.nix —
    # it's a Wayland-desktop concern, not a GPU one).
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # UPower: the D-Bus power daemon the shell's battery widget reads battery
    # state from. Enable it explicitly — relying on D-Bus auto-activation made
    # battery detection in the bar flaky.
    services.upower.enable = true;

    # AccountsService: DMS reads the user avatar through it
    # (PortalService.getUserIconFile → HeaderPane), and it's what falls back to
    # ~/.face (seeded in users/kyandesutter/mixins/dms.nix). Without the daemon
    # that whole path is dead and the profile picture never loads.
    services.accounts-daemon.enable = true;

    # Fonts the shell expects (Material Symbols, a Nerd Font, emoji).
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

    # Make MEK Sans / MEK Mono the default sans/monospace for the whole system
    # (GTK apps, anything resolving the generic sans-serif/monospace families).
    # Geist/GeistMono stay directly behind them: the MEK faces carry no
    # box-drawing, powerline or Nerd Font glyphs, so TUI frames and the fish
    # prompt's OS logo resolve through GeistMono instead of dropping to tofu.
    # MEK has no serif, so Noto Serif still fills that generic. "Noto Color
    # Emoji" is appended to every family so emoji render even in apps that don't
    # consult fontconfig's emoji generic directly.
    fonts.fontconfig.defaultFonts = {
      sansSerif = [ "MEK Sans" "Geist" "Noto Sans" "Noto Color Emoji" ];
      serif = [ "Noto Serif" "Noto Color Emoji" ];
      monospace = [ "MEK Mono" "GeistMono Nerd Font" "Noto Sans Mono" "Noto Color Emoji" ];
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

    # tailscale up/down from the FormalShell panel (M16) needs operator mode,
    # applied by tailscaled at service start.
    services.tailscale.extraSetFlags = [ "--operator=kyandesutter" ];

    # LocalSend discovery and transfers (FormalShell menu SHARE route).
    networking.firewall.allowedTCPPorts = [ 53317 ];
    networking.firewall.allowedUDPPorts = [ 53317 ];

    environment.systemPackages = with pkgs; [
      # Night light backend for FormalShell (M16): the shell manages the
      # wlsunset process itself and only needs the binary on PATH.
      wlsunset

      # ASCII audio visualizer backend (FormalShell M17 era): the shell
      # runs cava itself, gated on playback; binary on PATH is enough.
      cava

      # LocalSend, driven by the shell menu SHARE route; port below.
      localsend

      # SDDM "sddm-astronaut" theme, used as-is with its bundled pixel_sakura
      # preset (animated background + the preset's own colours — see the
      # `sddmAstronaut` let-binding; it's independent of the app theming).
      # Installed into the system profile so SDDM finds it under
      # .../share/sddm/themes/sddm-astronaut-theme.
      sddmAstronaut

      brightnessctl
      ddcutil # external-monitor brightness over DDC/CI — the shell's brightness backend (drives the slider + the XF86MonBrightness keybinds)
      playerctl
      wl-clipboard
      # grim/slurp: the shell's screenshot subcommand (bound on Print /
      # Mod+Shift+S in users/kyandesutter/mixins/hyprland.nix) shells out to
      # them for the actual capture.
      grim
      slurp
      ffmpegthumbnailer # video thumbnails for tumbler/Nautilus
      wsdd # GVFS's Windows-network discovery helper; prevents first-launch delay in Nautilus
    ]
    # GOA sign-in UI (see the services.gnome block above): the only way to add
    # an online account outside GNOME proper.
    ++ lib.optionals (cfg.shell == "formalshell") [ gnome-control-center ];
  };
}
