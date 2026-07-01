{ config, pkgs, ... }:
let
  # — Default-sink → preset sync (the reason EasyEffects' own autoload isn't enough) —
  #
  # EasyEffects 8 (the Qt6 rewrite) only autoloads a preset when a device's active
  # output ROUTE changes (e.g. plugging headphones into the analog jack) — see
  # pw_manager.cpp: `outputRouteChanged` triggers autoload, but `defaultSinkChanged`
  # does NOT. Switching the default sink in Noctalia (HDMI ↔ speakers ↔ bluetooth)
  # is a default-sink change, so EE never reacts and the wrong preset stays loaded.
  #
  # This service closes that gap: it tails `pw-metadata -n default -m`, which streams
  # an update line on every `default.audio.sink` change (and replays the current value
  # on connect, so the right preset is applied at startup too), maps the new sink's
  # node.name to a preset, and runs `easyeffects -l <preset>`. The per-device autoload
  # files below still cover the native route-change case (analog jack); this covers the
  # default-sink case. The two can both fire and just load the same preset — harmless.
  #
  # Sink → preset map mirrors the identifiers in modules/nixos/mixins/audio.nix's
  # output-priority rules. Runs in a user service with a limited PATH, so its tools
  # come from runtimeInputs.
  eePresetSync = pkgs.writeShellApplication {
    name = "ee-preset-sync";
    runtimeInputs = [
      pkgs.pipewire # pw-metadata
      config.services.easyeffects.package # easyeffects -l
      pkgs.gnused
      pkgs.coreutils
    ];
    text = ''
      map_preset() {
        case "$1" in
          *pci-0000_02_00.1*) echo bass-boost ;;     # GB206 HDMI speakers
          *pci-0000_80_1f.3*) echo laptop-neutral ;; # ALC294 built-in speakers
          bluez_output.*)     echo flat ;;           # bluetooth (CMF Headphone Pro)
          *)                  echo flat ;;           # anything else: pass-through, no EQ
        esac
      }

      last=""
      apply() {
        preset="$1"
        if [ "$preset" = "$last" ]; then return 0; fi
        if easyeffects -l "$preset"; then last="$preset"; fi
      }

      # Let the EasyEffects daemon finish coming up before the first -l.
      sleep 2

      pw-metadata -n default -m 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          *"key:'default.audio.sink'"*)
            sink="$(printf '%s\n' "$line" | sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')"
            [ -n "$sink" ] && apply "$(map_preset "$sink")"
            ;;
        esac
      done
    '';
  };

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

    # — Flat / pass-through preset for devices that should get NO processing —
    #
    # Loaded by ee-preset-sync (above) whenever the default sink is the bluetooth
    # headphones (CMF Headphone Pro) or any unmapped device. Empty plugins_order =
    # an empty chain, so the signal passes through EasyEffects untouched.
    extraPresets.flat = {
      output = {
        blocklist = [ ];
        plugins_order = [ ];
      };
    };

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
  # sink. EasyEffects 8 looks for ~/.local/share/easyeffects/autoload/
  # output/<device>:<route>.json whenever a device's active output ROUTE changes
  # (not on default-sink changes — that's what ee-preset-sync above handles); if
  # it matches, it loads `preset-name`.
  #
  # GOTCHA (EasyEffects 8): despite the JSON key being named "device-profile", v8
  # matches on the active output ROUTE name, NOT the card profile name — see
  # presets_autoload_manager.cpp (`device_route == json["device-profile"]`) and
  # pw_manager.cpp (autoload is driven by `device.output_route_name`). The v7
  # scheme used the card profile ("hdmi-stereo"); using that here silently never
  # matches. Both the filename's route part AND the "device-profile" field must be
  # the ROUTE name.
  #
  # Values:
  #   node.name (sink)              -> "device"           (+ filename device part)
  #   active output route name      -> "device-profile"   (+ filename route part)
  #   node.description               -> "device-description" (informational only)
  # Get the route name from:
  #   pw-dump | jq '.[]|select(.info.props["device.name"]=="alsa_card.pci-0000_02_00.1")
  #                 |.info.params.Route[]|select(.direction=="Output")|.name'
  # (EasyEffects replaces any "/" with "_"; neither value has one here.) If the
  # node name or route ever changes (different PCI slot / route), regenerate.
  xdg.dataFile."easyeffects/autoload/output/alsa_output.pci-0000_02_00.1.hdmi-stereo:hdmi-output-0.json".text =
    builtins.toJSON {
      device = "alsa_output.pci-0000_02_00.1.hdmi-stereo";
      "device-description" = "GB206 High Definition Audio Controller Digital Stereo (HDMI)";
      "device-profile" = "hdmi-output-0"; # active output ROUTE name (see GOTCHA above)
      "preset-name" = "bass-boost";
    };

  # Per-device autoload for the BUILT-IN analog speakers → laptop-neutral preset.
  # Same route-name rule as above; the analog card's active output route when the
  # internal speakers are selected is "analog-output-speaker" (plugging the 3.5mm
  # jack switches it to "analog-output-headphones" — add a file for that route if
  # you ever want a headphone-jack preset).
  xdg.dataFile."easyeffects/autoload/output/alsa_output.pci-0000_80_1f.3.analog-stereo:analog-output-speaker.json".text =
    builtins.toJSON {
      device = "alsa_output.pci-0000_80_1f.3.analog-stereo";
      "device-description" = "800 Series Chipset Family Audio Context Engine (ACE) Analog Stereo";
      "device-profile" = "analog-output-speaker"; # active output ROUTE name
      "preset-name" = "laptop-neutral";
    };

  # The default-sink → preset watcher. Lives exactly as long as the EasyEffects
  # daemon (BindsTo + WantedBy easyeffects.service), starts after it, and restarts
  # if pw-metadata or the daemon drops. See `eePresetSync` above for the why.
  systemd.user.services.ee-preset-sync = {
    Unit = {
      Description = "Sync EasyEffects output preset to the default sink";
      After = [
        "pipewire.service"
        "easyeffects.service"
      ];
      BindsTo = [ "easyeffects.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${eePresetSync}/bin/ee-preset-sync";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "easyeffects.service" ];
  };
}
