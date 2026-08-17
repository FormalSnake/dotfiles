{ config, lib, pkgs, osConfig ? { }, ... }:
let
  flexoki = import ./flexoki/palette.nix;
  inherit (flexoki) accents base;
  stripHash = lib.removePrefix "#";

  # Same shell selector as mixins/hyprland.nix, so the launcher button opens
  # whichever shell owns the session rather than a second one.
  useFormalshell = (((osConfig.kyan or { }).desktop or { }).shell or "dms") == "formalshell";
  launcher =
    if useFormalshell then
      "${config.programs.formalshell.package}/bin/formalshell ipc --any-display call menu toggle"
    else
      "${config.programs.dank-material-shell.package}/bin/dms ipc call spotlight toggle";

  # Herdr agent state, written by dualsense-herdr and read back by
  # dualsense-sync. Runtime dir, not the cache: a state that outlives the
  # session would paint a stale colour at the next login.
  stateFile = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/dualsense-herdr"'';

  # One setter for both surfaces the DualSense can show while it sits on the
  # desk: the lightbar carries agent state when there is any and the wallpaper
  # accent otherwise, the player LEDs carry the laptop battery as a 1-5 step
  # gauge. Every other unit here funnels through this script, so the two
  # inputs can never disagree about what the controller is showing.
  #
  # Written through hid-playstation's LED class, not dualsensectl: over
  # Bluetooth its hidraw output reports exit 0 and never reach the controller.
  # modules/nixos/mixins/dualsense.nix carries the udev rule that makes these
  # attributes group-writable, and the note about why.
  #
  # The node names are keyed to the controller's input device index, which
  # changes on every reconnect, so they can only be globbed. First match wins;
  # a second controller would need a way to say which one this is about.
  dualsenseSync = pkgs.writeShellApplication {
    name = "dualsense-sync";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      shopt -s nullglob
      rgb=(/sys/class/leds/input*:rgb:indicator)
      [ ''${#rgb[@]} -gt 0 ] || exit 0
      lightbar="''${rgb[0]}"
      base="''${lightbar%:rgb:indicator}"

      # Agent state outranks the wallpaper accent: the lightbar is the only
      # thing on the desk that can say "an agent is waiting on you" while the
      # screen shows something else.
      case "$(cat ${stateFile} 2>/dev/null || true)" in
        blocked) colour=${stripHash accents.red.d} ;;
        working) colour=${stripHash accents.yellow.d} ;;
        # Rendered by matugen's [templates.dualsense] block (dms.nix) on every
        # wallpaper/light-dark change. The seed matches power-tune's fallback
        # so a first boot before the first retheme doesn't blank the lightbar.
        *)       colour="$(cat "$HOME/.cache/dank/dualsense-color" 2>/dev/null || true)" ;;
      esac
      [ -n "$colour" ] || colour=b15bf5
      printf '%d %d %d\n' \
        "$((16#''${colour:0:2}))" "$((16#''${colour:2:2}))" "$((16#''${colour:4:2}))" \
        > "$lightbar/multi_intensity"

      # Unlike dualsensectl's symmetric player patterns, the individual LEDs
      # fill from one end, so this reads as a bar.
      cap="$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)"
      lit=$(( (cap + 19) / 20 ))
      [ "$lit" -ge 1 ] || lit=1
      [ "$lit" -le 5 ] || lit=5
      for i in 1 2 3 4 5; do
        led="$base:white:player-$i"
        [ -e "$led/brightness" ] || continue
        if [ "$i" -le "$lit" ]; then echo 1 > "$led/brightness"; else echo 0 > "$led/brightness"; fi
      done
    '';
  };

  # Herdr runs on the macbook and the controller is on this host, so the agent
  # states arrive over SSH. Herdr has no event stream to subscribe to — the
  # CLI is request/response over a unix socket and `--remote` only tunnels the
  # TUI — so this polls, and the loop runs on the *remote* side of one
  # long-lived connection rather than paying an SSH handshake every tick.
  #
  # ClearAllForwardings: the macbook host entry in mixins/ssh.nix carries
  # LocalForwards that a second connection can't bind, and their failures
  # would otherwise land in this unit's log every reconnect.
  #
  # No agent needed: the g815's on-disk key opens the mac directly, so this
  # works from a user service with no SSH_AUTH_SOCK. It never sudos.
  dualsenseHerdr = pkgs.writeShellApplication {
    name = "dualsense-herdr";
    runtimeInputs = with pkgs; [ openssh jq coreutils dualsenseSync dualsenseRumble ];
    text = ''
      # The mac's login shell is fish, which can't parse a `while :; do` loop,
      # so the remote side is handed to bash explicitly. Absolute path for the
      # same reason non-interactive fish needs one for darwin-rebuild: minimal
      # PATH.
      herdr=/etc/profiles/per-user/kyandesutter/bin/herdr
      last=""
      ssh -o BatchMode=yes -o ClearAllForwardings=yes -o ConnectTimeout=10 \
          -o ServerAliveInterval=15 -o ServerAliveCountMax=2 macbook \
          "bash -c 'while :; do $herdr agent list 2>/dev/null || echo null; sleep 2; done'" |
      while read -r line; do
        state="$(printf '%s' "$line" | jq -r '
          [.result.agents[]?.agent_status] as $s
          | if ($s | index("blocked")) then "blocked"
            elif ($s | index("working")) then "working"
            else "idle" end' 2>/dev/null || echo idle)"
        [ "$state" != "$last" ] || continue
        last="$state"
        printf '%s\n' "$state" > ${stateFile}
        dualsense-sync || true
        # Only on the way into blocked: a buzz every poll would be a pager.
        if [ "$state" = blocked ]; then
          dualsense-rumble || true
        fi
      done
    '';
  };

  # Waybar-JSON for FormalShell's `command` bar module (mixins/formalshell.nix
  # registers it as custom:dualsense). Empty text when no controller is
  # attached, which is what keeps the cell out of the way the rest of the time.
  # Same sysfs-over-dualsensectl reasoning as the sync; hid-playstation
  # publishes the pack as a power supply named after the controller's MAC.
  # Capacity comes in 10% buckets, never finer.
  dualsenseBar = pkgs.writeShellApplication {
    name = "dualsense-bar";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      shopt -s nullglob
      supply=(/sys/class/power_supply/ps-controller-battery-*)
      if [ ''${#supply[@]} -eq 0 ]; then
        printf '{"text":"","tooltip":"","class":""}\n'
        exit 0
      fi

      cap="$(cat "''${supply[0]}/capacity" 2>/dev/null || echo 0)"
      status="$(cat "''${supply[0]}/status" 2>/dev/null || echo Unknown)"
      class=""
      [ "$cap" -gt 20 ] || class="warning"
      [ "$cap" -gt 10 ] || class="critical"

      printf '{"text":"DS %s%%","tooltip":"DualSense — %s%%, %s","class":"%s"}\n' \
        "$cap" "$cap" "$status" "$class"
    '';
  };
  # On-screen keyboard. FormalShell has no keyboard surface of its own (its
  # only virtual-keyboard use is wtype for emoji auto-typing), so this is
  # wvkbd, which speaks the same zwp_virtual_keyboard protocol. Start/stop
  # rather than --hidden plus SIGUSR1/2: one code path, no state to track, and
  # it comes up fast enough that the difference isn't visible. Flexoki tones
  # so it doesn't arrive as a white slab over a dark session.
  dualsenseOsk = pkgs.writeShellApplication {
    name = "dualsense-osk";
    runtimeInputs = with pkgs; [ wvkbd procps ];
    text = ''
      if pkill -x wvkbd-mobintl; then
        exit 0
      fi
      exec wvkbd-mobintl -L 380 --fn "monospace 18" \
        --bg ${stripHash base.b950} --fg ${stripHash base.b900} \
        --fg-sp ${stripHash base.b850} --press ${stripHash accents.blue.l} \
        --press-sp ${stripHash accents.blue.l} \
        --text ${stripHash base.b200} --text-sp ${stripHash base.b300}
    '';
  };

  # A buzz for the one state you can't see: an agent that stopped and wants
  # an answer. hid-playstation implements force feedback, so this goes through
  # evdev rather than dualsensectl (whose Bluetooth writes never land).
  # dualsense-herdr calls it on the transition into blocked, never on a repeat.
  dualsenseRumble = pkgs.writers.writePython3Bin "dualsense-rumble"
    {
      libraries = [ pkgs.python3Packages.evdev ];
      flakeIgnore = [ "E501" ];
    } ''
    import time

    import evdev
    from evdev import ecodes as e, ff

    PAD = "DualSense Wireless Controller"


    def find_pad():
        for path in evdev.list_devices():
            try:
                dev = evdev.InputDevice(path)
            except OSError:
                continue
            if dev.name == PAD:
                return dev
            dev.close()
        return None


    def main():
        dev = find_pad()
        if dev is None:
            return
        rumble = ff.Rumble(strong_magnitude=0xC000, weak_magnitude=0x8000)
        effect = ff.Effect(
            e.FF_RUMBLE, -1, 0,
            ff.Trigger(0, 0),
            ff.Replay(350, 0),
            ff.EffectType(ff_rumble_effect=rumble),
        )
        effect_id = dev.upload_effect(effect)
        dev.write(e.EV_FF, effect_id, 1)
        # The kernel plays the effect asynchronously; erasing it immediately
        # cancels it, so wait out the replay length first.
        time.sleep(0.4)
        dev.erase_effect(effect_id)


    main()
  '';

  # The controller as a desk remote. Hyprland has no gamepad input path of its
  # own, so this reads evdev directly and drives three sinks: hyprctl for
  # window and workspace verbs, wpctl for volume, and a uinput pointer for the
  # sticks. It deliberately does NOT grab the pad — a grab would hide it from
  # anything that actually wants to be played with.
  #
  #   d-pad left/right   walk windows along the scrolling tape
  #   d-pad up/down      previous/next workspace
  #   L1/R1              same walk as the d-pad, for one-handed use
  #   cross              launcher
  #   circle             close window
  #   triangle           fullscreen toggle
  #   square             maximize toggle
  #   PS                 on-screen keyboard
  #   right stick        pointer, left stick scrolls
  #   stick clicks       right = left button, left = right button
  #   L2/R2              volume down/up, rate follows how far they're pressed
  #
  # Same dispatchers as the mod+H/L, mod+Q and mod+scroll binds in
  # mixins/hyprland.nix, so the controller can't drift from the keyboard.
  # `hyprctl dispatch` takes Lua since 0.55 (it wraps the argument in
  # hl.dispatch(...)), hence expressions rather than the old "layoutmsg focus
  # l" strings.
  #
  # Sticks and triggers are absolute 0-255 axes that only report on change, so
  # they can't be handled event-by-event: the loop keeps the last value and
  # applies it on a 60Hz tick. A hat, by contrast, reports once on press and
  # once on release with no auto-repeat, so holding a direction steps once.
  dualsensePad = pkgs.writers.writePython3Bin "dualsense-pad"
    {
      libraries = [ pkgs.python3Packages.evdev ];
      flakeIgnore = [ "E501" ];
    } ''
    import math
    import select
    import subprocess
    import time

    import evdev
    from evdev import ecodes as e

    # Exact match: the touchpad and motion sensors are separate devices whose
    # names extend this one.
    PAD = "DualSense Wireless Controller"
    HYPRCTL = "${pkgs.hyprland}/bin/hyprctl"
    WPCTL = "${pkgs.wireplumber}/bin/wpctl"

    TICK = 1.0 / 60
    # Sticks rest at 128 and jitter a point or two either side, so the
    # deadzone is not optional. Past it the response is squared: small
    # deflections stay slow enough to land on a target.
    DEADZONE = 0.12
    POINTER_PX_S = 900.0
    SCROLL_NOTCH_S = 14.0
    # Triggers rest at 0 and travel to 255. wpctl is spawned per step, so the
    # step rate is capped well below the tick rate.
    TRIGGER_DEADZONE = 30
    VOLUME_INTERVAL = 0.12


    def dispatch(lua):
        return [HYPRCTL, "dispatch", lua]


    BUTTONS = {
        e.BTN_TL: dispatch('hl.dsp.layout("focus l")'),
        e.BTN_TR: dispatch('hl.dsp.layout("focus r")'),
        e.BTN_SOUTH: [${lib.concatMapStringsSep ", " builtins.toJSON (lib.splitString " " launcher)}],
        e.BTN_EAST: dispatch('hl.dsp.window.close()'),
        e.BTN_NORTH: dispatch('hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" })'),
        e.BTN_WEST: dispatch('hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" })'),
        e.BTN_MODE: ["${dualsenseOsk}/bin/dualsense-osk"],
    }

    HATS = {
        (e.ABS_HAT0X, -1): dispatch('hl.dsp.layout("focus l")'),
        (e.ABS_HAT0X, 1): dispatch('hl.dsp.layout("focus r")'),
        (e.ABS_HAT0Y, -1): dispatch('hl.dsp.focus({ workspace = "e-1" })'),
        (e.ABS_HAT0Y, 1): dispatch('hl.dsp.focus({ workspace = "e+1" })'),
    }

    CLICKS = {e.BTN_THUMBR: e.BTN_LEFT, e.BTN_THUMBL: e.BTN_RIGHT}

    POINTER_CAPS = {
        e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_HWHEEL],
        e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT],
    }


    def find_pad():
        for path in evdev.list_devices():
            try:
                dev = evdev.InputDevice(path)
            except OSError:
                continue
            if dev.name == PAD:
                return dev
            dev.close()
        return None


    def curve(value):
        """0-255 axis to -1.0..1.0, deadzoned and squared."""
        norm = (value - 128) / 127.0
        if abs(norm) < DEADZONE:
            return 0.0
        scaled = (abs(norm) - DEADZONE) / (1.0 - DEADZONE)
        return math.copysign(scaled * scaled, norm)


    def volume_step(axes, last):
        now = time.monotonic()
        if now - last < VOLUME_INTERVAL:
            return last
        up = axes[e.ABS_RZ]
        down = axes[e.ABS_Z]
        depth = max(up, down)
        if depth <= TRIGGER_DEADZONE:
            return last
        span = 255 - TRIGGER_DEADZONE
        percent = 1 + int(4 * (depth - TRIGGER_DEADZONE) / span)
        sign = "+" if up >= down else "-"
        subprocess.run(
            [WPCTL, "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", f"{percent}%{sign}"],
            check=False,
        )
        return now


    def pump(dev, pointer):
        axes = {e.ABS_X: 128, e.ABS_Y: 128, e.ABS_RX: 128, e.ABS_RY: 128, e.ABS_Z: 0, e.ABS_RZ: 0}
        # Fractional pixels and notches carry across ticks, so a slow push
        # still moves instead of rounding to nothing every frame.
        carry = {e.REL_X: 0.0, e.REL_Y: 0.0, e.REL_WHEEL: 0.0, e.REL_HWHEEL: 0.0}
        last_volume = 0.0

        while True:
            ready, _, _ = select.select([dev.fd], [], [], TICK)
            if ready:
                for event in dev.read():
                    if event.type == e.EV_ABS:
                        if event.code in (e.ABS_HAT0X, e.ABS_HAT0Y):
                            action = HATS.get((event.code, event.value))
                            if action is not None:
                                subprocess.run(action, check=False)
                        elif event.code in axes:
                            axes[event.code] = event.value
                    elif event.type == e.EV_KEY:
                        if event.code in CLICKS:
                            pointer.write(e.EV_KEY, CLICKS[event.code], event.value)
                            pointer.syn()
                        elif event.value == 1 and event.code in BUTTONS:
                            subprocess.run(BUTTONS[event.code], check=False)

            carry[e.REL_X] += curve(axes[e.ABS_RX]) * POINTER_PX_S * TICK
            carry[e.REL_Y] += curve(axes[e.ABS_RY]) * POINTER_PX_S * TICK
            # Pushing up reads as a decreasing axis, and a positive wheel is
            # scroll-up, so the vertical sign flips here.
            carry[e.REL_WHEEL] += -curve(axes[e.ABS_Y]) * SCROLL_NOTCH_S * TICK
            carry[e.REL_HWHEEL] += curve(axes[e.ABS_X]) * SCROLL_NOTCH_S * TICK

            moved = False
            for code, value in carry.items():
                whole = int(value)
                if whole:
                    carry[code] = value - whole
                    pointer.write(e.EV_REL, code, whole)
                    moved = True
            if moved:
                pointer.syn()

            last_volume = volume_step(axes, last_volume)


    def main():
        pointer = evdev.UInput(POINTER_CAPS, name="dualsense-pointer")
        while True:
            dev = find_pad()
            if dev is None:
                time.sleep(5)
                continue
            try:
                pump(dev, pointer)
            except OSError:
                # Controller went away mid-read; fall back to scanning.
                time.sleep(2)


    main()
  '';
