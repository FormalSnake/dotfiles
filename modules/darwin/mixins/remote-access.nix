{ pkgs, ... }:
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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYmDpRg/oAI5/NSJbEzOZHJqEg8YoTT2Nrv5fwLLXWi kyandesutter@e1504g"
  ];

  # Best-effort enable of Remote Login (sshd) on activation. postActivation.text
  # is type `lines`, so this concatenates with any other contributor. Under
  # macOS TCC the call may silently no-op; the runbook has the manual Settings
  # fallback (System Settings -> General -> Sharing -> Remote Login).
  system.activationScripts.postActivation.text = ''
    /usr/sbin/systemsetup -setremotelogin on >/dev/null 2>&1 || true

    # mosh-server is an unsigned Nix binary, so the macOS application firewall
    # (enabled here, in "automatically allow signed software" mode) silently
    # DROPS its inbound UDP — `mosh macbook` then hangs at "Nothing received from
    # server on UDP port 600xx" for 8 s even though SSH works (sshd is Apple-
    # signed). Confirmed empirically: a signed binary listening on the Tailscale
    # IP receives UDP; an unsigned one gets nothing. Tailscale UDP transport
    # itself is fine. Explicitly add + unblock the current mosh-server so the
    # firewall permits it regardless of signature. The store path changes when
    # mosh updates, so re-apply on every activation (and cover both the per-user
    # profile symlink and the package path in case ordering leaves one absent).
    # Best-effort under TCC, like the remote-login toggle above.
    for b in \
      /etc/profiles/per-user/kyandesutter/bin/mosh-server \
      ${pkgs.mosh}/bin/mosh-server; do
      if [ -e "$b" ]; then
        /usr/libexec/ApplicationFirewall/socketfilterfw --add "$b" >/dev/null 2>&1 || true
        /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$b" >/dev/null 2>&1 || true
      fi
    done
  '';
}
