{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Import the hardware configuration from the default install
    ../../nixos-default/hardware-configuration.nix
  ];

  # Desktop Environment - KDE Plasma
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # System state version
  system.stateVersion = "25.05";
}
