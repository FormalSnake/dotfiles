{ inputs, ... }:
{
  imports = [ inputs.determinate.darwinModules.default ];

  # Determinate's module owns the Nix install + /etc/nix/nix.conf; setting
  # this to true implicitly disables nix-darwin's nix.* management.
  # Extra Nix settings (formerly in /etc/nix/nix.custom.conf) can move under
  # determinateNix.customSettings if desired.
  determinateNix.enable = true;
}
