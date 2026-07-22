{ pkgs, lib, ... }:
{
  # fish is the login shell (matches the macbook). The home-manager fish mixin
  # configures it; enabling it here registers it in /etc/shells and lets HM's
  # vendor completions resolve.
  programs.fish.enable = true;

  # mkDefault so a host driven remotely (the e1504g) can turn it off.
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  users.users.kyandesutter = {
    isNormalUser = true;
    description = "Kyan";
    shell = pkgs.fish;
    # The personal 1Password SSH key (same one authorized on the macbook in
    # modules/darwin/mixins/remote-access.nix), so any of the machines can SSH
    # into the Linux hosts over Tailscale without password auth — plus the
    # g815's on-disk key so non-interactive sessions there (Claude, scripts,
    # cron) can reach the other Linux hosts without the 1Password agent.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcVJF2yg72gRq6NceAnchCIgIWfC2Xx2Va2vcq1GVOm personal_mac"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxYo1mVlFzYfDSiHH4nWXYs+ZFz29vYlkRkWxQKxMFv kyandesutter@g815"
    ];
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
