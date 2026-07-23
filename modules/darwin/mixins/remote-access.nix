{ pkgs, ... }:
let
  # nixpkgs marks pam_ssh_agent_auth linux-only, but it builds against macOS's
  # OpenPAM with two fixes: -std=gnu99 (modern autoconf picks gnu23, which
  # rejects the K&R definitions in its openbsd-compat code AND breaks the
  # configure function probes, so half of libc gets "replaced") and
  # -D_FORTIFY_SOURCE=0 (the Apple SDK's fortify macros collide with those
  # replacements). NIX_CFLAGS_COMPILE lands after the makefile's flags, so the
  # -std override wins.
  pam_ssh_agent_auth =
    (pkgs.pam_ssh_agent_auth.override { pam = pkgs.openpam; }).overrideAttrs (o: {
      meta = o.meta // { platforms = pkgs.lib.platforms.unix; };
      hardeningDisable = [ "fortify" "fortify3" ];
      env = (o.env or { }) // {
        NIX_CFLAGS_COMPILE =
          (o.env.NIX_CFLAGS_COMPILE or "") + " -D_FORTIFY_SOURCE=0 -std=gnu99";
      };
    });
  machineKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcVJF2yg72gRq6NceAnchCIgIWfC2Xx2Va2vcq1GVOm personal_mac"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYmDpRg/oAI5/NSJbEzOZHJqEg8YoTT2Nrv5fwLLXWi kyandesutter@e1504g"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxYo1mVlFzYfDSiHH4nWXYs+ZFz29vYlkRkWxQKxMFv kyandesutter@g815"
  ];
  machineKeysFile = pkgs.writeText "sudo_authorized_keys" (pkgs.lib.concatLines machineKeys);
in
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
  users.users.kyandesutter.openssh.authorizedKeys.keys = machineKeys;

  # Passwordless sudo for SSH sessions from our own machines: pam_ssh_agent_auth
  # accepts sudo when the forwarded agent (the ssh mixin sets ForwardAgent only
  # for our hosts) holds one of the machine keys. Local sudo still uses
  # Touch ID / password. The module can't read the nix-darwin-managed
  # authorized-keys file: its secure_filename() check walks the resolved path
  # and rejects /nix/store (group-writable), so activation installs a real
  # root-owned copy outside the store for it. noninteractive_auth makes
  # `sudo -n` actually try PAM — without it sudo assumes PAM means "will
  # prompt" and gives up before the agent module ever runs.
  security.pam.services.sudo_local.text = ''
    auth       sufficient     ${pam_ssh_agent_auth}/libexec/pam_ssh_agent_auth.so file=/etc/ssh/sudo_authorized_keys
  '';
  security.sudo.extraConfig = ''
    Defaults env_keep+=SSH_AUTH_SOCK
    Defaults noninteractive_auth
  '';

  # Best-effort enable of Remote Login (sshd) on activation. postActivation.text
  # is type `lines`, so this concatenates with any other contributor. Under
  # macOS TCC the call may silently no-op; the runbook has the manual Settings
  # fallback (System Settings -> General -> Sharing -> Remote Login).
  system.activationScripts.postActivation.text = ''
    # Real root-owned copy of the machine keys for pam_ssh_agent_auth (see the
    # sudo_local block above: it can't read through the /nix/store symlink).
    install -m 444 -o root -g wheel ${machineKeysFile} /etc/ssh/sudo_authorized_keys

    /usr/sbin/systemsetup -setremotelogin on >/dev/null 2>&1 || true
  '';

  # The application firewall drops inbound UDP to ad-hoc-signed (i.e. every
  # Nix-built) binary, which kills mosh: mosh-server binds and listens but the
  # packets never reach its socket ("timed out waiting for server"). SSH is
  # unaffected (sshd is Apple-signed). Since macOS 26.5.2 the allow list can't
  # be maintained either: socketfilterfw --add/--unblockapp exit 0 but change
  # nothing (the per-activation re-add loop that used to live here went dead),
  # and even allow-listed store paths stopped passing traffic. So the firewall
  # stays off, declaratively — inbound exposure is governed by Tailscale and
  # the network edge instead. Verified 2026-07-23: signed /usr/bin/python3
  # echo server receives UDP over the tailnet, the Nix python on the next
  # port receives nothing until the firewall is disabled.
  networking.applicationFirewall.enable = false;
}
