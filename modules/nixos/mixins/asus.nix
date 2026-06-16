{ config, lib, pkgs, ... }:
let
  # Catppuccin Mocha "Mauve" — the accent painted on the Aura keyboard.
  auraColour = "cba6f7";

  # Toggle the keyboard backlight brightness node directly (0..max). Driven by
  # the udev rule below so dimming on battery works in the udev run context
  # without depending on the asusd dbus service being up.
  kbdDim = pkgs.writeShellScript "asus-kbd-dim" ''
    led=/sys/class/leds/asus::kbd_backlight
    [ -e "$led/brightness" ] || exit 0
    max=$(cat "$led/max_brightness" 2>/dev/null || echo 3)
    case "''${1:-}" in
      on)  echo "$max" > "$led/brightness" ;;
      off) echo 0      > "$led/brightness" ;;
    esac
  '';

  # game-mode: a no-relog runtime toggle. Flips the asusd platform profile
  # (fans/power) between Performance and Balanced. Per-game CPU governor/niceness
  # is handled separately by `gamemode` when a title launches. No GPU mode switch
  # (that would need a relog) — games already run on the dGPU via
  # `gamescope` / `nvidia-offload`.
  game-mode = pkgs.writeShellApplication {
    name = "game-mode";
    runtimeInputs = [
      pkgs.asusctl
      pkgs.libnotify
    ];
    text = ''
      action="''${1:-toggle}"

      current() { asusctl profile -p 2>/dev/null | grep -oiE 'Performance|Balanced|Quiet' | head -n1; }

      on() {
        asusctl profile -P Performance
        notify-send -a "game-mode" "Game mode ON" "asusd profile → Performance" || true
        echo "Game mode ON (Performance)"
      }
      off() {
        asusctl profile -P Balanced
        notify-send -a "game-mode" "Game mode OFF" "asusd profile → Balanced" || true
        echo "Game mode OFF (Balanced)"
      }

      case "$action" in
        on)     on ;;
        off)    off ;;
        status) echo "Current profile: $(current)" ;;
        toggle)
          if [ "$(current)" = "Performance" ]; then off; else on; fi ;;
        *) echo "usage: game-mode [on|off|toggle|status]" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  options.kyan.asus.enable =
    lib.mkEnableOption "ASUS laptop support (asusd, Aura RGB, battery charge limit)";

  config = lib.mkMerge [
    (lib.mkIf config.kyan.asus.enable {
      # asusd: fan curves, power/platform profiles, Aura keyboard LEDs.
      # (supergfxd is intentionally omitted — MUX switching needs a relog.)
      services.asusd.enable = true;

      # After asusd is up: paint the keyboard Catppuccin Mauve and cap the
      # battery charge at 80% for longevity. `|| true` so a CLI/permission
      # hiccup never fails the boot.
      systemd.services.asus-aura = {
        description = "Aura keyboard Catppuccin Mauve + 80% charge limit";
        after = [ "asusd.service" ];
        requires = [ "asusd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.asusctl}/bin/asusctl aura effect static -c ${auraColour} || true
          ${pkgs.asusctl}/bin/asusctl battery limit 80 || true
        '';
      };

      # Dim the keyboard LEDs on battery, restore to full on AC. The static
      # Mauve effect set by asusd is preserved across brightness changes.
      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="0", RUN+="${kbdDim} off"
        SUBSYSTEM=="power_supply", KERNEL=="ADP0", ATTR{online}=="1", RUN+="${kbdDim} on"
      '';
    })

    (lib.mkIf config.kyan.gaming.enable {
      # game-mode needs asusctl/asusd; the g815 host enables kyan.asus too.
      environment.systemPackages = [ game-mode ];
    })
  ];
}
