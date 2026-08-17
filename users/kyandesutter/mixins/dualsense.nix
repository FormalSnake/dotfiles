{ lib, pkgs, ... }:
let
  flexoki = import ./flexoki/palette.nix;
  inherit (flexoki) accents;
  stripHash = lib.removePrefix "#";

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
  # Everything talks to the controller over hidraw as the session user, which
  # works because programs.steam.enable (modules/nixos/mixins/steam.nix)
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
      dualsensectl lightbar \
        "$((16#''${colour:0:2}))" "$((16#''${colour:2:2}))" "$((16#''${colour:4:2}))" || true

      cap="$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)"
      leds=$(( (cap + 19) / 20 ))
      [ "$leds" -ge 1 ] || leds=1
      [ "$leds" -le 5 ] || leds=5
      dualsensectl player-leds "$leds" || true
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
    runtimeInputs = with pkgs; [ openssh jq coreutils dualsenseSync ];
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
      done
    '';
  };
  # Waybar-JSON for FormalShell's `command` bar module (mixins/formalshell.nix
  # registers it as custom:dualsense). Empty text when no controller answers,
  # which is what keeps the cell out of the way the rest of the time.
  # dualsensectl prints "<capacity> <status>" and nothing else, so the split is
  # positional. Capacity is a 10% bucket midpoint, never finer.
  dualsenseBar = pkgs.writeShellApplication {
    name = "dualsense-bar";
    runtimeInputs = [ pkgs.dualsensectl ];
    text = ''
      out="$(dualsensectl battery 2>/dev/null || true)"
      if [ -z "$out" ]; then
        printf '{"text":"","tooltip":"","class":""}\n'
        exit 0
      fi

      cap="''${out%% *}"
      status="''${out##* }"
      class=""
      [ "$cap" -gt 20 ] || class="warning"
      [ "$cap" -gt 10 ] || class="critical"

      printf '{"text":"DS %s%%","tooltip":"DualSense — %s%%, %s","class":"%s"}\n' \
        "$cap" "$cap" "$status" "$class"
    '';
  };
in
{
  home.packages = [ pkgs.dualsensectl dualsenseSync dualsenseBar ];

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
