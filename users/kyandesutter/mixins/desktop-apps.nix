{ pkgs, lib, ... }:
{
  # GTK ≥4.14 defaults to the Vulkan GSK renderer, which corrupts frames on this
  # laptop's Intel iGPU (ANV) — diagonal tearing across the whole window, most
  # visible in GNOME Calendar's month grid. Force the older GL renderer, which
  # keeps GPU acceleration and dodges the ANV bug (verified clean on Calendar).
  home.sessionVariables.GSK_RENDERER = "gl";

  # GNOME/GTK desktop apps + their MIME defaults. Not niri-specific — these
  # round out the desktop so double-clicking files in Nautilus opens something
  # sensible. Nautilus is the GUI file manager, plus the GNOME companions that
  # make it feel complete: file-roller (extract/create archives from the
  # right-click menu), sushi (Spacebar quick-preview), and loupe (the GNOME image
  # viewer).
  home.packages = with pkgs; [
    nautilus
    file-roller
    sushi
    loupe

    # GNOME/GTK apps that round out the desktop.
    papers # PDF / document viewer (default for application/pdf)
    gnome-text-editor # plain-text editor (default for text/plain)
    gnome-calendar
    gnome-clocks
    gnome-maps
    snapshot # camera
    epiphany # web browser

    # Media + office, so double-clicking these files in Nautilus opens something.
    #   • celluloid: GTK4/libadwaita mpv frontend — plays every common video
    #     format. GNOME Videos (totem) is the "native" app but has weak codec
    #     support; mpv handles everything, so this is the reliable GTK choice.
    #   • libreoffice-fresh: the only real office suite here (GNOME has none).
    #     The -fresh build renders through the gtk3 VCL backend, so it follows
    #     the adw-gtk3-dark GTK theme (set by DMS; see the dark-mode block
    #     in niri.nix). Opens Word/Excel/PowerPoint + ODF.
    celluloid
    libreoffice-fresh
  ];

  # Default apps by MIME. enable writes ~/.config/mimeapps.list.
  #   • Folders → Nautilus (xdg-open, file pickers, "open containing folder",
  #     DMS, etc. all launch it).
  #   • Images → Loupe, so double-clicking an image in Nautilus opens it.
  #   • PDFs → Papers; plain text → GNOME Text Editor.
  #   • Video → Celluloid.
  #   • Office docs → the matching LibreOffice component (Writer/Calc/Impress).
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      {
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        "application/pdf" = [ "org.gnome.Papers.desktop" ];
        "text/plain" = [ "org.gnome.TextEditor.desktop" ];
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
      ] (_: [ "io.github.celluloid_player.Celluloid.desktop" ])
      // lib.genAttrs [
        # Word-processor documents (.doc/.docx/.odt/.rtf) → Writer.
        "application/msword"
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        "application/vnd.oasis.opendocument.text"
        "application/rtf"
      ] (_: [ "writer.desktop" ])
      // lib.genAttrs [
        # Spreadsheets (.xls/.xlsx/.ods/.csv) → Calc.
        "application/vnd.ms-excel"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        "application/vnd.oasis.opendocument.spreadsheet"
        "text/csv"
      ] (_: [ "calc.desktop" ])
      // lib.genAttrs [
        # Presentations (.ppt/.pptx/.odp) → Impress.
        "application/vnd.ms-powerpoint"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        "application/vnd.oasis.opendocument.presentation"
      ] (_: [ "impress.desktop" ]);
  };
}
