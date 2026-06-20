{ config, lib, pkgs, ... }:
let
  # Catppuccin Mocha "Mauve" — the accent painted on the Aura keyboard.
  # Deepened from the on-screen value (cba6f7) to compensate for the LEDs: the
  # pastel mauve renders too white on the keyboard, so we drop lightness and
  # bump saturation (HSL 272/89/66) to read as the intended purple.
  auraColour = "b15bf5";

  # Single source of truth for the power source. Prints exactly one of:
  #   ac        — the barrel charger (up to ~300W): ADP0 online and no USB-C PD
  #               source negotiated.
  #   powerbank — a USB-C / Thunderbolt PD source is online (a ucsi-source-psy-*
  #               entry). The EC reports a power bank as ADP0 online *too*, so the
  #               only signal that tells a ~40-50W power bank apart from the barrel
  #               is a lit UCSI source — the barrel never lights one. A power bank
  #               can't sustain Performance, so it must be treated as battery
  #               (low power) even though it charges.
  #   battery   — nothing plugged.
  # Both the system reconciler (below) and the user session (hyprland.nix) key
  # every power decision off this one classifier.
  powerSource = pkgs.writeShellApplication {
    name = "power-source";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      for f in /sys/class/power_supply/ucsi-source-psy-*/online; do
        [ -e "$f" ] || continue
        if [ "$(cat "$f" 2>/dev/null)" = 1 ]; then echo powerbank; exit 0; fi
      done
      if [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 1)" = 1 ]; then
        echo ac
      else
        echo battery
      fi
    '';
  };

  # Toggle the keyboard backlight brightness node directly (0..max). Used at boot
  # by the asus-aura service to seed an AC-appropriate level without depending on
  # the asusd dbus service being up. (Live AC/battery keyboard following while a
  # session is up is owned by the user session — see power-tune / aura-repaint.)
  kbdDim = pkgs.writeShellScript "asus-kbd-dim" ''
    led=/sys/class/leds/asus::kbd_backlight
    [ -e "$led/brightness" ] || exit 0
    max=$(cat "$led/max_brightness" 2>/dev/null || echo 3)
    case "''${1:-}" in
      on)  echo "$max" > "$led/brightness" ;;
      off) echo 0      > "$led/brightness" ;;
      # ac: classify the source and apply the right level. Used by the asus-aura
      # boot service to re-assert the level *after* it sets the Aura effect (which
      # re-enables the backlight), since at boot there may be no power event yet.
      ac)
        if [ "$(${powerSource}/bin/power-source)" = ac ]; then echo "$max" > "$led/brightness"; else echo 0 > "$led/brightness"; fi ;;
    esac
  '';
in
{
  options.kyan.asus.enable =
    lib.mkEnableOption "ASUS laptop support (asusd, Aura RGB, battery charge limit)";

  config = lib.mkIf config.kyan.asus.enable {
    # asusd: fan curves, Aura keyboard LEDs, battery charge limit.
    # (supergfxd is intentionally omitted — MUX switching needs a relog.)
    services.asusd.enable = true;

    # After asusd is up: seed the keyboard colour and cap the battery charge at
    # 80% for longevity. The seed is the last wallpaper-derived accent noctalia
    # cached to the user's ~/.cache/noctalia/aura-color (so the keyboard already
    # shows the right colour before the graphical session starts); noctalia
    # repaints it on login anyway. Falls back to the Catppuccin Mauve seed if no
    # cache exists yet. `|| true` so a CLI/permission hiccup never fails the boot.
    systemd.services.asus-aura = {
      description = "Aura keyboard accent seed + 80% charge limit";
      after = [ "asusd.service" ];
      requires = [ "asusd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        seed="${config.users.users.kyandesutter.home}/.cache/noctalia/aura-color"
        colour="$(${pkgs.coreutils}/bin/cat "$seed" 2>/dev/null || echo ${auraColour})"
        ${pkgs.asusctl}/bin/asusctl aura effect static -c "$colour" || true
        ${pkgs.asusctl}/bin/asusctl battery limit 80 || true
        # Kill the red breathing "slash" pulse the Aura zones run while the
        # laptop is suspended. The power-state flags are all-or-nothing — any
        # flag omitted is set false — so re-assert boot/awake/shutdown and drop
        # --sleep for every zone. Not all zones exist on every chassis; `|| true`.
        for zone in keyboard logo lightbar lid rear-glow; do
          ${pkgs.asusctl}/bin/asusctl aura power "$zone" --boot --awake --shutdown || true
        done
        # Setting the Aura effect above re-enables the backlight, so re-assert the
        # AC-appropriate level last: dark on battery, full on AC. Mirrors the relog
        # fix in users/kyandesutter/mixins/noctalia.nix (aura-repaint).
        ${kbdDim} ac || true
      '';
    };
  };
}
