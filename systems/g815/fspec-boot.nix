{ lib, ... }:
{
  # `fspec disk migrate`'s boot counting, its fspec-live entry and its
  # switch-to-configuration step all go through systemd-boot; Limine has no
  # tries. systemd-boot finds bootmgfw.efi on the shared ESP by itself.
  boot.loader.limine.enable = lib.mkForce false;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 3;
  };
}
