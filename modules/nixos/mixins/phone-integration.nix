{ config, lib, pkgs, ... }:
# iPhone ↔ g815 integration, over two paths:
#
# LAN / native-iOS-app tools (both system-level so they manage their own firewall
# ports):
#   • KDE Connect (1714–1764) — notification mirroring, shared clipboard, media
#     control, find-my-phone. (Remote input is an unused plugin — ignore it.)
#   • LocalSend  (53317)       — AirDrop-style file/link sharing.
#
# Same-Wi-Fi is the primary path (LAN broadcast auto-discovery, zero config).
# Tailscale is the backup path for when the phone and laptop are apart: broadcast
# does NOT cross the tailnet, so `tailscale0` is trusted here (the traffic is
# already authenticated end-to-end) and the phone pairs by the g815's stable
# Tailscale IP / MagicDNS name. The user services that run the daemons live in
# ../../../users/kyandesutter/mixins/autostart.nix.
#
# Wired USB (libimobiledevice stack): usbmuxd multiplexes lockdown connections
# over the cable — pair with `idevicepair pair` (tap Trust on the phone), then
# mount the camera roll with `ifuse`, back up with `idevicebackup2`, sideload
# `.ipa`s with `ideviceinstaller`, screenshot with `idevicescreenshot`. usbmuxd
# also lights up plug-n-play USB tethering (the in-tree `ipheth` module hands the
# iPhone to NetworkManager as a normal interface — no extra config here).
#
# Gated on the desktop profile (no-op on a headless NixOS host), mirroring the
# import-unconditionally / gate-internally pattern of ./niri.nix.
lib.mkIf config.kyan.desktop.enable {
  programs.kdeconnect.enable = true; # opens TCP+UDP 1714–1764
  programs.localsend.enable = true; # opens TCP+UDP 53317

  # Wired path: the USB multiplexer daemon every idevice* tool talks through.
  services.usbmuxd.enable = true;

  environment.systemPackages = with pkgs; [
    libimobiledevice # idevice{info,pair,backup2,screenshot,syslog,…} CLI stack
    ifuse # FUSE-mount the iPhone camera roll (DCIM) as a filesystem
    ideviceinstaller # list / install / remove apps (.ipa sideloading)
  ];

  # Backup path: trust the whole Tailscale interface so KDE Connect / LocalSend
  # reach the laptop when the two devices aren't on the same physical LAN.
  # (trustedInterfaces is a list — merges additively with ./networking.nix.)
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
