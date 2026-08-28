{ pkgs, ... }:
{
  # Dillo: a ~1 MB FLTK browser with no JavaScript engine at all, so pages
  # either work as documents or don't work. Handy for reading docs, plain-text
  # sites and anything that shouldn't be allowed to run code. It does its own
  # HTML/CSS layout (no WebKit, no Blink), and speaks HTTPS through libressl.
  #
  # FLTK 1.3 is X11-only, so this runs through XWayland. XWayland renders at
  # native pixel density here (force_zero_scaling in mixins/hyprland.nix), so on
  # the g815's 1.25-scaled panel the UI comes out small; FLTK's own scaling
  # (Ctrl +/-, or FLTK_SCALING_FACTOR) covers that per session.
  home.packages = [ pkgs.dillo ];
}
