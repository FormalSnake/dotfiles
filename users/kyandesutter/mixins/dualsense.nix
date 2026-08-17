{ pkgs, ... }:
let
  # One setter for both surfaces the DualSense can show while it sits on the
  # desk: the lightbar carries the wallpaper accent (same palette as the
  # keyboard aura and the window borders), the player LEDs carry the laptop
  # battery as a 1-5 step gauge.
  #
  # Everything here talks to the controller over hidraw as the session user,
  # which works because programs.steam.enable (modules/nixos/mixins/steam.nix)
  # installs 60-steam-input.rules — it tags hidraw for 054c:0ce6 with uaccess.
  # Drop Steam from a host and this needs its own rule.
  #
  # `dualsensectl -l` lists nothing when no controller is attached, which is
  # the whole guard: every caller here is fire-and-forget, so a run with no
  # controller has to be a silent no-op rather than an error.
  #
  # player-leds takes the console's own player patterns, not a left-to-right
  # bar: 1 lights the centre LED, 2 the pair around it, up to 5 for all of
  # them (dualsensectl main.c, player_ids[]). Symmetric fill, still five
  # readable steps.
  dualsenseSync = pkgs.writeShellApplication {
    name = "dualsense-sync";
    runtimeInputs = with pkgs; [ dualsensectl coreutils gnugrep ];
    text = ''
      dualsensectl -l 2>/dev/null | grep -qi dualsense || exit 0

      # Rendered by matugen's [templates.dualsense] block (dms.nix) on every
      # wallpaper/light-dark change. The seed matches power-tune's fallback so
      # a first boot before the first retheme doesn't blank the lightbar.
      colour="$(cat "$HOME/.cache/dank/dualsense-color" 2>/dev/null || true)"
      [ -n "$colour" ] || colour=b15bf5
      dualsensectl lightbar \
        "$((16#''${colour:0:2}))" "$((16#''${colour:2:2}))" "$((16#''${colour:4:2}))" || true

      cap="$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)"
      leds=$(( (cap + 19) / 20 ))
      [ "$leds" -ge 1 ] || leds=1
      [ "$leds" -le 5 ] || leds=5
      dualsensectl player-leds "$leds" || true
    '';
  };
in
{
  home.packages = [ pkgs.dualsensectl dualsenseSync ];

  # Hotplug: dualsensectl's own udev watcher, so a controller that wakes up or
  # reconnects over Bluetooth is painted immediately instead of waiting for the
  # drift timer. It keeps running with no controller attached, so this is a
  # plain long-lived unit.
  systemd.user.services.dualsense-sync = {
    Unit = {
      Description = "Paint the DualSense lightbar and player LEDs on hotplug";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.dualsensectl}/bin/dualsensectl monitor add ${dualsenseSync}/bin/dualsense-sync";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Battery drift. The gauge only moves a step every ~20% of charge, so a slow
  # tick is enough; the lightbar half of the sync is idempotent.
  systemd.user.timers.dualsense-battery = {
    Unit.Description = "Refresh the DualSense battery gauge";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "2min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.dualsense-battery = {
    Unit.Description = "Refresh the DualSense battery gauge";
    Service = {
      Type = "oneshot";
      ExecStart = "${dualsenseSync}/bin/dualsense-sync";
    };
  };
}
