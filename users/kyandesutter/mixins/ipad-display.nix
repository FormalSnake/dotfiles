{ pkgs, ... }:
let
  # The iPad Pro 11" (3rd gen) panel is 2388x1668, so serving the output at
  # exactly that size lets the viewer draw 1:1 with no resampling. scale 1.5
  # leaves a 1592x1112 logical desktop: 2.0 is Apple's own factor but it is
  # sized for a tablet held at reading distance, and a second monitor parked
  # next to a laptop wants more room than that.
  output = "ipad";
  mode = "2388x1668@60";
  scale = "1.5";
  port = 5900;

  # wayvnc binds to the Tailscale address rather than 0.0.0.0, so the desktop
  # is reachable from the tailnet and from nothing else. That address only
  # exists at runtime and systemd does not expand command substitution in
  # ExecStart, hence a wrapper instead of an inline command line.
  #
  # --max-fps=30: the e1504g encodes in software on a 15W Intel part, and the
  # frame budget is better spent on the physical panel.
  serve = pkgs.writeShellApplication {
    name = "ipad-display-serve";
    runtimeInputs = [
      pkgs.wayvnc
      pkgs.tailscale
      pkgs.coreutils
    ];
    text = ''
      exec wayvnc --output=${output} --max-fps=30 "$(tailscale ip -4 | head -n1)" ${toString port}
    '';
  };

  ctl = pkgs.writeShellApplication {
    name = "ipad-display";
    runtimeInputs = [
      pkgs.hyprland # hyprctl
      pkgs.jq
      pkgs.tailscale
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      have_output() {
        hyprctl -j monitors all | jq -e --arg n ${output} 'any(.[]; .name == $n)' >/dev/null
      }

      running() {
        systemctl --user --quiet is-active ipad-display.service
      }

      address() {
        printf '%s:%s' "$(tailscale ip -4 | head -n1)" ${toString port}
      }

      start() {
        if ! have_output; then
          hyprctl output create headless ${output}
          for _ in $(seq 20); do
            if have_output; then break; fi
            sleep 0.1
          done
        fi
        # Geometry is applied here rather than from hyprland.lua: the rule is
        # only meaningful while the output exists, and it keeps the whole
        # concern in this file. Re-applying is idempotent, monitor rules are
        # keyed by output name.
        hyprctl eval 'hl.monitor({ output = "${output}", mode = "${mode}", position = "auto", scale = ${scale} })' >/dev/null
        systemctl --user start ipad-display.service
        echo "iPad display up. Point a VNC viewer at $(address)"
      }

      stop() {
        systemctl --user stop ipad-display.service
        if have_output; then hyprctl output remove ${output}; fi
      }

      case "''${1:-toggle}" in
        on) start ;;
        off) stop ;;
        toggle) if running; then stop; else start; fi ;;
        status)
          if running; then echo "on, serving $(address)"; else echo off; fi
          ;;
        *)
          echo "usage: ipad-display [on|off|toggle|status]" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  # iPad as a real second display, over Tailscale.
  #
  # Hyprland can conjure an output with no hardware behind it
  # (`hyprctl output create headless ipad`; naming it arrived in 0.56, before
  # that you took whatever HEADLESS-n you were given). wayvnc captures that one
  # output through wlr-screencopy and serves it as a VNC session, and its
  # virtual pointer/keyboard feed iPad touches back in as input. The result
  # carries workspaces and window rules like any other monitor, so it is an
  # extension of the desktop rather than a mirror of the panel.
  #
  # A cable is not on the table: an iPad's USB-C port is a DisplayPort source
  # and never a sink, and the only USB networking iPadOS offers is Personal
  # Hotspot, which wants a cellular model. Tailscale is the wire.
  #
  # Client side is any VNC viewer on the iPad pointed at the address
  # `ipad-display on` prints.
  home.packages = [ ctl ];

  systemd.user.services.ipad-display = {
    Unit = {
      Description = "VNC server for the iPad headless output";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    # No Install.WantedBy: this is on-demand, started by `ipad-display on`.
    Service = {
      Type = "simple";
      ExecStart = "${serve}/bin/ipad-display-serve";
      # Tear the phantom monitor down with the server, so a wayvnc that dies on
      # its own can't leave an invisible output holding windows. Best-effort:
      # at session teardown hyprctl has no compositor left to talk to.
      ExecStopPost = "-${pkgs.hyprland}/bin/hyprctl output remove ${output}";
    };
  };
}
