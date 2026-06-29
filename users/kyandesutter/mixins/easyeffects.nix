{ ... }:
let
  # — Voicing EQ for the Pebbles (the "general sound" improvement) —
  #
  # The upper half of Ziyad Nazem's community "Perfect EQ" curve, adapted for
  # these speakers. The original 10-band curve is a consumer "smile":
  #   32:+4 64:+2 125:+1 250:0 500:-1 1k:-2 2k:0 4k:+2 8k:+3 16k:+3
  # The bass bells (32/64 Hz) are ZEROED here on purpose: filter#0's low-shelf
  # already owns everything below 110 Hz, and the 2" drivers can't move 32 Hz —
  # boosting it just adds excursion/distortion and eats the headroom. What's
  # left is what actually improves *general* clarity on a bass-boosted tiny
  # speaker: a gentle 500 Hz–1 kHz scoop to de-mud, plus a 4/8/16 kHz presence
  # + air lift so vocals and detail cut through. All Bell, RLC (BT), Q≈1.5.
  # Want the full smile back? Set band0/band1 gains to 4.0/2.0. Tune live in the
  # EasyEffects window — changes save back to the bass-boost output preset.
  mkBand = frequency: gain: {
    inherit frequency gain;
    type = "Bell";
    mode = "RLC (BT)";
    q = 1.5;
    slope = "x1";
    mute = false;
    solo = false;
  };
  perfectEqBands = {
    band0 = mkBand 32.0 0.0; # owned by the low-shelf — left flat
    band1 = mkBand 64.0 0.0; # owned by the low-shelf — left flat
    band2 = mkBand 125.0 1.0;
    band3 = mkBand 250.0 0.0;
    band4 = mkBand 500.0 (-1.0); # de-mud
    band5 = mkBand 1000.0 (-2.0); # de-mud
    band6 = mkBand 2000.0 0.0;
    band7 = mkBand 4000.0 2.0; # presence
    band8 = mkBand 8000.0 3.0; # detail
    band9 = mkBand 16000.0 3.0; # air
  };
