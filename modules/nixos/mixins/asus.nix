{ config, lib, pkgs, ... }:
let
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
  config = lib.mkIf config.kyan.gaming.enable {
    # asusd: fan curves, power/platform profiles, Aura keyboard LEDs.
    # (supergfxd is intentionally omitted — MUX switching needs a relog.)
    services.asusd.enable = true;

    environment.systemPackages = [ game-mode ];
  };
}
