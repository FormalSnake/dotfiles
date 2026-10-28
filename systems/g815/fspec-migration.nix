# The g815 as `fspec disk migrate --nixos-system` needs it: built as
# nixosConfigurations.g815-btrfs while p5 is still ext4, booted only after the
# conversion. Once it has run, this moves into hardware-configuration.nix and
# default.nix the way the e1504g's did, and the second configuration goes.
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
  # The migration's boot counting, its fspec-live entry and its
  # switch-to-configuration step all go through systemd-boot; Limine has no
  # tries. systemd-boot finds bootmgfw.efi on the shared ESP by itself.
  boot.loader.limine.enable = lib.mkForce false;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 3;
  };

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
