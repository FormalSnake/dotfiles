{ pkgs, config, lib, osConfig, ... }:
let
  # Same host flags as ./default.nix: the shell picks the GTK palette import,
  # the dGPU gates the g815 GPU selection.
  useFormalshell = osConfig.kyan.desktop.shell == "formalshell";
  shellColors = if useFormalshell then "formalshell-colors.css" else "dank-colors.css";

  iconThemeName = "Colloid-Dark";

  hasNvidia = (osConfig.kyan or { }).nvidia.enable or false;

  # KDE apps off Plasma take Breeze Light/Dark over the qtct palette unless
  # [UiSettings] ColorScheme names a scheme. Set through XDG_CONFIG_DIRS so
  # only this session sees it: ~/.config/kdeglobals is Plasma's, which keeps
  # its own scheme. Matugen renders the scheme (kde-colors in dms.nix).
  kdeGlobals = pkgs.writeTextDir "kdeglobals" ''
    [UiSettings]
    ColorScheme=Matugen
  '';
in
{
  # Session environment (uwsm)
  #
  # uwsm sources ~/.config/uwsm/env and ~/.config/uwsm/env-${XDG_CURRENT_DESKTOP,,}
  # once per login, before launching Hyprland, and imports the result into the
  # systemd user manager. That second half is what makes this the right home for
  # anything the *autostarted user services* also need: they do not inherit
  # Hyprland's own `hl.env` block.
  xdg.configFile."uwsm/env".text = ''
    export QS_ICON_THEME="${iconThemeName}"
    export QT_QPA_PLATFORMTHEME="qt6ct"
    export XDG_CONFIG_DIRS="${kdeGlobals}''${XDG_CONFIG_DIRS:+:$XDG_CONFIG_DIRS}"
  '';

  # GPU selection (g815)
  #
  # The MUX routes the internal panel through the dGPU (systems/g815/
  # default.nix), so the session renders and scans out on the RTX 5070 alone.
  # Named explicitly: aquamarine otherwise probes the iGPU too and Xwayland
  # grabs whichever node it finds first. Resolved through the stable by-path
  # PCI symlink (DRM card numbers reorder across boots). uwsm feeds this file
  # to the compositor and the user manager, so the VA-API and GLX vendor picks
  # reach autostarted services too.
  xdg.configFile."uwsm/env-hyprland" = lib.mkIf hasNvidia {
    text = ''
      export AQ_DRM_DEVICES="$(readlink -f /dev/dri/by-path/pci-0000:02:00.0-card)"
      export LIBVA_DRIVER_NAME=nvidia
      export NVD_BACKEND=direct
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
    '';
  };

  # xdph keeps hyprlang syntax; Hyprland's Lua config does not reach it.
  # Pre-ticking "Allow restore token" lets Discord/Meet reuse the last share
  # target instead of reopening the picker every call.
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      allow_token_by_default = true
    }
  '';

  # polkit auth agent: FormalShell registers its own in-shell agent (M16,
  # 2026-08-03), so there is no standalone agent service here. Two agents would
  # race for the session registration.

  # Compositor-essential session packages. The generic GNOME/desktop apps and
  # their MIME defaults live in users/kyandesutter/mixins/desktop/desktop-apps.nix.
  #   • wl-clip-persist: keeps the regular Wayland selection alive after the
  #     source app exits so the shell's clipboard poller can capture it
  #     (launched from autostart.nix).
  home.packages = with pkgs; [
    wl-clip-persist

    # GTK theme the shell's gtk template sets via gsettings/dconf (adw-gtk3-dark).
    # Installed here so that theme name resolves; the shell, not the gtk module,
    # selects it (see the dark-mode block below).
    adw-gtk3

    # Icon themes. Colloid-Dark is the desktop-wide icon set (set via gtk.iconTheme
    # below, plus qt{5,6}ct.conf + QS_ICON_THEME above for Qt). adwaita is kept
    # as the complete freedesktop fallback so any icon Colloid lacks resolves
    # to a real glyph instead of the broken-image placeholder.
    colloid-icon-theme
    adwaita-icon-theme

    # Qt platform theme engines. QT_QPA_PLATFORMTHEME=qt6ct (uwsm/env above)
    # points Qt6 apps at qt6ct; qt5ct themes Qt5 apps. Both read the shell's
    # generated colour scheme via the qt{6,5}ct.conf written in mixins/desktop/qt.nix.
    kdePackages.qt6ct
    libsForQt5.qt5ct

    # Disk usage as a treemap. Qt6 widgets, so it also shows what the Qt theme
    # above looks like on a real app.
    qdirstat
  ];

  # Cursor theme: Bibata Modern Classic, the black variant. Sets it for GTK,
  # native Wayland (hyprcursor) and X11/XWayland (x11.enable exports
  # XCURSOR_THEME/SIZE), so every app shows the same cursor; the hl.env pair
  # in outputs.nix covers XWayland clients Hyprland spawns itself.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  # Dark mode for GTK / X11 / browsers.
  #
  # The shell owns app theming (see the matugen config.toml + templates in
  # dms.nix, plus DMS's own builtin gtk template). The builtin gtk3/gtk4
  # templates write the palette to ~/.config/gtk-{3,4}.0/dank-colors.css
  # (imported via gtk.css), and DMS drives the *runtime* dark signal on every
  # re-theme: `gsettings set org.gnome.desktop.interface color-scheme
  # prefer-dark` + `gtk-theme adw-gtk3-dark` (also written to dconf).
  # xdg-desktop-portal reports that to native-Wayland libadwaita/GTK4 apps. So
  # we don't pin the theme *name* here: the shell chooses it, and pinning our
  # own would drift.
  #
  # We keep this module for the things the shell does NOT do:
  #   • gtk.iconTheme: sets Colloid-Dark as the icon theme. Neither shell
  #     touches the icon theme; without this GTK falls back to hicolor and
  #     renders every app/mime icon as the broken-image placeholder.
  #   • gtk-application-prefer-dark-theme in settings.ini: the X11/XWayland
  #     fallback (no xsettingsd here). DMS's gtk theming only touches
  #     gtk.css + gsettings/dconf, never settings.ini.
  #   • gtk.font: the UI font (gtk-font-name in both settings.ini files).
  #     GTK3 under Wayland and GTK4 read it from there; GNOME/libadwaita apps
  #     read org.gnome.desktop.interface instead, so the same pair is written to
  #     dconf below. Without both, half the GTK apps stay on the fontconfig
  #     sans-serif default and the desktop looks mixed.
  #   • gtk{3,4}.extraCss: own gtk.css declaratively so it holds ONLY the
  #     session.css import (see gtk-session-css below). The shell writes the colour file but never gtk.css, so
  #     an unmanaged gtk.css silently accumulates cruft: stale @define-color
  #     blocks from old theming tools end up ABOVE the import, and GTK
  #     requires @import before any other rule: so it drops the import, the
  #     colour file never loads, and GTK3 apps render un-themed adw-gtk3-dark.
  #     Managing the file keeps the import valid and first.
  #
  # FormalShell hosts get the same treatment with FormalShell's names: its
  # ThemeEngine renders formalshell-colors.css (gtk template) + the qt{5,6}ct
  # matugen.conf, and asserts color-scheme/gtk-theme via dconf on every
  # retheme, flipping between adw-gtk3 and adw-gtk3-dark, the same pair DMS uses. The static
  # settings.ini prefer-dark hint is DMS-only: FormalShell has a real light
  # mode, and the hint would keep X11/XWayland GTK3 fallback apps dark in it.
  gtk = {
    enable = true;
    iconTheme = {
      name = iconThemeName;
      package = pkgs.colloid-icon-theme;
    };
    font = {
      name = "Adwaita Sans";
      size = 11;
    };
    gtk3.extraConfig = lib.optionalAttrs (!useFormalshell) { gtk-application-prefer-dark-theme = 1; };
    gtk4.extraConfig = lib.optionalAttrs (!useFormalshell) { gtk-application-prefer-dark-theme = 1; };
    gtk3.extraCss = ''@import url("session.css");'';
    gtk4.extraCss = ''@import url("session.css");'';
  };

  # gtk.css is read in every session, so it only imports session.css, which
  # the session picks at startup: this unit points it at hyprland.css (the
  # shell's palette imports) at every Hyprland login.
  xdg.configFile."gtk-3.0/hyprland.css".text = ''@import url("${shellColors}");'';
  xdg.configFile."gtk-4.0/hyprland.css".text = ''@import url("${shellColors}");'';
  systemd.user.services.gtk-session-css = {
    Unit = {
      Description = "Point GTK's session.css at the Hyprland theme";
      Before = [ "wayland-session-pre@hyprland.desktop.target" ];
    };
    Install.WantedBy = [ "wayland-session-pre@hyprland.desktop.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "gtk-session-css" ''
        for dir in "${config.xdg.configHome}"/gtk-3.0 "${config.xdg.configHome}"/gtk-4.0; do
          ${pkgs.coreutils}/bin/ln -sfn hyprland.css "$dir/session.css"
        done
      '');
    };
  };

  # The GSettings half of the GTK font (see the gtk block above). The shell
  # writes gtk-theme and color-scheme into this same schema at runtime; these
  # keys are disjoint from those, so neither side clobbers the other.
  dconf.settings."org/gnome/desktop/interface" = {
    font-name = "Adwaita Sans 11";
    monospace-font-name = "GeistMono Nerd Font 11";
    document-font-name = "Adwaita Sans 12";
  };

  # No buttons on GTK headerbars. Hyprland answers every decoration request
  # with server-side, so Qt draws none of its own, and GTK matches that.
  dconf.settings."org/gnome/desktop/wm/preferences".button-layout = ":";
}
