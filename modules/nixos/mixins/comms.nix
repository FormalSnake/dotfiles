{ config, lib, pkgs, ... }:
let
  igpuChromium = import ../../../lib/chromium-igpu.nix { inherit pkgs lib; };

  # — Equibop with WebRTC mic auto-gain disabled —
  # Equibop is Electron (Chromium under the hood). On Linux specifically,
  # Chromium's WebRTC stack is allowed to reach into PipeWire and ride the
  # *hardware* input gain of the capture device up/down to hit a loudness
  # target — so during a call the mic "gradually gets quieter" and the source
  # slider visibly drops (the Razer was found pulled down to 0.79). On
  # Windows/macOS the same AGC runs purely inside Chromium's own pipeline and
  # never touches the OS slider, which is why this is a Linux-only symptom.
  # The fix Equibop's own wiki recommends (https://equibop.org/wiki/linux/tips/)
  # is to launch with `--disable-features=WebRtcAllowInputVolumeAdjustment`.
  # The NixOS equibop wrapper just execs electron and ignores the usual
  # `equibop-flags.conf`, so the flag is injected at the package level here —
  # this way it applies regardless of launch path (autostart, the
  # `Exec=equibop` .desktop entry, or a terminal). igpuChromium also pins it to
  # the iGPU (Electron hits the same nvidia-Wayland dmabuf software-fallback as
  # Helium when docked — see lib/chromium-igpu.nix).
  equibopNoAgc = igpuChromium {
    package = pkgs.equibop;
    exes = [ "equibop" ];
    extraFlags = [ "--disable-features=WebRtcAllowInputVolumeAdjustment" ];
  };
in
{
  # Comms / recording desktop apps. Rides on the desktop profile like the other
  # desktop-only mixins (phone-integration, online-accounts).
  config = lib.mkIf config.kyan.desktop.enable {
    environment.systemPackages = [
      equibopNoAgc # Discord client (Vesktop fork); WebRTC mic-AGC flag baked in (see above)
      pkgs.obs-studio
    ];
  };
}
