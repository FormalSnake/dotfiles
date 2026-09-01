{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.usbflux;
  label = "kyan.usbfluxd";

  usbflux = pkgs.writeShellScriptBin "usbflux" ''
    set -euo pipefail
    case "''${1-status}" in
      on)
        sudo launchctl kickstart -k system/${label}
        echo "usbfluxd -> ${cfg.remote}. Restart Xcode so it reconnects to the new socket."
        ;;
      off)
        sudo launchctl kill TERM system/${label} 2>/dev/null || true
        # usbfluxd restores /var/run/usbmuxd on SIGTERM; give it a moment to finish.
        for _ in 1 2 3 4 5; do
          [ -e /var/run/usbmuxd.orig ] || break
          sleep 0.3
        done
        if [ -e /var/run/usbmuxd.orig ]; then
          echo "warning: /var/run/usbmuxd.orig still present, local USB devices may be unreachable" >&2
          exit 1
        fi
        echo "usbfluxd stopped, local usbmuxd restored. Restart Xcode."
        ;;
      status)
        if [ -e /var/run/usbmuxd.orig ]; then
          echo "on: usbmuxd socket is held by usbfluxd (remote ${cfg.remote})"
        else
          echo "off: local usbmuxd owns the socket"
        fi
        xcrun xctrace list devices 2>/dev/null || true
        ;;
      *)
        echo "usage: usbflux [on|off|status]" >&2
        exit 2
        ;;
    esac
  '';
in
{
  # macOS half of the remote-iPhone setup: usbfluxd makes a phone plugged into
  # one of the Linux laptops show up in Xcode here. The Linux half (which
  # exports its usbmuxd over the tailnet) is ../../nixos/mixins/usbflux.nix.
  #
  # usbfluxd works by renaming /var/run/usbmuxd to /var/run/usbmuxd.orig and
  # binding its own socket in that place, then merging the local devices behind
  # .orig with the remote ones. Two consequences drive the wiring below:
  #
  #   * While it runs, every usbmux client on this machine goes through it, so
  #     it must not be on by default and must not be restarted in a crash loop
  #     (each restart re-does the rename dance under a live Xcode). Hence
  #     RunAtLoad and KeepAlive both off: the job sits loaded and idle until
  #     `usbflux on` kickstarts it.
  #   * The rename is only undone on a clean shutdown, which usbfluxd does from
  #     its SIGTERM handler, so `usbflux off` sends TERM and then checks that
  #     .orig is gone before reporting success.
  #
  # Xcode and any other usbmux client caches its connection, so it has to be
  # restarted across an on/off flip; the wrapper says so each time.

  options.kyan.usbflux = {
    remote = lib.mkOption {
      type = lib.types.str;
      # Tailscale IP rather than MagicDNS, matching the ssh host entries in
      # users/kyandesutter/mixins/ssh.nix. usbfluxd takes a single -r, so
      # pointing at the other laptop means changing this and rebuilding.
      default = "100.114.32.78:5000"; # g815
      description = "host:port of the Linux machine exporting its usbmuxd.";
    };
  };

  config = {
    launchd.daemons.usbfluxd = {
      serviceConfig = {
        Label = label;
        ProgramArguments = [
          "${pkgs.usbfluxd}/bin/usbfluxd"
          "-f" # foreground, so launchd supervises the real process
          "-m" # no mDNS: _remote-mobdev._tcp doesn't cross the tailnet
          "-r"
          cfg.remote
        ];
        RunAtLoad = false;
        KeepAlive = false;
        StandardOutPath = "/var/log/usbfluxd.log";
        StandardErrorPath = "/var/log/usbfluxd.log";
      };
    };

    environment.systemPackages = [
      usbflux
      pkgs.libimobiledevice # idevice_id -l to confirm the phone arrived
    ];
  };
}
