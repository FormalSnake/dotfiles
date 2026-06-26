{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.kyan.gaming;

  # Catppuccin Mocha "Mauve" — the accent painted on the Aura keyboard.
  # Deepened from the on-screen value (cba6f7) to compensate for the LEDs: the
  # pastel mauve renders too white on the keyboard, so we drop lightness and
  # bump saturation (HSL 272/89/66) to read as the intended purple.
  auraColour = "b15bf5";

  # — Millennium (patched build) —
  # Millennium's `bun-deps` fixed-output derivation pins a hash that our `bun`
  # doesn't reproduce (bun install isn't byte-reproducible across bun versions),
  # and Millennium's cachix doesn't carry the path either — so a from-source build
  # fails with a hash mismatch. Patch that one hash, in a copy of Millennium's nix
  # dir, to the value our bun actually produces, then build the lib + steam from
  # the copy. `${inputs.millennium}` already points at the packages/nix subdir
  # (the input URL has ?dir=packages/nix), so steam.nix/millennium.nix sit at its
  # root. NOTE: if a future nixpkgs bumps `bun`, this hash may need updating — the
  # rebuild error prints the new `got:` value to paste here.
  millenniumBunDepsHash = "sha256-07kSANQ5uLwsLX+wuS0Cq2YSeTqkSVnUBGqadP0Uj4Y=";
  millenniumNix = pkgs.runCommand "millennium-nix-patched" { } ''
    cp -r ${inputs.millennium} "$out"
    chmod -R +w "$out"
    ${pkgs.gnused}/bin/sed -i \
      's|sha256-eVk0KVSIMTGPC0DbdenO/ZCY/fiD1Q9RXj3yKqsHz0Y=|${millenniumBunDepsHash}|' \
      "$out/millennium.nix" || { echo 'millennium hash patch: pattern not found — update millenniumBunDepsHash'; exit 1; }
  '';
  # Build the millennium lib against our nixpkgs (so our bun → our patched hash);
  # its own flake inputs supply the luajit/millennium sources.
  millenniumLib = pkgs.callPackage "${millenniumNix}/millennium.nix" {
    inputs = inputs.millennium.inputs;
    millennium-src = inputs.millennium.inputs.millennium-src;
  };

  # PRIME render-offload env + the launcher-wrapping helper are defined once in
  # ../mixins/nvidia.nix and exposed via an overlay (pkgs.nvidiaOffloadEnv /
  # pkgs.gpuOffloadWrap). See that file for the rationale (push each game
  # launcher onto the dGPU so games use the RTX 5070 with no per-title config).

  # — Keep the screen awake while gaming with a controller —
  # noctalia's idle service uses the Wayland ext-idle-notify protocol, which only
  # resets on keyboard/mouse/touch activity from libinput — gamepad input never
  # counts. So a controller-only session keeps counting down and hits the
  # configured idle action (screen-off@11m; see noctalia.nix). The idle monitor
  # respects inhibitors, so holding a standard Wayland idle inhibitor (wlinhibit,
  # exactly as night-mode already does) fully suppresses them. Two complementary
  # holders cover the two cases:
  #   1. game-inhibit — driven by the gamemode start/end hooks below, so the
  #      screen stays on for the whole lifetime of any gamemode-aware title
  #      (Steam/Proton, Lutris, Heroic) regardless of input device — including
  #      input-free stretches like cutscenes or turn-based thinking.
  #   2. gamepad-idle-inhibit — a session daemon that watches evdev gamepads and
  #      holds the inhibitor while a controller is actively used, covering apps
  #      that never trigger gamemode (emulators, browser/cloud games, couch media).

  # 1. wlinhibit holder toggled by the gamemode hooks. Mirrors night-mode's
  #    pidfile pattern so `end` releases exactly the process `start` spawned.
  gameInhibit = pkgs.writeShellApplication {
    name = "game-inhibit";
    runtimeInputs = [ pkgs.wlinhibit pkgs.coreutils ];
    text = ''
      pidfile="''${XDG_RUNTIME_DIR:-/tmp}/game-inhibit.pid"
      is_on() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; }
      case "''${1:-}" in
        on)  if ! is_on; then wlinhibit >/dev/null 2>&1 & echo "$!" > "$pidfile"; fi ;;
        off) if is_on; then kill "$(cat "$pidfile")" 2>/dev/null || true; fi; rm -f "$pidfile" ;;
        *)   echo "usage: game-inhibit on|off" >&2; exit 1 ;;
      esac
    '';
  };

  # 2. evdev gamepad-activity watcher. Holds wlinhibit while a real gamepad is in
  #    active use and releases it after GAMEPAD_IDLE_SECS of no input. Filters to
  #    devices that expose BTN_GAMEPAD-range keys, so the Keychron keyboard's
  #    stray "joystick" interface (it also shows up under /dev/input/by-id) is
  #    ignored, and uses each axis's flat/fuzz deadzone so resting hall-effect
  #    sticks don't register as activity. Reads /dev/input/event* — the logged-in
  #    user gets access via logind's uaccess ACL on the seat's input devices.
  gamepadWatcherPy = pkgs.writeText "gamepad-idle-inhibit.py" ''
    import os
    import select
    import subprocess
    import time

    import evdev
    from evdev import ecodes

    IDLE_SECS = int(os.environ.get("GAMEPAD_IDLE_SECS", "120"))
    RESCAN_SECS = 5


    def is_gamepad(dev):
        try:
            caps = dev.capabilities()
        except OSError:
            return False
        keys = caps.get(ecodes.EV_KEY, [])
        # BTN_GAMEPAD..BTN_THUMBR occupy 0x130-0x13f; their presence marks a pad.
        return any(0x130 <= k <= 0x13f for k in keys)


    def open_gamepads():
        out = {}
        for path in evdev.list_devices():
            try:
                dev = evdev.InputDevice(path)
            except OSError:
                continue
            if is_gamepad(dev):
                out[path] = dev
            else:
                dev.close()
        return out


    def axis_deadzones(dev):
        # Per-axis movement threshold and resting value, from the kernel absinfo.
        thresholds = {}
        baseline = {}
        try:
            axes = dict(dev.capabilities().get(ecodes.EV_ABS, []))
        except OSError:
            return thresholds, baseline
        for code, info in axes.items():
            span = info.max - info.min
            thresholds[code] = max(info.flat, info.fuzz, span // 16, 1)
            baseline[code] = info.value
        return thresholds, baseline


    class Inhibitor:
        def __init__(self):
            self.proc = None

        def on(self):
            if self.proc is None or self.proc.poll() is not None:
                self.proc = subprocess.Popen(
                    ["wlinhibit"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )

        def off(self):
            if self.proc is not None and self.proc.poll() is None:
                self.proc.terminate()
                try:
                    self.proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.proc.kill()
            self.proc = None


    def main():
        devices = {}
        thresholds = {}
        baseline = {}
        last_activity = 0.0
        last_scan = 0.0
        inhibitor = Inhibitor()
        try:
            while True:
                now = time.monotonic()
                if now - last_scan >= RESCAN_SECS:
                    current = open_gamepads()
                    for path in list(devices):
                        if path not in current:
                            devices[path].close()
                            del devices[path]
                            thresholds.pop(path, None)
                            baseline.pop(path, None)
                    for path, dev in current.items():
                        if path in devices:
                            dev.close()  # already tracking it; drop the dup handle
                        else:
                            devices[path] = dev
                            thresholds[path], baseline[path] = axis_deadzones(dev)
                    last_scan = now

                fds = {dev.fd: path for path, dev in devices.items()}
                try:
                    ready, _, _ = select.select(list(fds), [], [], 1.0)
                except OSError:
                    ready = []

                for fd in ready:
                    path = fds.get(fd)
                    dev = devices.get(path) if path else None
                    if dev is None:
                        continue
                    try:
                        for ev in dev.read():
                            if ev.type == ecodes.EV_KEY:
                                last_activity = time.monotonic()
                            elif ev.type == ecodes.EV_ABS:
                                th = thresholds.get(path, {}).get(ev.code, 0)
                                prev = baseline.get(path, {}).get(ev.code)
                                if prev is None or abs(ev.value - prev) > th:
                                    baseline.setdefault(path, {})[ev.code] = ev.value
                                    if prev is not None:
                                        last_activity = time.monotonic()
                    except OSError:
                        pass  # device vanished mid-read; the next rescan drops it

                active = last_activity and time.monotonic() - last_activity < IDLE_SECS
                if active:
                    inhibitor.on()
                else:
                    inhibitor.off()
        finally:
            inhibitor.off()


    if __name__ == "__main__":
        main()
  '';
  gamepadWatcherEnv = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  gamepadWatcher = pkgs.writeShellApplication {
    name = "gamepad-idle-inhibit";
    runtimeInputs = [ gamepadWatcherEnv pkgs.wlinhibit ];
    text = ''exec python3 ${gamepadWatcherPy} "$@"'';
  };

  # — Equibop with WebRTC mic auto-gain disabled —
  # Equibop is Electron (Chromium under the hood). On Linux specifically,
  # Chromium's WebRTC stack is allowed to reach into PipeWire and ride the
  # *hardware* input gain of the capture device up/down to hit a loudness
  # target — so during a call the mic "gradually gets quieter" and the source
  # slider visibly drops (the Razer was found pulled down to 0.79). On
  # Windows/macOS the same AGC runs purely inside Chromium's own pipeline and
  # never touches the OS slider, which is why this is a Linux-only symptom.
  # The fix Equibop's own wiki recommends (https://equibop.org/wiki/linux/tips/)
  # is to launch with `--disable-features=WebRtcAllowInputVolumeAdjustment`.
  # The NixOS equibop wrapper just execs electron and ignores the usual
  # `equibop-flags.conf`, so the flag is injected at the package level here —
  # this way it applies regardless of launch path (Hyprland autostart, the
  # `Exec=equibop` .desktop entry, or a terminal).
  equibopNoAgc = pkgs.symlinkJoin {
    name = "equibop-no-agc";
    paths = [ pkgs.equibop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/equibop \
        --add-flags "--disable-features=WebRtcAllowInputVolumeAdjustment"
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
        # Restore the profile that matches the CURRENT power source, mirroring the
        # system power reconciler (modules/nixos/mixins/power.nix): AC →
        # Performance/performance, battery or power bank → Balanced/power-saver.
        # night-mode runs as the user and can't trigger the root-owned
        # power-reconcile.service, so we replicate its mapping here. The `|| echo ac`
        # keeps the old always-Performance behaviour if the classifier is absent.
        if [ "$(/run/current-system/sw/bin/power-source 2>/dev/null || echo ac)" = ac ]; then
          asusctl profile set Performance || true
          "$ppctl" set performance 2>/dev/null || "$ppctl" set balanced || true
        else
          asusctl profile set Balanced || true
          "$ppctl" set power-saver 2>/dev/null || "$ppctl" set balanced || true
        fi
        # Repaint the Aura keyboard. Restore the *current* wallpaper-derived accent
        # that noctalia's `aura` template caches to ~/.cache/noctalia/aura-color
        # (see users/kyandesutter/mixins/noctalia.nix), falling back to the
        # Catppuccin Mauve seed if noctalia hasn't generated a palette yet.
        aura_colour="$(cat "$HOME/.cache/noctalia/aura-color" 2>/dev/null || echo ${auraColour})"
        asusctl aura effect static -c "$aura_colour" || true
        notify-send -a "night-mode" "Night mode OFF" "Restored power profile for the current source" || true
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
  options.kyan.gaming.enable = lib.mkEnableOption "gaming stack (Steam, gamescope, gamemode, launchers)";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
      # Big Picture / "console mode" session: render gamescope itself and the
      # Steam client on the dGPU too, so the tenfoot UI isn't stuck on the iGPU.
      gamescopeSession.env = pkgs.nvidiaOffloadEnv;
      protontricks.enable = true;
      # Proton-GE shows up in Steam's compatibility-tool dropdown.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      # Millennium-patched Steam (Steam Homebrew) — enables the client themes the
      # Noctalia "steam" community template targets (Material-Theme skin; see
      # users/kyandesutter/mixins/noctalia.nix). Built from Millennium's own
      # steam.nix rather than the flake's prebuilt `millennium-steam` so we keep
      # the dGPU-offload extraEnv (the prebuilt package defaults extraEnv to {},
      # which would drop RTX-5070 offload — desktop client + every game it spawns
      # default to the dGPU via these vars). steam.nix merges Millennium's own libs
      # /env/profile on top, and the steam module merges its compat-tool extraEnv
      # on top of that, so nothing is clobbered.
      # Built from the patched Millennium nix dir (see the let block) so the
      # bun-deps hash matches and the dGPU-offload extraEnv is preserved.
      package = pkgs.callPackage "${millenniumNix}/steam.nix" {
        millennium = millenniumLib;
        extraEnv = pkgs.nvidiaOffloadEnv;
      };
    };

    programs.gamescope = {
      enable = true;
      capSysNice = true; # lets gamescope set nice/rtprio
    };

    # NTSync — kernel-level NT synchronization primitives (CONFIG_NTSYNC, mainlined
    # in Linux 6.14; the CachyOS kernel ships it as a module). Wine/Proton 11+ open
    # /dev/ntsync for semantically-correct, in-kernel sync that fsync only ever
    # approximated (NtPulseEvent, wait-for-all) — the payoff is steadier frame
    # times / fewer stutters in heavily multithreaded titles rather than big
    # average-FPS gains over fsync. Valve already loads it by default in SteamOS.
    # Load the module at boot, and grant the logged-in user access via logind's
    # uaccess ACL (the misc device is otherwise root-only, so Proton can't open it).
    boot.kernelModules = [ "ntsync" ];
    services.udev.extraRules = ''
      KERNEL=="ntsync", MODE="0660", TAG+="uaccess"
    '';

    programs.gamemode = {
      enable = true;
      settings.general = {
        renice = 10;
        # gamemode flips the CPU governor to performance for the running game.
        desiredgov = "performance";
      };
      # Hold a Wayland idle inhibitor for the lifetime of every gamemode-aware
      # title so noctalia never blanks the screen mid-game (see gameInhibit above).
      settings.custom = {
        start = "${gameInhibit}/bin/game-inhibit on";
        end = "${gameInhibit}/bin/game-inhibit off";
      };
    };

    # Catch-all for non-gamemode controller use: a session daemon that suppresses
    # idle while a gamepad is actively used (see gamepadWatcher above). Bound to
    # graphical-session.target like the noctalia shell, so it has the Wayland
    # session env wlinhibit needs and starts/stops with the desktop session.
    systemd.user.services.gamepad-idle-inhibit = {
      description = "Hold a Wayland idle inhibitor while a game controller is active";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${gamepadWatcher}/bin/gamepad-idle-inhibit";
        Restart = "on-failure";
        RestartSec = "5s";
        Slice = "session.slice";
      };
    };

    environment.systemPackages = with pkgs; [
      # game-mode / night-mode need asusctl/asusd; the g815 host enables kyan.asus too.
      game-mode
      night-mode

      # Idle-inhibit helpers (also driven by the gamemode hooks / user service
      # above; exposed here for manual control and testing).
      gameInhibit
      gamepadWatcher

      # Overlays / post-processing (enable per-game via env vars).
      mangohud
      vkbasalt
      protonup-qt # manage extra Proton-GE versions

      # Launchers (Epic / GOG / non-Steam). Wrapped so games launched through
      # them render on the dGPU (PRIME offload) — see ../mixins/nvidia.nix.
      (gpuOffloadWrap lutris)
      (gpuOffloadWrap heroic)

      # Comms / streaming.
      equibopNoAgc # Discord client (Vesktop fork); WebRTC mic-AGC flag baked in (see above)
      obs-studio
    ];
  };
}
