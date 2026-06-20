{ ... }:
{
  # Tailscale device mesh — reach either host (the macbook "remote work server"
  # and the g815 laptop) from the other anywhere. `sudo tailscale up` to
  # authenticate is a manual owner step — see docs/remote-server.md.
  # Valid on both nix-darwin and NixOS.
  services.tailscale.enable = true;
}
