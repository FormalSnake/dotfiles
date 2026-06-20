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

  # System power reconciler — the single automatic owner of the power profile,
  # and the authority that publishes the current power source to the user session
  # via /run/power/state. Triggered by udev on any ADP0 or ucsi-source-psy change
  # (and at boot via the service's wantedBy PPD). PPD is the backend the noctalia
  # bar reads/writes (UPower → net.hadess.PowerProfiles), so this is what makes the
  # shell show the right profile without manual toggling.
  #
  # The 1.5s settle is essential: plugging a power bank lands ADP0=online *before*
  # the USB-C PD contract negotiates, so an immediate read would misclassify it as
  # `ac`. Waiting lets the UCSI source come up (the UCSI udev event also
  # re-triggers this, so it always converges). Because the canonical state is only
  # written post-settle, every downstream consumer can trust it without its own
  # debounce.
  #
  # `performance` can be unavailable when the daemon reports degradation, so we
  # fall back to balanced rather than fail.
  powerReconcile = pkgs.writeShellApplication {
    name = "power-reconcile";
    runtimeInputs = [
      pkgs.coreutils
      powerSource
      config.services.power-profiles-daemon.package
    ];
    text = ''
      sleep 1.5
      src="$(power-source)"
      printf '%s\n' "$src" > /run/power/state
      if [ "$src" = ac ]; then
        powerprofilesctl set performance 2>/dev/null || powerprofilesctl set balanced || true
      else
        powerprofilesctl set power-saver 2>/dev/null || powerprofilesctl set balanced || true
      fi
    '';
  };

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
  # Wayland idle-inhibit lock for the duration so noctalia's idle service never
  # fires its action. We configure noctalia with screen-off@11m (see noctalia.nix)
  # which `respectInhibitors`; the inhibitor suppresses it so the session stays
  # fully awake for an overnight download. We blank the screens ourselves (dpms
  # off) since the inhibitor also suppresses noctalia's own auto screen-off —
  # they wake on any input.
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
        # overnight. `off` repaints them the current wallpaper-derived accent.
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
        # Repaint the Aura keyboard. Restore the *current* wallpaper-derived accent
        # that noctalia's `aura` template caches to ~/.cache/noctalia/aura-color
        # (see users/kyandesutter/mixins/noctalia.nix), falling back to the
        # Catppuccin Mauve seed if noctalia hasn't generated a palette yet.
        aura_colour="$(cat "$HOME/.cache/noctalia/aura-color" 2>/dev/null || echo ${auraColour})"
        asusctl aura effect static -c "$aura_colour" || true
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

      # power-profiles-daemon: the profile backend the noctalia bar reads and
      # writes. The bare Hyprland session doesn't pull it in (no desktop manager
      # does), so without it the bar is stuck showing a static "Balanced" it
      # can't change. Coexists with asusd, which keeps Aura/fan/charge-limit
      # duties; PPD owns the platform profile (the kernel asus-wmi interface).
      services.power-profiles-daemon.enable = true;

      # Publish /run/power/state for the user session to subscribe to.
      systemd.tmpfiles.rules = [ "d /run/power 0755 root root -" ];

      # Drive PPD + publish the power source. Bound to PPD itself (wantedBy
      # power-profiles-daemon), so it runs right after PPD comes up at boot, plus
      # on every ADP0 / ucsi-source-psy change (udev rules below).
      #
      # NOTE: do NOT use `wantedBy = multi-user.target` here. nixpkgs orders PPD
      # `After=multi-user.target` (it belongs to graphical.target), so pinning a
      # unit that is `After=power-profiles-daemon.service` to multi-user.target
      # closes an ordering loop (multi-user → power-reconcile → PPD →
      # multi-user). systemd can't break it and drops the whole transaction,
      # failing sysinit/basic/NetworkManager at switch/boot.
      systemd.services.power-reconcile = {
        description = "Power profile + /run/power/state follow the power source (AC / power bank / battery)";
        after = [ "power-profiles-daemon.service" ];
        wants = [ "power-profiles-daemon.service" ];
        wantedBy = [ "power-profiles-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${powerReconcile}/bin/power-reconcile";
        };
      };

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
          seed=/home/kyandesutter/.cache/noctalia/aura-color
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

      # power-source is the shared classifier; expose it on PATH so the user
      # session (env-hyprland, power-tune) can call it via /run/current-system.
      environment.systemPackages = [ powerSource ];

      # Re-run the reconciler on any power-source change. We watch BOTH the ACPI
      # mains adapter (ADP0 — barrel) and the USB-C PD sources (ucsi-source-psy-*
      # — a power bank), since a power bank lands ADP0=online before its UCSI
      # source negotiates; the second (UCSI) event is what lets the reconciler's
      # post-settle read see the power bank for what it is. The keyboard LEDs are
      # no longer driven from here — the user session owns live AC/battery
      # following (power-tune / aura-repaint) so there is a single keyboard owner.
      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", KERNEL=="ADP0", RUN+="${config.systemd.package}/bin/systemctl --no-block restart power-reconcile.service"
        SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-*", RUN+="${config.systemd.package}/bin/systemctl --no-block restart power-reconcile.service"
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
