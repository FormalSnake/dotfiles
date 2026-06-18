{ ... }:
{
  # Tailscale device mesh — reach the macbook (remote work server) from this
  # laptop anywhere. `sudo tailscale up` to authenticate is a manual owner step
  # — see docs/remote-server.md.
  services.tailscale.enable = true;
}
