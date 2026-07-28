{ pkgs, lib, ... }:
{
  # Tailscale device mesh — reach either host (the macbook "remote work server"
  # and the g815 laptop) from the other anywhere. `sudo tailscale up` to
  # authenticate is a manual owner step — see docs/remote-server.md.
  # Valid on both nix-darwin and NixOS.
  services.tailscale = {
    enable = true;
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    # Tailscale SSH: tailscaled itself answers port 22 on the tailnet address,
    # authenticating by tailnet identity instead of a key — so a phone/iPad
    # terminal connects with no key to install and no passphrase. It only
    # intercepts connections arriving over tailscale0; sshd still owns the LAN
    # path (modules/nixos/mixins/agenix.nix), so the g815's remote-builder login
    # and the LAN fallbacks are untouched.
    #
    # extraSetFlags runs `tailscale set` from tailscaled-set.service at boot,
    # which (unlike extraUpFlags) does not need an authKeyFile — the nodes are
    # already logged in. Access is still gated by the tailnet policy file's
    # `ssh` block in the admin console; with no matching rule every connection
    # is refused.
    #
    # Darwin is excluded because it can't work there: the Mac runs the App Store
    # variant, and only the open-source tailscaled variant can be a Tailscale
    # SSH *server*. The Mac keeps native Remote Login + key auth — see
    # docs/remote-server.md.
    extraSetFlags = [ "--ssh" ];
  };
}
