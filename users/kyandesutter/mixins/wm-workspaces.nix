# Workspace layout shared by both compositors (mixins/hyprland.nix and
# mixins/mango.nix): the nine names, which of them live on the g815's internal
# panel, and which apps open where. Pure data, no module.
{
  # Pill labels: role -> Nerd Font glyph + short name, mirroring the macOS
  # aerospace workspace names (see mixins/aerospace.nix). Hyprland reports it
  # as the workspace `name`; mango has no tag names, so FormalShell reads them
  # from its compositor.workspaceNames setting instead (mixins/mango.nix).
  # Glyph and name are joined by an EM SPACE, not an ASCII space: the bar
  # widget collapses ASCII/nbsp whitespace in the label but preserves it.
  # Glyphs verified present in GeistMono Nerd Font 3.4.0.
  names = builtins.fromJSON ''
    {"1": " web", "2": " term", "3": " dev", "4": " chat", "5": " prod", "6": " print", "7": "󰚩 ai", "8": " media", "9": " game"}
  '';

  # On the two-monitor g815, communication (4) and media (8) live on the
  # internal panel and the other seven on the desk monitor.
  internal = [ 4 8 ];

  # Window -> workspace. `class` is a regex on the Wayland app-id (Hyprland's
  # class), `title` one on the title. No terminal entry: ghostty opens where
  # you are.
  apps = [
    { class = "^([Hh]elium)$"; workspace = 1; }
    { class = "^([Cc]ode|[Zz]ed|dev.zed.Zed)$"; workspace = 3; }
    { class = "^([Ss]lack|WhatsApp|discord|[Bb]eeper)$"; workspace = 4; }
    # Messages (GPUI) sets no Wayland app-id, so it matches on the title.
    { title = "^(Messages)$"; workspace = 4; }
    { class = "^([Oo]bsidian)$"; workspace = 5; }
    { class = "^([Cc]laude)$"; workspace = 7; }
    { class = "^([Kk]opuz)$"; workspace = 8; }
    { class = "^(es.canarycoders.formalmusic)$"; workspace = 8; }
    # YouTube Music web app (mixins/webapps.nix). Chromium names a
    # shared-profile --app window after its URL and profile, not the
    # launcher's --class.
    { class = "^(chrome-music.youtube.com__-Default)$"; workspace = 8; }
  ];
}
