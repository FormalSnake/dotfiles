{ pkgs, ... }:
let
  # The iPad Pro 11" (3rd gen) panel is 2388x1668, so serving the output at
  # exactly that size lets the viewer draw one framebuffer pixel per device
  # pixel. scale 1.5 leaves a 1592x1112 logical desktop: 2.0 is Apple's own
  # factor but it is sized for a tablet held at reading distance, and a second
  # monitor parked next to a laptop wants more room than that.
  output = "ipad";
  mode = "2388x1668@60";
  scale = "1.5";
  vncPort = 5900;
  webPort = 5901;

  # Both servers bind to the Tailscale address rather than 0.0.0.0, so the
  # desktop is reachable from the tailnet and from nothing else. That address
  # only exists at runtime and systemd does not expand command substitution in
  # ExecStart, hence the wrappers.
  #
  # -w serves the VNC stream as a websocket on the same port, which is what
  # noVNC below talks; the raw VNC port still works for a native client.
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
      exec wayvnc -w --output=${output} --max-fps=30 "$(tailscale ip -4 | head -n1)" ${toString vncPort}
    '';
  };

  web = pkgs.writeShellApplication {
    name = "ipad-display-web";
    runtimeInputs = [
      pkgs.darkhttpd
      pkgs.tailscale
      pkgs.coreutils
    ];
    text = ''
      exec darkhttpd ${pkgs.novnc}/share/webapps/novnc \
        --addr "$(tailscale ip -4 | head -n1)" --port ${toString webPort} --no-listing
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

      # resize=scale hands noVNC's 2388-wide canvas to a 1194pt-wide Safari
      # viewport, which on the iPad's 2x screen lands back on 1:1 device pixels.
      url() {
        ip="$(tailscale ip -4 | head -n1)"
        printf 'http://%s:%s/vnc.html?host=%s&port=%s&autoconnect=1&reconnect=1&resize=scale' \
          "$ip" ${toString webPort} "$ip" ${toString vncPort}
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
        echo "iPad display up. Open on the iPad:"
        url
        echo
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
          if running; then url; echo; else echo off; fi
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
  # output through wlr-screencopy and serves it, and its virtual
  # pointer/keyboard feed iPad touches back in as input on that output alone.
  # The result carries workspaces and window rules like any other monitor, so it
  # is an extension of the desktop rather than a mirror of the panel.
  #
  # The client is noVNC in Safari, served from here, because every native iPad
  # VNC client is paid or subscription-gated. Add-to-home-screen gives it a real
  # full-screen app (noVNC ships the apple-mobile-web-app meta tags).
  #
  # Sunshine + Moonlight would be the nicer client, and is not an option:
  # Sunshine's wlr backend reports an empty monitor list under Hyprland, headless
  # or not (LizardByte/Sunshine#4197, closed as not planned; reproduced on this
  # host against sunshine 2026.516). Its other backends need a real KMS plane,
  # which a headless output does not have.
  #
  # A cable is not on the table either: an iPad's USB-C port is a DisplayPort
  # source and never a sink, and the only USB networking iPadOS offers is
  # Personal Hotspot, which wants a cellular model. Tailscale is the wire.
  home.packages = [ ctl ];

  systemd.user.services.ipad-display = {
    Unit = {
      Description = "VNC server for the iPad headless output";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Wants = [ "ipad-display-web.service" ];
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

  systemd.user.services.ipad-display-web = {
    Unit = {
      Description = "noVNC client files for the iPad display";
      # Pulled in and torn down by the VNC server, which is the thing worth
      # running: the static files are useless on their own.
      PartOf = [ "ipad-display.service" ];
      After = [ "ipad-display.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${web}/bin/ipad-display-web";
    };
  };
}
