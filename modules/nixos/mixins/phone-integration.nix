{ config, lib, ... }:
# iPhone ↔ g815 integration. Two native-iOS-app tools, both system-level so they
# manage their own LAN firewall ports:
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
# Gated on the desktop profile (no-op on a headless NixOS host), mirroring the
# import-unconditionally / gate-internally pattern of ./hyprland.nix.
lib.mkIf config.kyan.desktop.enable {
  programs.kdeconnect.enable = true; # opens TCP+UDP 1714–1764
  programs.localsend.enable = true; # opens TCP+UDP 53317

  # Backup path: trust the whole Tailscale interface so KDE Connect / LocalSend
  # reach the laptop when the two devices aren't on the same physical LAN.
  # (trustedInterfaces is a list — merges additively with ./networking.nix.)
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