in
{
  home.packages = [
    pkgs.dualsensectl
    dualsenseSync
    dualsenseBar
    dualsensePad
    dualsenseOsk
    dualsenseRumble
  ];

  # Hotplug: dualsensectl's own udev watcher, so a controller that wakes up or
  # reconnects over Bluetooth is painted immediately instead of waiting for the
  # drift timer. It keeps running with no controller attached, so this is a
  # plain long-lived unit. The LED nodes appear slightly after the hidraw one,
  # hence the settle sleep before the sync.
  systemd.user.services.dualsense-sync = {
    Unit = {
      Description = "Paint the DualSense lightbar and player LEDs on hotplug";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.dualsensectl}/bin/dualsensectl monitor add ${pkgs.writeShellScript "dualsense-settle" ''
        sleep 2
        exec ${dualsenseSync}/bin/dualsense-sync
      ''}";
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

  # Scans for the pad itself and keeps scanning, so it needs no hotplug hook.
  systemd.user.services.dualsense-pad = {
    Unit = {
      Description = "DualSense D-pad as a window and workspace remote";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dualsensePad}/bin/dualsense-pad";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Restart on failure covers the mac being asleep or off the network: the
  # unit dies with the connection and comes back when the mac does. The state
  # file is left alone on the way out, so a dropped link keeps showing the
  # last known state rather than flapping back to the accent.
  systemd.user.services.dualsense-herdr = {
    Unit = {
      Description = "Mirror herdr agent state onto the DualSense lightbar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${dualsenseHerdr}/bin/dualsense-herdr";
      Restart = "always";
      RestartSec = 30;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
