{ pkgs, ... }:
{
  # Geekbench CPU benchmark. Unfree and x86_64-linux only in nixpkgs (allowUnfree
  # is global in modules/shared/mixins/nix.nix), so it lives in the Linux-only
  # home module. The tryout build runs from the CLI as `geekbench7` and uploads
  # results to browser.geekbench.com, which is where the score is shown.
  home.packages = [ pkgs.geekbench ];
}
