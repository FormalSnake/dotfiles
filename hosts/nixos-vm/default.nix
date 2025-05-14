{
  config,
  pkgs,
  lib,
  ...
}: {
  # Host-specific settings for the NixOS VM
  networking.hostName = "nixos-vm";

  # VM-specific hardware configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Simple VM disk configuration
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
  };

  # VM-specific services
  services = {
    # Minimal X11 setup for VM
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
    };

    # Enable SSH for VM access
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  # Enable ZSH at the system level
  programs.zsh.enable = true;

  # VM-specific system packages
  environment.systemPackages = with pkgs; [
    gnome.gnome-tweaks
    firefox
  ];
}