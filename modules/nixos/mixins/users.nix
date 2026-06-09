{ pkgs, ... }:
{
  # fish is the login shell (matches the macbook). The home-manager fish mixin
  # configures it; enabling it here registers it in /etc/shells and lets HM's
  # vendor completions resolve.
  programs.fish.enable = true;

  users.users.kyandesutter = {
    isNormalUser = true;
    description = "Kyan";
    shell = pkgs.fish;
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode" # gamemode renice/governor without root
    ];
  };
}
