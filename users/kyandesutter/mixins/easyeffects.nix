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
  services.easyeffects = {
    enable = true;
    preset = "shit-mic";

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
}
