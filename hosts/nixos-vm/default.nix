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
    # Enable SSH for VM access
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };
  
  # Use Hyprland for this VM
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Enable ZSH at the system level
  programs.zsh.enable = true;

  # VM-specific system packages
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    firefox
  ];
}

