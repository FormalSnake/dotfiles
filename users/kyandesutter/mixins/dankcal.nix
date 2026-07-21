{ inputs, ... }:
{
  # DankCalendar (dcal) — the daemon behind DMS's native "dankcal" calendar
  # backend (mixins/dms.nix). It unifies Local/Google/Microsoft/CalDAV/iCloud
  # accounts and serves them to DMS over an IPC socket; DMS's calendarBackend
  # defaults to "auto" (SettingsData key `n`), which enables the dank backend
  # and auto-selects it once this daemon is connected — so nothing in dms.nix's
  # settings seed needs touching.
  #
  # The official home module installs `dcal` (built from source, Quickshell UI
  # baked in) and runs `dcal run --session --hidden` as a user service bound to
  # the Wayland systemd target — same graphical-session wiring as the rest of
  # the g815 login apps.
  #
  # Google (and Microsoft) accounts need a one-time interactive OAuth login the
  # daemon can't do declaratively: create a Google Cloud OAuth *desktop* client
  # with the Calendar API enabled (dcal ships no shared app), then
  #   dcal account setup google   # prints the Cloud Console steps
  #   dcal account add google      # opens the browser consent flow
  # Tokens land in the system keyring, not the store.
  imports = [ inputs.dankcalendar.homeModules.dank-calendar ];

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true; # user service, PartOf the Wayland/graphical-session target
  };
}
