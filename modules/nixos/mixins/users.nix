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
    # The personal 1Password SSH key (same one authorized on the macbook in
    # modules/darwin/mixins/remote-access.nix), so any of the machines can SSH
    # into the Linux hosts over Tailscale without password auth.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcVJF2yg72gRq6NceAnchCIgIWfC2Xx2Va2vcq1GVOm personal_mac"
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
