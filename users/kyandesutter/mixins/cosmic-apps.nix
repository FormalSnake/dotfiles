{ pkgs, ... }:
{
  # COSMIC (libcosmic) app trial — side-by-side with the GNOME suite in
  # desktop-apps.nix: no MIME changes, the GNOME apps stay the defaults and
  # keep covering what COSMIC has no answer for (image viewer, calendar,
  # clocks, maps, camera). Launch these by name to evaluate; dropping the
  # trial is deleting this mixin's import.
  # Spec: docs/superpowers/specs/2026-07-26-cosmic-apps-trial-design.md
  #
  # Themed by the matugen `cosmic` template (dms.nix), which also pins every
  # corner radius to 0 — libcosmic draws its own window corners from the
  # theme, so this is what un-rounds the otherwise forcibly-rounded windows.
  # cosmic-settings is here as the headless theme applier (`appearance
  # import`, used by the template's post_hook) and manual-tweak escape
  # hatch, not as a settings app for the niri session.
  home.packages = with pkgs; [
    cosmic-files
    cosmic-edit
    cosmic-player
    cosmic-reader
    cosmic-settings
    tasks # cosmic-ext to-do app
    forecast # cosmic-ext weather app
  ];
}
