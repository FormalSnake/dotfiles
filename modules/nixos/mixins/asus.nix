{ config, lib, pkgs, ... }:
let
  # Catppuccin Mocha "Mauve" — the accent painted on the Aura keyboard.
  # Deepened from the on-screen value (cba6f7) to compensate for the LEDs: the
  # pastel mauve renders too white on the keyboard, so we drop lightness and
  # bump saturation (HSL 272/89/66) to read as the intended purple.
  auraColour = "b15bf5";

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

  # Follow AC state with the power-profiles-daemon profile: Performance on AC,
  # Balanced on battery. PPD is the backend the caelestia bar reads/writes
  # (Quickshell UPower → net.hadess.PowerProfiles), so this is what makes the
  # shell show "Performance" plugged in without manual toggling. Reads ADP0
  # itself so a single udev rule on any power_supply change does the right thing.
  # `performance` can be unavailable when the daemon reports degradation, so we
  # fall back to balanced rather than fail.
  powerProfileSync = pkgs.writeShellScript "power-profile-ac" ''
    ppctl=${config.services.power-profiles-daemon.package}/bin/powerprofilesctl
    online=$(cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 1)
    if [ "$online" = "1" ]; then
      "$ppctl" set performance 2>/dev/null || "$ppctl" set balanced || true
    else
      "$ppctl" set balanced || true
    fi
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

      current() { asusctl profile get 2>/dev/null | grep -oiE 'Performance|Balanced|Quiet' | head -n1; }

      on() {
        asusctl profile set Performance
        notify-send -a "game-mode" "Game mode ON" "asusd profile → Performance" || true
        echo "Game mode ON (Performance)"
      }
      off() {
        asusctl profile set Balanced
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

  # night-mode: a quiet overnight-download mode. Sets the asusd platform profile
  # to Quiet (gentlest fan curve) and PPD to power-saver (caps CPU boost → less
  # heat → fans stay down), turns the displays and Aura keyboard LEDs off, and —
  # crucially — holds a
  # Wayland idle-inhibit lock for the duration so caelestia's idle daemon never
  # fires its timeouts. Those default to lock@3m, dpms-off@5m and
  # `systemctl suspend-then-hibernate`@10m, and all of them `respectInhibitors`;
  # the 10-minute suspend is what would otherwise pause a Steam download
  # overnight. We blank the screens ourselves (dpms off) since the inhibitor
  # also suppresses caelestia's own auto screen-off — they wake on any input.
  night-mode = pkgs.writeShellApplication {
    name = "night-mode";
    runtimeInputs = [
      pkgs.asusctl
      config.services.power-profiles-daemon.package # powerprofilesctl
      pkgs.wlinhibit
      pkgs.hyprland # hyprctl
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      action="''${1:-toggle}"
      pidfile="''${XDG_RUNTIME_DIR:-/tmp}/night-mode-inhibit.pid"
      ppctl=${config.services.power-profiles-daemon.package}/bin/powerprofilesctl

      # ON iff a recorded wlinhibit process is still alive.
      is_on() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; }

      on() {
        asusctl profile set Quiet || true
        "$ppctl" set power-saver || true
        # Blank the Aura keyboard LEDs (static black) so they aren't glowing
        # overnight. `off` repaints them the Catppuccin Mauve set at boot.
        asusctl aura effect static -c 000000 || true
        if ! is_on; then
          # Foreground tool that holds the idle inhibitor until killed; background
          # it and remember the PID so `off` can release it.
          wlinhibit >/dev/null 2>&1 &
          echo "$!" > "$pidfile"
        fi
        notify-send -a "night-mode" "Night mode ON" \
          "Quiet fans · idle suspend blocked · screens + RGB off" || true
        hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' || true
        echo "Night mode ON"
      }

      off() {
        if is_on; then kill "$(cat "$pidfile")" 2>/dev/null || true; fi
        rm -f "$pidfile"
        hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' || true
        asusctl profile set Performance || true
        "$ppctl" set performance 2>/dev/null || "$ppctl" set balanced || true
        # Repaint the Aura keyboard the Catppuccin Mauve set by the asus-aura unit.
        asusctl aura effect static -c ${auraColour} || true
        notify-send -a "night-mode" "Night mode OFF" "Restored Performance" || true
        echo "Night mode OFF"
      }

      case "$action" in
        on)     on ;;
        off)    off ;;
        status) if is_on; then echo "Night mode ON"; else echo "Night mode OFF"; fi ;;
        toggle) if is_on; then off; else on; fi ;;
        *) echo "usage: night-mode [on|off|toggle|status]" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  options.kyan.asus.enable =
    lib.mkEnableOption "ASUS laptop support (asusd, Aura RGB, battery charge limit)";

  config = lib.mkMerge [
    (lib.mkIf config.kyan.asus.enable {
      # asusd: fan curves, Aura keyboard LEDs, battery charge limit.
      # (supergfxd is intentionally omitted — MUX switching needs a relog.)
      services.asusd.enable = true;

      # power-profiles-daemon: the profile backend the caelestia bar reads and
      # writes. The bare Hyprland session doesn't pull it in (no desktop manager
      # does), so without it the bar is stuck showing a static "Balanced" it
      # can't change. Coexists with asusd, which keeps Aura/fan/charge-limit
      # duties; PPD owns the platform profile (the kernel asus-wmi interface).
      services.power-profiles-daemon.enable = true;

      # Drive PPD from AC state: Performance on AC, Balanced on battery. Bound to
      # PPD itself (wantedBy power-profiles-daemon), so it runs right after PPD
      # comes up at boot, plus on every AC plug/unplug (udev rule below).
      #
      # NOTE: do NOT use `wantedBy = multi-user.target` here. nixpkgs orders PPD
      # `After=multi-user.target` (it belongs to graphical.target), so pinning a
      # unit that is `After=power-profiles-daemon.service` to multi-user.target
      # closes an ordering loop (multi-user → power-profile-ac → PPD →
      # multi-user). systemd can't break it and drops the whole transaction,
      # failing sysinit/basic/NetworkManager at switch/boot.
      systemd.services.power-profile-ac = {
        description = "Power profile follows AC (Performance on AC, Balanced on battery)";
        after = [ "power-profiles-daemon.service" ];
        wants = [ "power-profiles-daemon.service" ];
        wantedBy = [ "power-profiles-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = powerProfileSync;
        };
      };

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
        SUBSYSTEM=="power_supply", KERNEL=="ADP0", RUN+="${config.systemd.package}/bin/systemctl --no-block restart power-profile-ac.service"
      '';
    })

    (lib.mkIf config.kyan.gaming.enable {
      # game-mode / night-mode need asusctl/asusd; the g815 host enables kyan.asus too.
      environment.systemPackages = [
        game-mode
        night-mode
      ];
    })
  ];
}
