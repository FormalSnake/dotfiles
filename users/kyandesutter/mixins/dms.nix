{ lib, pkgs, inputs, ... }:
let
  # The single keyboard-aura setter: paint the Aura keyboard to a given accent and
  # apply the effect/brightness appropriate to the current power source. Shared by
  # two triggers — the matugen aura template runs it as a post_hook on every
  # palette change (session start, wallpaper pick, light/dark flip, passing the
  # new accent), and power-tune (niri.nix) calls it on every power-source change
  # (passing the cached accent). Having one setter means the two triggers can't
  # disagree.
  #
  # By power source (see modules/nixos/mixins/power.nix `power-source`):
  #   ac        — static themed colour, full brightness.
  #   powerbank — slow breathe of the themed accent (a "charging" vibe) while still
  #               being treated as battery for power; full brightness.
  #   battery   — themed colour staged but brightness dropped to dark (so a later
  #               AC/relog brings the colour back). This is also the fix for the
  #               LEDs lighting up after a relog on battery: setting an Aura effect
  #               re-enables the backlight, so we re-assert the dark level here.
  # Runs inside DMS's systemd *user* service (limited PATH), so power-source is
  # pinned by absolute path; brightness is driven through asusd (asusctl leds) since
  # the user can't write the root-owned /sys LED node directly.
  auraRepaint = pkgs.writeShellApplication {
    name = "aura-repaint";
    runtimeInputs = [
      pkgs.asusctl
      pkgs.coreutils
    ];
    text = ''
      colour="''${1:?usage: aura-repaint <hex>}"
      case "$(/run/current-system/sw/bin/power-source 2>/dev/null || echo ac)" in
        ac)
          asusctl aura effect static -c "$colour" || true
          asusctl leds set high || true
          ;;
        powerbank)
          asusctl aura effect breathe --colour "$colour" --colour2 000000 --speed med || true
          asusctl leds set high || true
          ;;
        *)
          asusctl aura effect static -c "$colour" || true
          asusctl leds set off || true
          ;;
      esac
    '';
  };

  # Seed for ~/.config/DankMaterialShell/settings.json (activation block below):
  # disables every idle monitor DMS's IdleService.qml drives — screen-off, lock,
  # and suspend, on both AC and battery. Same reason noctalia's idle was
  # force-disabled: the internal panel (eDP-1) fails its wake modeset with
  # `PHY A failed to request refclk` (see systems/g815/default.nix), and that
  # modeset only happens coming back from a DPMS-off, so never blanking on idle
  # dodges it. Manual lock/suspend (SUPER+SHIFT+Escape) is unaffected.
  #
  # Key names verified against upstream quickshell/Common/settings/SettingsSpec.js
  # (AvengeMedia/DankMaterialShell@74896fb): DMS already defaults every one of
  # these to 0 (= disabled), but they're pinned explicitly here rather than
  # relying on that staying true across DMS updates.
  idleSettingsSeed = pkgs.writeText "dms-settings-idle-seed.json" (
    builtins.toJSON {
      acMonitorTimeout = 0;
      acLockTimeout = 0;
      acSuspendTimeout = 0;
      batteryMonitorTimeout = 0;
      batteryLockTimeout = 0;
      batterySuspendTimeout = 0;
    }
  );
in
{
  # Official DankMaterialShell flake home-manager module. DMS is a Quickshell/QML
  # desktop shell. The module installs the `dms-shell` package + runs it as a user
  # systemd service bound to the Wayland systemd target (auto-starts once niri
  # reaches that target).
  imports = [ inputs.dank-material-shell.homeModules.dank-material-shell ];

  # Expose aura-repaint on PATH so power-tune (niri.nix) can call it as the
  # shared keyboard-aura setter (the matugen aura template's post_hook also uses
  # it, by store path).
  home.packages = [ auraRepaint ];

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true; # user service, PartOf the Wayland/graphical-session target
    enableDynamicTheming = true; # pulls in the deps DMS's own theming needs
  };

  # settings.json is DMS's own runtime-mutable config (rewritten by the Settings
  # UI and by DMS itself on every save), so home-manager must not own the whole
  # file — seed it once, only if absent, so idle stays disabled from the very
  # first session rather than however long it takes to open Settings manually.
  home.activation.dmsIdleSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.config/DankMaterialShell/settings.json" ]; then
      run mkdir -p "$HOME/.config/DankMaterialShell"
      run cp --no-preserve=mode ${idleSettingsSeed} "$HOME/.config/DankMaterialShell/settings.json"
    fi
  '';
}