in
{
  # EasyEffects runs as a user daemon (systemd graphical-session service) and
  # sits on the OUTPUT pipeline (apps → "Easy Effects Sink" → the real device).
  # Its job here is to voice the HDMI speakers — bass boost + a clarity EQ —
  # applied to the HDMI sink only via the per-device autoload profile.
  #
  # Preset format note (EasyEffects 8): the top-level block ("output" here)
  # selects the pipeline folder, `plugins_order` lists the active plugin
  # instances, parameter keys are hyphenated, and enum-valued keys (type/mode)
  # take their string label exactly as shown in the GUI. Tune any of this live in
  # the EasyEffects window — changes save back to the output preset.
  # — Bass boost for the Creative Pebble V3 on HDMI —
  #
  # The Pebbles are tiny 2" drivers with effectively no low end. EasyEffects
  # already sits on the OUTPUT pipeline (apps → "Easy Effects Sink" → the real
  # device), so an output preset is the natural place to fix this.
  #
  # eqMac-style: boost the bass but pull the WHOLE signal down by a matching
  # amount (a "preamp" cut) so the boosted low end lands at unity instead of
  # slamming past 0 dBFS and clipping. The result is quieter overall but with
  # hard, clean bass — turn the speaker up to taste. Boosting without this
  # headroom is exactly what produces the distorted "2013 bass boost" sound.
  #
  # Two plugins, in order:
  #   1. filter#0 as a Low-shelf: input-gain -11 dB knocks the whole signal down
  #      for headroom (eqMac used ~-11 dB), then +10 dB below ~110 Hz brings the
  #      bass back to roughly unity (so bass ≈ -1 dB, everything else ≈ -11 dB →
  #      bass is way out front, nothing clips). Overall much quieter — that's the
  #      headroom; turn the speaker up.
  #      The bass-vs-rest emphasis is the shelf `gain`; the overall level/headroom
  #      is `input-gain`. Want less bass but same loudness? Lower BOTH together.
  #   2. equalizer#0 — voicing EQ for general clarity (see `perfectEqBands`).
  #
  # NOTE: a Calf bass_enhancer used to sit between these two, synthesizing
  # harmonics to fake sub-bass the 2" drivers can't move. Removed — on speakers
  # that already reproduce real low end via the shelf, its added harmonic
  # distortion read as midbass "warmth" that MASKED the genuine deep bass,
  # making it feel shallower. The pure shelf sounds deeper. If you ever want it
  # back, re-add "bass_enhancer#0" to plugins_order with a low `amount` (~3).
  #
  # Applied to HDMI ONLY (not the laptop's analog speakers) via a per-device
  # autoload profile written below — see the xdg.dataFile entry. Tune any of
  # this live in the EasyEffects window; changes save back to the output preset.
  services.easyeffects = {
    enable = true;

    # — Neutral + gentle bass for the laptop's BUILT-IN speakers (ALC294) —
    #
    # Separate from the HDMI `bass-boost` preset: the built-in drivers are voiced
    # reasonably flat already, so this stays "as neutral as possible" — NO smile
    # EQ, no presence/air lift, no mid scoop. Just one low-shelf to add the low end
    # the small drivers roll off, with a matching preamp cut so the boosted bass
    # lands at unity instead of clipping (same headroom trick as bass-boost, just
    # gentler). Net: bass ≈ 0 dB, everything else ≈ -4 dB → clean, never clips, a
    # touch quieter overall (raise the speaker volume to compensate). Want more
    # bass? Raise `gain` and drop `input-gain` by the same amount. Bound to the
    # analog sink only via the autoload profile below.
    extraPresets.laptop-neutral = {
      output = {
        blocklist = [ ];
        plugins_order = [ "filter#0" ];

        "filter#0" = {
          bypass = false;
          "input-gain" = -4.0; # preamp cut for headroom — matches the +4 shelf
          "output-gain" = 0.0;
          type = "Low-shelf";
          mode = "RLC (BT)";
          "equal-mode" = "IIR";
          slope = "x1";
          decramp = "Off";
          frequency = 120.0;
          width = 4.0;
          quality = 0.0;
          gain = 4.0; # gentle low-end lift below ~120 Hz
          balance = 0.0;
        };
      };
    };

    extraPresets.bass-boost = {
      output = {
        blocklist = [ ];
        plugins_order = [
          "filter#0"
          "equalizer#0"
        ];

        # Low-shelf + preamp: -11 dB on everything (input-gain) for headroom,
        # then +10 dB below 110 Hz. Bass nets ≈ -1 dB, the rest ≈ -11 dB, so the
        # bass is ~10 dB hotter than the rest and nothing clips. RLC (BT) is a
        # gentle, musical shelf; slope x1 keeps it broad rather than a sharp step.
        # Too quiet? Raise the speaker volume. Too much bass? Lower `gain`.
        "filter#0" = {
          bypass = false;
          "input-gain" = -11.0;
          "output-gain" = 0.0;
          type = "Low-shelf";
          mode = "RLC (BT)";
          "equal-mode" = "IIR";
          slope = "x1";
          decramp = "Off";
          frequency = 110.0;
          width = 4.0;
          quality = 0.0;
          gain = 10.0;
          balance = 0.0;
        };

        # Voicing EQ — final stage, shapes the already bass-boosted signal.
        # See `perfectEqBands` above for the curve and rationale. split-channels
        # off, so the single (mirrored) band set applies to both L and R; both
        # `left`/`right` are written identically for a clean, explicit preset.
        "equalizer#0" = {
          bypass = false;
          "input-gain" = 0.0;
          "output-gain" = 0.0;
          mode = "IIR";
          "num-bands" = 10;
          "split-channels" = false;
          left = perfectEqBands;
          right = perfectEqBands;
        };
      };
    };
  };

  # Per-device autoload profile: tie the bass-boost OUTPUT preset to the HDMI
  # sink only. EasyEffects 8 looks for ~/.local/share/easyeffects/autoload/
  # output/<device>:<profile>.json whenever the active output device/route
  # changes; if it matches, it loads `preset-name`. With no profile for the
  # laptop's analog sink, those speakers stay flat.
  #
  # Values come straight from `wpctl inspect` on the GB206 (NVIDIA) HDMI sink:
  #   node.name              -> "device"           (and the filename device part)
  #   device.profile.name    -> "device-profile"   (and the filename profile part)
  #   node.description        -> "device-description"
  # The filename is exactly "<device>:<profile>.json" (EasyEffects replaces any
  # "/" with "_"; neither value has one here). If the HDMI node name ever
  # changes (e.g. different PCI slot), regenerate from `wpctl inspect`.
  xdg.dataFile."easyeffects/autoload/output/alsa_output.pci-0000_02_00.1.hdmi-stereo:hdmi-stereo.json".text =
    builtins.toJSON {
      device = "alsa_output.pci-0000_02_00.1.hdmi-stereo";
      "device-description" = "GB206 High Definition Audio Controller Digital Stereo (HDMI)";
      "device-profile" = "hdmi-stereo";
      "preset-name" = "bass-boost";
    };

  # Per-device autoload for the BUILT-IN analog speakers → laptop-neutral preset.
  # Values from `wpctl inspect` on the ALC294 analog sink:
  #   node.name           -> "device"          (and the filename device part)
  #   device.profile.name -> "device-profile"  (and the filename profile part)
  #   node.description     -> "device-description"
  xdg.dataFile."easyeffects/autoload/output/alsa_output.pci-0000_80_1f.3.analog-stereo:analog-stereo.json".text =
    builtins.toJSON {
      device = "alsa_output.pci-0000_80_1f.3.analog-stereo";
      "device-description" = "800 Series Chipset Family Audio Context Engine (ACE) Analog Stereo";
      "device-profile" = "analog-stereo";
      "preset-name" = "laptop-neutral";
    };
}
