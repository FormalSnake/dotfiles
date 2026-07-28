{ ... }:
{
  # Tailscale device mesh — reach either host (the macbook "remote work server"
  # and the g815 laptop) from the other anywhere. `sudo tailscale up` to
  # authenticate is a manual owner step — see docs/remote-server.md.
  # Valid on both nix-darwin and NixOS.
  #
  # Tailscale SSH (`extraSetFlags = [ "--ssh" ]`) is deliberately NOT enabled.
  # Tried 2026-07-28 and reverted: tailscaled claims port 22 on the tailnet
  # addresses, so every inter-host connection stops reaching sshd. That breaks
  # two load-bearing flows at once — the forwarded-agent sudo mesh (Tailscale
  # SSH does not forward SSH_AUTH_SOCK, so `sudo -n` on the g815 starts asking
  # for a password) and the e1504g's remote builder, whose nix-builder key and
  # its forced `nix-daemon --stdio` command live in sshd's authorized_keys.
  # There is no fallthrough to sshd for tailnet traffic, and the Mac runs the
  # App Store variant, which cannot be a Tailscale SSH server at all. Mobile
  # terminals use sshd with their own key instead (modules/nixos/mixins/
  # users.nix, modules/darwin/mixins/remote-access.nix).
  services.tailscale.enable = true;
}
