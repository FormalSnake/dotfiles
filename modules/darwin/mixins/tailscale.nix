{ ... }:
{
  # Tailscale device mesh — reach this Mac (the "remote work server") from the
  # g815 laptop anywhere. nix-darwin runs tailscaled as a launchd daemon
  # (com.tailscale.tailscaled). `sudo tailscale up` to authenticate is a manual
  # owner step — see docs/remote-server.md.
  services.tailscale.enable = true;
}
