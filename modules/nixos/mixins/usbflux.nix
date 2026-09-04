{ config, lib, ... }:
let
  cfg = config.kyan.usbflux;
in
{
  # Share the USB-attached iPhone with the macbook so Xcode builds and debugs
  # onto it while the cable stays in this laptop.
  #
  # The mac runs usbfluxd (../../darwin/mixins/usbflux.nix), which takes over
  # /var/run/usbmuxd there and forwards to the usbmuxd running here; the phone
  # then appears in Xcode as a locally-plugged device, pairing record and all.
  # That is the usbmux protocol layer, not raw USB, so app installs don't pay
  # USB/IP round-trip latency the way VirtualHere or kernel usbip would (and
  # macOS has no usbip client anyway).
  #
  # usbmuxd only listens on a unix socket, so a socket-activated
  # systemd-socket-proxyd bridges TCP to it. Nothing authenticates that port:
  # whatever reaches it can install apps on and read the camera roll of a phone
  # that has already tapped Trust. So it is exposed on tailscale0 only, via the
  # trusted interface below, never on wifi or the LAN.
  #
  # The mac side is pointed at an explicit host:port rather than usbfluxd's
  # _remote-mobdev._tcp mDNS discovery, because mDNS doesn't cross the tailnet.

  options.kyan.usbflux = {
    enable = lib.mkEnableOption "exporting the attached iPhone to the macbook for Xcode";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "TCP port to export usbmuxd on (usbfluxd's default for a bare -r host).";
    };
  };

  config = lib.mkIf cfg.enable {
    # The daemon whose socket gets exported. ./phone-integration.nix also sets
    # this on desktop hosts; identical bool definitions merge fine.
    services.usbmuxd.enable = true;

    systemd.sockets.usbflux-export = {
      description = "usbmuxd TCP export for remote Xcode";
      wantedBy = [ "sockets.target" ];
      socketConfig.ListenStream = toString cfg.port;
    };

    systemd.services.usbflux-export = {
      description = "Bridge the usbflux TCP port to usbmuxd's unix socket";
      requires = [ "usbmuxd.service" ];
      after = [ "usbmuxd.service" ];
      serviceConfig = {
        # No --exit-idle-time. Letting the proxy go away tears down the TCP
        # connection usbfluxd is holding, and usbfluxd only ever re-dials the
        # single remote it was given with -r: one added later with
        # `usbfluxctl add` is logged as "no longer available" and never
        # retried, so the phone silently vanishes from the mac a few minutes
        # after the last command. Measured 2026-09-04.
        ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd /run/usbmuxd";
        # Runs as usbmuxd's own service account: it needs nothing but the
        # listening fd systemd passes it and access to that one socket.
        User = config.services.usbmuxd.user;
        Group = config.services.usbmuxd.group;
        PrivateDevices = true;
        ProtectHome = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      };
    };

    # Reachable over the tailnet only; the default-deny firewall drops the port
    # everywhere else. (List, so this merges with ./phone-integration.nix.)
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  };
}
