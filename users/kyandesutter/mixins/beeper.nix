{ pkgs, ... }:
{
  # Beeper — universal chat app (Matrix-based, bridges WhatsApp/Signal/iMessage/
  # etc. into one client). Electron app; in nixpkgs it is x86_64-linux-only and
  # unfree (allowUnfree is already set globally in modules/shared/mixins/nix.nix),
  # so it lives in the Linux-only home module rather than the cross-platform
  # programs.nix.
  home.packages = [ pkgs.beeper ];
}
