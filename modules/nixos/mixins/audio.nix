{ pkgs, ... }:
{
  # PipeWire audio stack (replaces PulseAudio).
  security.rtkit.enable = true;

  # pactl client: DMS shells out to it for codec/output handling. PipeWire ships
  # the pulse *server* (pulse.enable) but not the CLI client, and the user
  # service PATH sees the system profile, not the home one — so install it here.
  environment.systemPackages = [ pkgs.pulseaudio ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # Floor the graph quantum at 1024 frames (~21ms). Games (e.g. Cities2)
    # otherwise negotiate the whole graph down to 256 frames (~5.3ms); under
    # gaming CPU load the EasyEffects DSP chain misses that deadline and xruns,
    # which are audible as pops/crackle. A larger buffer absorbs the jitter.
    extraConfig.pipewire."92-min-quantum"."context.properties"."default.clock.min-quantum" = 1024;

    # Never auto-switch Bluetooth headsets to the HFP/headset profile. This
    # chassis's BT adapter can't hold an SCO voice link (kernel: "SCO packet for
    # unknown connection handle"), so the AirPods mic only ever captures silence
    # anyway. Left on, WirePlumber flips A2DP→headset whenever an app opens that
    # dead mic, which swaps the high-quality stereo sink for a separate HFP sink
    # whose volume collapses toward 0 — the media volume "randomly" dropping.
    # Off: AirPods stay A2DP (full stereo, stable volume); calls use the laptop
    # mic, which WirePlumber then picks as the default source on its own.
    wireplumber.extraConfig."51-airpods-a2dp-only"."wireplumber.settings"."bluetooth.autoswitch-to-headset-profile" = false;

    # Device-specific output priorities (headphone MACs, this chassis's PCI
    # audio addresses) live in systems/g815/default.nix — they are hardware
    # facts, not portable audio-stack config.
  };
}
