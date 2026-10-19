{ inputs, ... }:
{
  imports = [ inputs.determinate.darwinModules.default ];

  # Determinate's module owns the Nix install + /etc/nix/nix.conf; setting
  # this to true implicitly disables nix-darwin's nix.* management.
  # Extra Nix settings (formerly in /etc/nix/nix.custom.conf) can move under
  # determinateNix.customSettings if desired.
  determinateNix.enable = true;

  # claude-code and kopuz caches so neither input ever builds locally
  # (extra-* so Determinate's own default substituters are kept).
  determinateNix.customSettings = {
    extra-substituters = [
      "https://claude-code.cachix.org"
      "https://kopuz.cachix.org"
    ];
    extra-trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      "kopuz.cachix.org-1:J2X3AnAYhKTJW5S3aCLoA1ckonQXVNZMQvhZA0YAufw="
    ];
  };
}
