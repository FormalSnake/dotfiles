{ pkgs, lib, ... }:
{
  # GTK ≥4.14 defaults to the Vulkan GSK renderer, which corrupts frames on this
  # laptop's Intel iGPU (ANV): diagonal tearing across the whole window, most
  # visible in GNOME Calendar's month grid. Force the older GL renderer, which
  # keeps GPU acceleration and dodges the ANV bug (verified clean on Calendar).
  home.sessionVariables.GSK_RENDERER = "gl";

  # Desktop apps + their MIME defaults. Not Hyprland-specific: these round out
  # the desktop so double-clicking files opens something sensible. elementary's
  # own apps where they keep every feature of the GNOME app they replace (they
  # carry the elementary stylesheet natively, see mixins/desktop/elementary), GNOME's
  # where elementary has no equal:
  #   • Files: native quick preview, archive extract/compress through
  #     contractor + file-roller-contract (contractor is D-Bus activated), the
  #     same gvfs, tumbler thumbnails and gtk-3.0/bookmarks as Nautilus.
  #   • Loupe stays: Photos' viewer declares no BMP, ICO, HEIF, AVIF or SVG.
  home.packages = with pkgs; [
    pantheon.elementary-files
    pantheon.contractor
    pantheon.file-roller-contract
    file-roller
    loupe

    papers # PDF / document viewer (default for application/pdf)
    pantheon.elementary-code # plain-text editor (default for text/plain)
    # texliveMedium (PDF export only) drags in asymptote, whose pyqt5 fails to
    # build on python 3.14; texliveBasic still has pdflatex. nixpkgs pins
    # apostrophe to python312, which is uncached and whose anyio tests fail
    # (2026-10-04); it builds fine on the default python.
    (apostrophe.override {
      texliveMedium = texliveBasic;
      python312Packages = python3Packages;
    }) # Markdown editor, default for .md
    pantheon.elementary-calendar # reads GOA accounts through evolution-data-server
    gnome-clocks
    gnome-maps
    pantheon.elementary-camera
    epiphany # web browser

    # Media.
    #   • celluloid: GTK4/libadwaita mpv frontend, plays every common video
    #     format. GNOME Videos (totem) is the "native" app but has weak codec
    #     support; mpv handles everything, so this is the reliable GTK choice.
    celluloid
  ];

  # Default apps by MIME. enable writes ~/.config/mimeapps.list.
  #   • Folders → Files (xdg-open, "open containing folder", the shell, etc.
  #     all launch it).
  #   • Images → Loupe.
  #   • PDFs → Papers; plain text → Code; Markdown → Apostrophe.
  #   • Video → Celluloid.
  # KDE rewrites mimeapps.list in place when an app registers a handler,
  # replacing the symlink and blocking the next activation. Every handler it
  # adds is declared next to its app, so the generated file wins.
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      {
        "inode/directory" = [ "io.elementary.files.desktop" ];
        "application/pdf" = [ "org.gnome.Papers.desktop" ];
        "text/plain" = [ "io.elementary.code.desktop" ];
        # DMS Notepad's desktop file (com.danklinux.dms.notepad.desktop) also
        # declares text/markdown, and Apostrophe only declares text/x-markdown,
        # so both aliases need an explicit default.
        "text/markdown" = [ "org.gnome.gitlab.somas.Apostrophe.desktop" ];
        "text/x-markdown" = [ "org.gnome.gitlab.somas.Apostrophe.desktop" ];
      }
      // lib.genAttrs [
        "image/png"
        "image/jpeg"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/tiff"
        "image/x-icon"
        "image/heif"
        "image/avif"
        "image/svg+xml"
      ] (_: [ "org.gnome.Loupe.desktop" ])
      // lib.genAttrs [
        "video/mp4"
        "video/x-matroska" # .mkv
        "video/webm"
        "video/quicktime" # .mov
        "video/x-msvideo" # .avi
        "video/mpeg"
        "video/ogg"
        "video/x-m4v"
        "video/3gpp"
        "video/x-flv"
        "video/x-ms-wmv"
      ] (_: [ "io.github.celluloid_player.Celluloid.desktop" ]);
  };
}
