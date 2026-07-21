{ pkgs, ... }:
{
  # fish is the login shell (matches the macbook). The home-manager fish mixin
  # configures it; enabling it here registers it in /etc/shells and lets HM's
  # vendor completions resolve.
  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = true;

  users.users.kyandesutter = {
    isNormalUser = true;
    description = "Kyan";
    shell = pkgs.fish;
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video"
      "i2c" # DDC/CI access to /dev/i2c-* for external-monitor brightness (ddcutil)
      "audio"
      "input"
    ];
  };
}
