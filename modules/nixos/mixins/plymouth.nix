{ pkgs, ... }:
{
  # Boot splash between Limine and SDDM. The module's default theme is bgrt,
  # which shows the firmware's own logo (the ASUS badge on both laptops);
  # breeze instead pulls in nixpkgs' NixOS-branded build with the snowflake
  # centred. No nvidia modules in the initrd: plymouth draws on simpledrm and
  # hands the framebuffer over when the driver loads.
  # breeze copies the logo in at native size and the option's default is the
  # 48 px GDM icon, which reads as a favicon on a laptop panel; 256 px puts
  # it at Ubuntu/Fedora scale.
  boot.plymouth = {
    enable = true;
    theme = "breeze";
    logo = "${pkgs.nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake-white.png";
  };

  # systemd stage 1. The scripted initrd only starts the splash after
  # switch-root; with systemd in the initrd plymouth comes up as the first
  # unit and stays up through the root mount and the switch.
  boot.initrd.systemd.enable = true;
  boot.initrd.verbose = false;

  # Keep kernel and udev chatter off the splash. Log level 3 still surfaces
  # errors; "quiet" also makes systemd default show_status to auto.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
  ];
}
