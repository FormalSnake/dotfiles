{ pkgs, ... }:
{
  # Parsec remote desktop. Unfree and Linux-only in nixpkgs (allowUnfree is
  # already set globally in modules/shared/mixins/nix.nix), so it lives in the
  # Linux-only home module rather than the cross-platform programs.nix; the
  # macbook gets the `parsec` homebrew cask (systems/macbook/homebrew.nix).
  #
  # Client only: Parsec does not support hosting on Linux, so these machines can
  # connect out (to the macbook, to Windows) but never show up as a host
  # themselves. The app is X11, so it runs under the XWayland server Hyprland
  # starts itself (programs.hyprland.xwayland in modules/nixos/mixins/hyprland.nix).
  home.packages = [ pkgs.parsec-bin ];
}
