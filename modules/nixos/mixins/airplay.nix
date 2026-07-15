{ config, lib, pkgs, ... }:
# AirPlay screen-mirroring receiver: show an iPhone's screen in a window on the
# g815 (e.g. to demo the phone in a meeting by sharing that window).
#
# UxPlay is an AirPlay 2 mirroring *receiver* — the iPhone finds it in the
# AirPlay picker and streams H.264 into a GStreamer window. Two prerequisites
# beyond the package:
#   • Avahi (mDNS/DNS-SD) must run with publishing allowed, or the phone never
#     sees the receiver in its AirPlay list.
#   • The AirPlay ports must be open. UxPlay picks random ports unless pinned, so
#     run it with `-p` (the legacy fixed set) and open exactly those:
#       TCP 7000,7001,7100   UDP 6000,6001,7011.
#
# The receiver runs at login as a home-manager user service (`uxplay -p`, so its
# ports match the firewall set below) — see ../../../users/kyandesutter/mixins/
# autostart.nix. It opens no window until a phone connects; pick it in the iPhone's
# Screen Mirroring list. AirPlay is a network path (same Wi-Fi / LAN), NOT USB —
# the wired libimobiledevice stack in ./phone-integration.nix does not mirror.
let
  cfg = config.kyan.airplay;
in
{
  options.kyan.airplay.enable =
    lib.mkEnableOption "UxPlay AirPlay screen-mirroring receiver";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.uxplay ];

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        userServices = true; # let uxplay register its AirPlay DNS-SD service
      };
    };

    # Match `uxplay -p` (legacy fixed ports). Merges additively with
    # ./networking.nix; avahi opens its own mDNS port (5353) itself.
    networking.firewall = {
      allowedTCPPorts = [ 7000 7001 7100 ];
      allowedUDPPorts = [ 6000 6001 7011 ];
    };
  };
}
