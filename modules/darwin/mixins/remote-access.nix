{ ... }:
{
  # SSH server hardening for the remote-work-server role. macOS's sshd reads
  # /etc/ssh/sshd_config.d/* (the Include sits near the top of the stock
  # sshd_config, so these directives win). Key-only auth, no root login.
  #
  # SAFETY: the laptop's SSH *public* key must already be in this Mac's
  # ~/.ssh/authorized_keys BEFORE PasswordAuthentication flips to "no", or you
  # lock yourself out. See docs/remote-server.md step 3.
  environment.etc."ssh/sshd_config.d/100-kyan.conf".text = ''
    PermitRootLogin no
    PasswordAuthentication no
    KbdInteractiveAuthentication no
  '';

  # Authorized keys for SSH into this Mac over Tailscale. nix-darwin delivers
  # these via an AuthorizedKeysCommand (/etc/ssh/nix_authorized_keys.d/%u),
  # which is *additive* to ~/.ssh/authorized_keys — the laptop's hand-installed
  # key (docs/remote-server.md step 3) is untouched. Tailscale SSH can't be a
  # macOS server, so mobile devices (iPhone/iPad) reach the Mac via native sshd
  # with key auth; add each device's public key here.
  users.users.kyandesutter.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcVJF2yg72gRq6NceAnchCIgIWfC2Xx2Va2vcq1GVOm personal_mac"
  ];

  # Best-effort enable of Remote Login (sshd) on activation. postActivation.text
  # is type `lines`, so this concatenates with any other contributor. Under
  # macOS TCC the call may silently no-op; the runbook has the manual Settings
  # fallback (System Settings -> General -> Sharing -> Remote Login).
  system.activationScripts.postActivation.text = ''
    /usr/sbin/systemsetup -setremotelogin on >/dev/null 2>&1 || true
  '';
}
