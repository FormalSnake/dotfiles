{
  # PipeWire audio stack (replaces PulseAudio).
  security.rtkit.enable = true;

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

    # Device-specific output priorities (headphone MACs, this chassis's PCI
    # audio addresses) live in systems/g815/default.nix — they are hardware
    # facts, not portable audio-stack config.
  };
}
