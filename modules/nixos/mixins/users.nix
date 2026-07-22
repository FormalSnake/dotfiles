{ pkgs, lib, ... }:
{
  # fish is the login shell (matches the macbook). The home-manager fish mixin
  # configures it; enabling it here registers it in /etc/shells and lets HM's
  # vendor completions resolve.
  programs.fish.enable = true;

  # mkDefault so a host driven remotely (the e1504g) can turn it off.
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  # Passwordless sudo for SSH sessions coming from our own machines:
  # pam_ssh_agent_auth accepts sudo when the forwarded agent holds one of the
  # keys authorized below (the ssh mixin sets ForwardAgent only for our hosts).
  # Local/console sudo still asks for the password. The module reads
  # /etc/ssh/authorized_keys.d/%u, which NixOS fills from authorizedKeys.keys.
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;
  # Without this, `sudo -n` gives up before PAM runs (it assumes PAM will
  # prompt), so scripts would never reach the agent module.
  security.sudo.extraConfig = ''
    Defaults noninteractive_auth
  '';

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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYmDpRg/oAI5/NSJbEzOZHJqEg8YoTT2Nrv5fwLLXWi kyandesutter@e1504g"
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
