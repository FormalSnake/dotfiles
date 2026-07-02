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

    # Automatic output routing by priority. WirePlumber always switches the
    # default sink to the highest-priority *available* node, and auto-falls back
    # when it disappears. Order: CMF Headphone Pro > HDMI > built-in speakers.
    # A manual pick (Noctalia / `wpctl set-default` / pavucontrol) is stored as a
    # "configured default" and overrides this until you change it again.
    wireplumber.extraConfig."51-output-priorities" = {
      # CMF Headphone Pro (bluetooth, MAC 2C:BE:EE:65:A0:21) — highest priority.
      "monitor.bluez.rules" = [
        {
          matches = [ { "node.name" = "~bluez_output.2C_BE_EE_65_A0_21.*"; } ];
          actions.update-props = {
            "priority.session" = 2000;
            "priority.driver" = 2000;
          };
        }

        # AirPods Pro (bluetooth, MAC 14:14:7D:E7:8C:E3). They otherwise connect
        # with `bluez5.profile = "off"`, so no sink/source node is ever created
        # and they don't appear as an audio device. Pin the initial profile to
        # A2DP (high-fidelity AAC playback) and auto-connect that profile so the
        # sink always shows up. Trade-off: A2DP has no microphone — switch the
        # card to `headset-head-unit` (via Noctalia/wpctl) when you need the mic.
        {
          matches = [ { "device.name" = "bluez_card.14_14_7D_E7_8C_E3"; } ];
          actions.update-props = {
            "device.profile" = "a2dp-sink";
            "bluez5.auto-connect" = [ "a2dp_sink" ];
          };
        }

        # …and make the AirPods a preferred default output when present.
        {
          matches = [ { "node.name" = "~bluez_output.14_14_7D_E7_8C_E3.*"; } ];
          actions.update-props = {
            "priority.session" = 2000;
            "priority.driver" = 2000;
          };
        }
      ];

      # HDMI (GPU audio @ 02:00.1) above built-in analog speakers (@ 00:1f.3).
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.pci-0000_02_00.1.*"; } ];
          actions.update-props = {
            "priority.session" = 1500;
            "priority.driver" = 1500;
          };
        }
        {
          matches = [ { "node.name" = "~alsa_output.pci-0000_80_1f.3.*"; } ];
          actions.update-props = {
            "priority.session" = 1000;
            "priority.driver" = 1000;
          };
        }
      ];
    };
  };
}
