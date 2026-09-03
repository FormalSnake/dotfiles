{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.kyan.desktop;

  # qylock's Quickshell lock screen. Same builder call the programs.qylock
  # module makes below, with the same arguments, so both references resolve to
  # one derivation rather than two builds of the same 650 MB theme tree.
  qylockTheme = "sword";
  # sword takes none of the per-theme conf edits qylock's module can apply
  # (only terraria, Genshin, clockwork and osu have any).
  qylockThemeOptions = { };
  qylockLock = inputs.qylock.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mkQuickshell {
    defaultTheme = qylockTheme;
    themeOptions = qylockThemeOptions;
  };

  # Lock the session before the machine suspends. Runs as kyandesutter and
  # starts qylock-lock.service through the user manager, reached over
  # $XDG_RUNTIME_DIR/bus (systemctl --user derives the bus address from
  # XDG_RUNTIME_DIR when DBUS_SESSION_BUS_ADDRESS is unset, which it is in a
  # system unit). Starting an already-running unit is a no-op, so the paths
  # where the keybind locked first cost nothing. The suspend itself is driven
  # by systemd-suspend.service, ordered after this via sleep.target. Always
  # exit 0: a lock failure (no session, no user manager) must never block the
  # suspend.
  lockBeforeSleep = pkgs.writeShellScript "lock-before-sleep" ''
    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    ${pkgs.coreutils}/bin/timeout 10 \
      ${pkgs.systemd}/bin/systemctl --user start qylock-lock.service || true
    exit 0
  '';

  # weston.ini for the SDDM Wayland greeter compositor. Mirrors what the NixOS
  # sddm module generates by default (keyboard from the xkb config, the module's
  # libinput defaults), so behaviour is unchanged except that we hand weston a
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

  # SDDM Wayland greeter compositor launcher. Weston picks the boot_vga card,
  # which on both hosts owns every connector (the g815 panel and HDMI both
  # hang off the dGPU since the MUX switch, see systems/g815/default.nix).
  sddmGreeterCompositor = pkgs.writeShellScript "sddm-greeter-compositor" ''
    exec ${pkgs.weston}/bin/weston --shell=kiosk -c ${sddmWestonIni}
  '';

  # Apple's emoji, the set every iMessage and iOS device draws, from upstream's
  # Linux conversion of the .ttc Apple ships in /System/Library/Fonts: one TTF
  # in CBDT/CBLC, the same colour-bitmap format Noto Color Emoji uses.
  #
  # The name table is rewritten for three reasons, all of them about the Rust
  # text stack (fontdb + cosmic-text under GPUI), not about fontconfig:
  #
  # 1. The release carries Macintosh-platform name records only, and fontdb
  #    reads family names from Unicode/Windows records. It finds none, so it
  #    drops the face and the font does not exist for those toolkits at all.
  # 2. cosmic-text's Unix fallback list is hardcoded and names "Noto Color
  #    Emoji" as its only emoji family. A family it does not name is reached
  #    only after every other installed face, in directory scan order, where
  #    Font Awesome and the CJK fonts answer for hundreds of emoji codepoints
  #    first. The en-GB record aliases this file to the name it does look for.
  #    Nothing else provides that family: noto-fonts-color-emoji is gone below.
  # 3. GPUI decides a glyph is emoji by comparing the PostScript name against
  #    the literal "NotoColorEmoji", and rasterises anything else as an
  #    outline. A colour-bitmap font has no outlines, so under its own name
  #    this one drew blanks: "unable to render glyph via swash", is_emoji
  #    false, nothing painted.
  appleColorEmojiRelease = "macos-26-20260722-484daf4e";
  appleColorEmoji = pkgs.runCommand "apple-color-emoji-${appleColorEmojiRelease}"
    {
      src = pkgs.fetchurl {
        url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/${appleColorEmojiRelease}/AppleColorEmoji-Linux.ttf";
        hash = "sha256-43x69iZaxKCvbVe8ZehhCad22ZZug0MzRVf2PaSCUW8=";
      };
      nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.fonttools ])) ];
    }
    ''
      # lazy=True leaves the 110 MB bitmap table packed; decompiling it needs
      # more memory than the e1504g has to spare.
      python3 - "$src" AppleColorEmoji.ttf <<'PY'
      import sys
      from fontTools.ttLib import TTFont

      font = TTFont(sys.argv[1], lazy=True)
      names = font["name"]
      for name_id, value in ((1, "Apple Color Emoji"), (2, "Regular"), (4, "Apple Color Emoji")):
          names.setName(value, name_id, 3, 1, 0x409)
      for name_id, value in ((1, "Noto Color Emoji"), (2, "Regular"), (4, "Noto Color Emoji")):
          names.setName(value, name_id, 3, 1, 0x809)
      # Both records: fontdb takes the first PostScript name in table order and
      # accepts Mac Roman, so the Macintosh one it shipped with would win.
      names.setName("NotoColorEmoji", 6, 1, 0, 0)
      names.setName("NotoColorEmoji", 6, 3, 1, 0x409)
      font.save(sys.argv[2])
      PY
      install -Dm444 AppleColorEmoji.ttf $out/share/fonts/truetype/AppleColorEmoji.ttf
    '';

  # nixpkgs builds fontconfig with dejavu_fonts.minimal wired in as its own
  # last-resort font directory, and that <dir> line sits in the package's
  # fonts.conf, underneath everything the NixOS module generates. fontdb takes
  # its directory list from that same file and has no notion of <rejectfont>,
  # so DejaVu Sans walks back in for every GPUI app and goes on drawing the
  # U+1F600 faces and ❤ in outline. This is that file minus the one line,
  # first in confPackages so it wins the buildEnv merge behind /etc/fonts.
  fontconfigNoDefaultDir = pkgs.runCommandLocal "fontconfig-no-default-dir" { } ''
    mkdir -p $out/etc/fonts
    grep -v dejavu-fonts-minimal ${pkgs.fontconfig.out}/etc/fonts/fonts.conf > $out/etc/fonts/fonts.conf
  '';

  # noto-fonts minus "Noto Sans Symbols", which draws 64 emoji (☺ ☹ 😐 ♻ ⚓ ⛪
  # ⛵, the zodiac) as monochrome outlines and sits ahead of every emoji font
  # in cosmic-text's list. "Noto Sans Symbols 2" stays: cosmic-text spells it
  # without the space and so never reaches it, and ghostty maps U+23FA to it
  # (users/kyandesutter/mixins/ghostty.nix).
  notoFonts = pkgs.runCommandLocal "noto-fonts-no-symbols" { } ''
    mkdir -p $out/share/fonts/noto
    for font in ${pkgs.noto-fonts}/share/fonts/noto/*; do
      case "$(basename "$font")" in
        NotoSansSymbols.ttf) ;;
        *) ln -s "$font" $out/share/fonts/noto/ ;;
      esac
    done
  '';
in
{
  # Imported unconditionally. Everything in it is inert until
  # services.formalshell.enable flips on below.
  #
  # qylock declares programs.qylock, which owns both the SDDM theme and the
  # qylock-lock wrapper (configured in the programs.qylock block below).
  imports = [
    inputs.formalshell.nixosModules.formalshell
    inputs.qylock.nixosModules.default
  ];

  options.kyan.desktop = {
    enable = lib.mkEnableOption "Hyprland desktop (system side)";
    shell = lib.mkOption {
      type = lib.types.enum [ "dms" "formalshell" ];
      default = "dms";
      description = "Which desktop shell owns the session (bar, notification daemon). Gates the shell-facing binds and user services in users/kyandesutter/mixins/{hyprland,formalshell}.nix. Not the lock screen: qylock owns that on both shells.";
    };
  };

  config = lib.mkIf cfg.enable {
    # System-side FormalShell prerequisites (the formalshell-lock PAM service,
    # geoclue; NetworkManager/bluetooth/UPower/PPD/pipewire are mkDefault'd in
    # the module and already owned by this profile).
    services.formalshell.enable = cfg.shell == "formalshell";

    # GOA/EDS calendar backend (M12): evolution-data-server serves calendar
    # data on the session bus (formalshell-eds reads it over one held D-Bus
    # connection), and gnome-online-accounts holds the Google account, tokens
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
    # the iGPU pins reach both the compositor and every user service (see
    # users/kyandesutter/mixins/hyprland.nix).
    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    # xdg portals: hyprland's own portal for screencast/screenshot, gtk for the
    # rest (file pickers). gnome-keyring's Secret portal is gated `UseIn=gnome`
    # and $XDG_CURRENT_DESKTOP=Hyprland bypasses it. Keep the explicit pin so
    # sandboxed Flatpaks can reach the keyring.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };

    # SDDM (Qt6, Wayland). SDDM lists the Hyprland uwsm session
    # (hyprland-uwsm.desktop, installed by programs.hyprland) from
    # /run/current-system/sw/share/wayland-sessions. The theme itself is set by
    # programs.qylock below, not here.
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      wayland.compositorCommand = toString sddmGreeterCompositor;
      package = pkgs.kdePackages.sddm;
      # On-screen keyboard. The Qt runtime sword's QML needs (svg,
      # multimedia, Qt5Compat) is contributed by the qylock module.
      extraPackages = [ pkgs.kdePackages.qtvirtualkeyboard ];
    };

    # qylock: one theme tree rendered by two frontends, the SDDM greeter and a
    # Quickshell `ext-session-lock-v1` client. sword draws over a looping 43 MB
    # bg.mp4 and loads its own bundled font, so both frontends need Qt
    # Multimedia's backend plugin as well as its QML (see the unit below for
    # the lock half; the greeter gets it through sddm's Qt wrapper).
    #
    # This replaces both the sddm-astronaut cyberdeck greeter and the shell's
    # own lock screen, so the greeter and the lock screen finally match. It
    # stays outside the matugen/Flexoki theming model for the same reason the
    # cyberdeck greeter did: the greeter runs before any user session exists,
    # so there is no wallpaper to derive colours from.
    programs.qylock = {
      enable = true;
      theme = qylockTheme;
      themeOptions = qylockThemeOptions;
    };

    # The lock screen, as a user unit. qylock-lock runs for as long as the
    # session is locked, so it has to outlive whatever raised it: the keybind
    # in users/kyandesutter/mixins/hyprland.nix and lockBeforeSleep above both
    # start this unit instead of exec'ing the binary. PartOf, not WantedBy: it
    # is only ever started on demand, but it must not survive the compositor.
    systemd.user.services.qylock-lock = {
      description = "qylock lock screen";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      # bash: qylock-lock is a makeWrapper script around a lock.sh carrying a
      # `#!/usr/bin/env bash` shebang, and the wrapper's own PATH prefix
      # (quickshell, psmisc, systemd, coreutils) has no shell in it. A unit
      # PATH is the systemd default, not the session's, so without this the
      # lock dies at exec with `env: bash: No such file or directory`.
      # hyprctl: the lock client sets misc:allow_session_lock_restore through
      # it on a successful unlock.
      path = [ pkgs.bash config.programs.hyprland.package ];
      # qylock's wrapper puts Qt Multimedia's QML on the import path but not
      # its multimedia backend plugin, which lives in a store path of its own
      # and so is invisible to quickshell's Qt. Without it sword's MediaPlayer
      # has no backend and the video background stays black. quickshell's own
      # wrapper prefixes this, so the platform plugins still win.
      environment.QT_PLUGIN_PATH = "${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins";
      serviceConfig = {
        Type = "exec";
        ExecStart = "${qylockLock}/bin/qylock-lock";
        # The lock surface is only handed to the compositor a beat after the
        # process starts. Hold the start job over that gap so a suspend queued
        # right behind it cannot race the screen going black.
        ExecStartPost = "${pkgs.coreutils}/bin/sleep 1";
      };
    };

    # polkit agent + secrets/keyring so GUI auth prompts and saved logins work.
    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;

    # Lock on suspend. logind's default HandleLidSwitch=suspend goes straight to
    # s2idle with no lock, so closing the lid used to resume into an unlocked
    # session. This oneshot raises the shell's lock screen and is ordered Before
    # sleep.target, so every suspend path (lid close, idle, and the
    # SUPER+SHIFT+Escape keybind) resumes on the lock screen. The keybind
    # still locks on its own too. This makes the lid path match.
    systemd.services.lock-before-sleep = {
      description = "Lock the session before sleep";
      before = [ "sleep.target" ];
      wantedBy = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = config.users.users.kyandesutter.name;
        ExecStart = toString lockBeforeSleep;
        # Belt-and-braces: the script already exits 0 and times out its IPC call,
        # but suspend waits on this oneshot. Cap it so sleep is never held up.
        TimeoutStartSec = 15;
      };
    };

    # GNOME/GTK desktop plumbing the apps and file manager rely on:
    #   • gvfs + wsdd: Nautilus trash, removable-drive / network mounting, MTP,
    #     and Windows-network discovery. gvfsd-network starts `wsdd` on its first
    #     activation. Without it, Files waits for the failed automount and logs
    #     "Failed to spawn the wsdd daemon".
    #   • tumbler (+ ffmpegthumbnailer): thumbnails, including video, in Nautilus.
    #   • dconf: the settings backend every GTK/GNOME app reads and writes.
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    programs.dconf.enable = true;

    # Nautilus is installed via home-manager (home.packages), so it isn't wrapped
    # with the GNOME GIO module environment the NixOS gnome session would provide.
    # Without gvfs's client module (libgvfsdbus.so) on GIO_EXTRA_MODULES, GIO only
    # knows local backends, so `trash://` is unavailable and Nautilus reports
    # "Trash locations are not supported" when you open Trash. Put gvfs's gio
    # modules on the session search path (this list merges with dconf's, which is
    # already there), so the trash backend (gvfsd-trash) loads and D-Bus-activates.
    environment.sessionVariables.GIO_EXTRA_MODULES = [ "${pkgs.gvfs}/lib/gio/modules" ];

    # Electron/Chromium apps run native Wayland (moved here from nvidia.nix,
    # it's a Wayland-desktop concern, not a GPU one).
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # UPower: the D-Bus power daemon the shell's battery widget reads battery
    # state from. Enable it explicitly. Relying on D-Bus auto-activation made
    # battery detection in the bar flaky.
    services.upower.enable = true;

    # AccountsService: DMS reads the user avatar through it
    # (PortalService.getUserIconFile → HeaderPane), and it's what falls back to
    # ~/.face (seeded in users/kyandesutter/mixins/dms.nix). Without the daemon,
    # that whole path is dead, and the profile picture never loads.
    services.accounts-daemon.enable = true;

    # Fonts the shell expects (Material Symbols, a Nerd Font, emoji).
    # System UI font is Geist; monospace is GeistMono patched with Nerd Font
    # glyphs (terminal mono + powerline icons). The rest are general coverage
    # fonts so apps don't fall back to Geist (which carries no emoji, CJK, or
    # serif glyphs) for anything outside basic Latin.
    #
    # The NixOS default set is off: it adds dejavu_fonts, freefont_ttf and
    # noto-fonts-color-emoji, and the first two are exactly what has to stay
    # out of the way (see the emoji note below). Its other members are either
    # listed here (liberation, the CJK pair) or not wanted: gyre-fonts is
    # PostScript substitutes for printing, unifont a last-resort bitmap face.
    fonts.enableDefaultPackages = false;

    fonts.packages = with pkgs; [
      material-symbols
      geist-font # "Geist" (sans) + "Geist Mono"
      nerd-fonts.geist-mono # "GeistMono Nerd Font"

      # Broad Latin/symbol coverage + metric-compatible Arial/Times/Courier
      # replacements (lots of web/office content references these by name).
      notoFonts # "Noto Sans" / "Noto Serif": huge Unicode coverage
      liberation_ttf # "Liberation Sans/Serif/Mono" (Arial/Times/Courier metrics)

      # CJK (Chinese/Japanese/Korean) so those scripts render instead of tofu.
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif

      # Emoji, Apple's. DejaVu ("last-resort wide coverage") used to sit above
      # and both Noto emoji fonts here; they are gone, along with the default
      # set's FreeSans/FreeMono, because cosmic-text asks all of those and
      # "Noto Sans Symbols" before any emoji font. Between them they answered
      # for 192 of the 1456 emoji codepoints in monochrome, the whole U+1F600
      # face block, ❤, ☺ and ✈ included. What still reaches a text font is
      # ©®™‼⁉ℹ↔↕▪▫▶◀◻◼◽◾, which wants a text glyph anyway. Noto, Liberation
      # and Geist cover the rest of what DejaVu did, bar ⌥ and ✗.
      appleColorEmoji

      # Font Awesome 6 (Brands): the githubNotifier DankBar plugin renders the
      # GitHub logo from this family (mixins/dms.nix).
      font-awesome
    ];

    # Geist / GeistMono are the default sans/monospace for the whole system
    # (GTK apps, anything resolving the generic sans-serif/monospace families).
    # GeistMono is the Nerd Font patch, so TUI frames, powerline segments and
    # the fish prompt's OS logo resolve without dropping to tofu. Geist has no
    # serif, so Noto Serif fills that generic. "Apple Color Emoji" is appended
    # to every family so emoji render even in apps that don't consult
    # fontconfig's emoji generic directly.
    fonts.fontconfig.confPackages = lib.mkBefore [ fontconfigNoDefaultDir ];

    fonts.fontconfig.defaultFonts = {
      sansSerif = [ "Geist" "Noto Sans" "Apple Color Emoji" ];
      serif = [ "Noto Serif" "Apple Color Emoji" ];
      monospace = [ "GeistMono Nerd Font" "Noto Sans Mono" "Apple Color Emoji" ];
      emoji = [ "Apple Color Emoji" ];
    };

    # The CSS system-font keywords, which Chromium and Electron hand to
    # fontconfig verbatim. 48-guessfamily.conf already routes ui-monospace and
    # ui-serif through genericfamily, but `system-ui` fell through it and
    # matched "Noto Sans Arabic UI" on the "ui" substring, so any page or
    # Electron app whose stack starts with system-ui drew Latin text in an
    # Arabic UI face. -apple-system and BlinkMacSystemFont only reached the sans
    # default by fallback. Pinning all seven keeps the mapping explicit.
    #
    # localConf lands as local.conf at priority 51, so 52-nixos-default-fonts
    # still resolves the generic to defaultFonts above. It is written verbatim
    # as a whole file, hence the declaration and wrapper.
    #
    # Testing these with fc-match needs the dashes escaped (fc-match 'system\-ui'):
    # FcNameParse reads an unescaped `-` as the point-size separator, so plain
    # `fc-match system-ui` queries the family "ui" and reports a bogus answer.
    fonts.fontconfig.localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <alias binding="same">
          <family>system-ui</family>
          <prefer><family>sans-serif</family></prefer>
        </alias>
        <alias binding="same">
          <family>ui-sans-serif</family>
          <prefer><family>sans-serif</family></prefer>
        </alias>
        <alias binding="same">
          <family>ui-rounded</family>
          <prefer><family>sans-serif</family></prefer>
        </alias>
        <alias binding="same">
          <family>-apple-system</family>
          <prefer><family>sans-serif</family></prefer>
        </alias>
        <alias binding="same">
          <family>BlinkMacSystemFont</family>
          <prefer><family>sans-serif</family></prefer>
        </alias>
        <alias binding="same">
          <family>ui-serif</family>
          <prefer><family>serif</family></prefer>
        </alias>
        <alias binding="same">
          <family>ui-monospace</family>
          <prefer><family>monospace</family></prefer>
        </alias>

        <!-- The emoji font, appended to every pattern rather than only to the
             generics above, so an app that names its own family still gets it.
             Without this, a request for "Geist" that hits an emoji codepoint
             is scored on coverage alone and Font Awesome answers for ❤ and
             the U+1F600 faces. Weak binding: appended behind the app's own
             families, so ©, ® and ™ keep their text glyphs. -->
        <match target="pattern">
          <edit name="family" mode="append" binding="weak">
            <string>Apple Color Emoji</string>
          </edit>
        </match>
      </fontconfig>
    '';

    # Backlight permissions: let the `video` group (which kyandesutter is in)
    # write the panel brightness node so `brightnessctl` works without root.
    # brightnessctl ships its own udev rule, but it hardcodes `/bin/chgrp`
    # (which doesn't exist on NixOS), so spell the rule out with store paths.
    # %S%p is the device's sysfs path. The writable attribute is .../brightness.
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

      # LocalSend, driven by the shell menu SHARE route (port below).
      localsend

      brightnessctl
      ddcutil # external-monitor brightness over DDC/CI (the shell's brightness backend; drives the slider + the XF86MonBrightness keybinds)
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
    # GOA sign-in UI (see the services.gnome block above, the only way to add
    # an online account outside GNOME proper).
    ++ lib.optionals (cfg.shell == "formalshell") [ gnome-control-center ];
  };
}
