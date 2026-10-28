# p5 after `fspec disk migrate`: btrfs with NixOS in @nixos beside the other
# roots. Goes with NixOS at `fspec forget nixos`.
{ lib, ... }:
let
  # p5: btrfs-convert --uuid copy keeps the ext4 UUID.
  root = "/dev/disk/by-uuid/04b474c9-4caf-4bd4-969e-233bba3134c6";
  subvol = name: {
    device = lib.mkForce root;
    fsType = lib.mkForce "btrfs";
    options = [ "subvol=${name}" "noatime" "compress=zstd:1" ];
  };
in
{
  # `fspec switch --beside tumbleweed` runs zypper in the Tumbleweed container
  # through podman; docker alone does not do.
  virtualisation.podman.enable = true;

  fileSystems."/" = subvol "@nixos";
  fileSystems."/home" = subvol "@home";
  fileSystems."/swap" = subvol "@swap";

  swapDevices = lib.mkForce [
    {
      # Its own nocow subvolume: btrfs refuses a swapfile on a snapshotted
      # or copy-on-write subvolume, and @nixos gets snapshotted.
      device = "/swap/swapfile";
      size = 16 * 1024; # MiB → 16 GiB
      priority = 1;
    }
  ];
}
