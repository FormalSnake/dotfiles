{ lib, pkgs, ... }:
{
  # Discord with moonlight (https://moonlight-mod.github.io), the client mod.
  # nixpkgs builds the mod in and swaps resources/app.asar for a two-line loader
  # that requires moonlight's injector and hands it the real _app.asar, which is
  # the same patch the upstream installer applies imperatively. Doing it through
  # the package means a Discord update can't silently revert the injection.
  #
  # Replaced Equibop on the Linux hosts (2026-08-28); Equicord is gone with it,
  # and the wrapper asserts at most one client mod anyway. Worth knowing what
  # went with it: Vesktop's venmic is why Equibop could share desktop *audio* on
  # Wayland. Native Discord shares the screen through the xdg portal but has no
  # audio path, so screenshare here is video only.
  #
  # `--disable-features=WebRtcAllowInputVolumeAdjustment` is Linux-only: there
  # Chromium's WebRTC stack reaches into PipeWire and rides the *hardware* input
  # gain toward a loudness target, so the mic gradually gets quieter during a
  # call and the source slider visibly drops (the Razer was found pulled down to
  # 0.79). On macOS the same AGC stays inside Chromium's own pipeline and never
  # touches the OS slider.
  #
  # Discord is unfree; allowUnfree is global in modules/shared/mixins/nix.nix.
  home.packages = [
    (pkgs.discord.override (
      {
        withMoonlight = true;
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        commandLineArgs = "--disable-features=WebRtcAllowInputVolumeAdjustment";
      }
    ))
  ];
}
