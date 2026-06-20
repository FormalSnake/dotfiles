{ ... }:
{
  # — "Shit Mic" via EasyEffects (Jschlatt-style blown-out lo-fi mic) —
  #
  # Replaces the old, never-working PipeWire filter-chain. EasyEffects runs as a
  # user daemon (systemd graphical-session service) and, with `processAllInputs`
  # on by default, transparently moves every application's microphone capture
  # through its virtual source — so Discord/OBS/etc. need no per-app setup.
  #
  # The distortion is the "shit-mic" INPUT preset below. SUPER+M toggles
  # EasyEffects' global bypass (toggle-shit-mic in hyprland.nix): bypass OFF =
  # crusty mic, bypass ON = clean passthrough. The daemon is started with this
  # preset loaded (`preset = "shit-mic"`).
  #
  # Preset format note (EasyEffects 8): the top-level block "input" selects the
  # input pipeline folder, `plugins_order` lists the active plugin instances,
  # parameter keys are hyphenated, and enum-valued keys (type/mode) take their
  # string label exactly as shown in the GUI. Tune any of this live in the
  # EasyEffects window — changes save back to ~/.local/share/easyeffects/input.
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
  #      headroom; turn the speaker up. Same Filter plugin/schema as shit-mic.
  #      The bass-vs-rest emphasis is the shelf `gain`; the overall level/headroom
  #      is `input-gain`. Want less bass but same loudness? Lower BOTH together.
  #   2. bass_enhancer#0 — psychoacoustic harmonics for the sub-bass the tiny
  #      drivers can't physically reproduce. Kept GENTLE on purpose: its
  #      mechanism is literally added harmonic distortion, so a high `amount`
  #      is what made it sound buzzy/overdriven. A small `amount` adds
  #      perceived low end without the grit.
  #
  # Applied to HDMI ONLY (not the laptop's analog speakers) via a per-device
  # autoload profile written below — see the xdg.dataFile entry. Tune any of
  # this live in the EasyEffects window; changes save back to the output preset.
  services.easyeffects = {
    enable = true;
    preset = "shit-mic";

    extraPresets.bass-boost = {
      output = {
        blocklist = [ ];
        plugins_order = [
          "filter#0"
          "bass_enhancer#0"
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

        # Bass enhancer (Calf): synthesize harmonics of content below `scope`
        # so the brain hears bass the drivers can't move. GENTLE — `amount` is
        # low so it warms rather than buzzes. Raise `amount`/`harmonics` for
        # more grit, lower for cleaner. floor disabled — works all the way down.
        "bass_enhancer#0" = {
          bypass = false;
          "input-gain" = 0.0;
          "output-gain" = 0.0;
          amount = 3.0;
          harmonics = 4.0;
          scope = 120.0;
          floor = 20.0;
          "floor-active" = false;
          blend = 0.0;
          listen = false;
        };
      };
    };

    extraPresets.shit-mic = {
      input = {
        blocklist = [ ];
        # The 2013 game-lobby / cheap-headset sound is NOT a bitcrush (sample-rate
        # reduction = aliasing = "robot voice") and NOT a slammed maximizer (a
        # dynamics processor driven that hard just pumps/ducks → stuttery near
        # silence). It's a cheap mic whose gain is cranked way too high so it
        # CLIPS, inside a narrow transmission band. So: high-pass + low-pass to
        # the "telephone" band, then a big STATIC output gain on the last filter
        # — no dynamics, nothing to pump — which pushes peaks past 0 dBFS so the
        # consumer (Discord/OBS) hard-clips them into the steady blown-out fuzz.
        plugins_order = [
          "filter#0"
          "filter#1"
        ];

        # High-pass ~300 Hz: strip the lows so it sounds thin/boxy like a headset.
        "filter#0" = {
          bypass = false;
          "input-gain" = 0.0;
          "output-gain" = 0.0;
          type = "High-pass";
          mode = "BWC (BT)";
          "equal-mode" = "IIR";
          slope = "x4";
          decramp = "Off";
          frequency = 300.0;
          width = 4.0;
          quality = 0.0;
          gain = 0.0;
          balance = 0.0;
        };

        # Low-pass ~3.4 kHz: chop the highs → the muffled "voice comms" band, then
        # +20 dB static output gain. This is a fixed boost (not a compressor), so
        # it can't pump or stutter; normal-level speech peaks land well past
        # 0 dBFS and hard-clip at the consumer → constant cheap-mic overdrive.
        "filter#1" = {
          bypass = false;
          "input-gain" = 0.0;
          "output-gain" = 20.0;
          type = "Low-pass";
          mode = "BWC (BT)";
          "equal-mode" = "IIR";
          slope = "x4";
          decramp = "Off";
          frequency = 3400.0;
          width = 4.0;
          quality = 0.0;
          gain = 0.0;
          balance = 0.0;
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
}
