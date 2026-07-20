{ config, pkgs, ... }:
let
  # — Default-sink → preset sync (the reason EasyEffects' own autoload isn't enough) —
  #
  # EasyEffects 8 (the Qt6 rewrite) only autoloads a preset when a device's active
  # output ROUTE changes (e.g. plugging headphones into the analog jack) — see
  # pw_manager.cpp: `outputRouteChanged` triggers autoload, but `defaultSinkChanged`
  # does NOT. Switching the default sink in DMS (HDMI ↔ speakers ↔ bluetooth)
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
          *pci-0000_02_00.1*)                 echo bass-boost ;;     # GB206 HDMI speakers
          *pci-0000_80_1f.3*)                 echo laptop-neutral ;; # ALC294 built-in speakers
          bluez_output.14_14_7D_E7_8C_E3.*)   echo airpods-bass ;;   # AirPods Pro 2
          bluez_output.*)                     echo flat ;;           # other bluetooth (CMF Headphone Pro)
          *)                                  echo flat ;;           # anything else: pass-through, no EQ
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

  # — Voicing EQ for the Pebble X Plus (the "general sound" improvement) —
  #
  # The Pebble X Plus is a 2.1 system: two 2" satellites + a dedicated 3.5"
  # subwoofer (dual passive radiators) reaching ~45 Hz. Unlike the old 2" Pebble
  # V3 it makes REAL low end, so the sub-bass is handled entirely by filter#0's
  # low-shelf below — this EQ only shapes everything above it.
  #
  # Based on the upper half of Ziyad Nazem's community "Perfect EQ" smile, which
  # also matches the near-mandatory "Music" V-shape reviewers recommend over the
  # "dull/empty" flat tuning (lows + highs up, slight mid scoop). The low bells
  # (32/64/125 Hz) are ZEROED on purpose: the shelf already owns everything below
  # ~110 Hz, and lifting them here would just stack into the sub's boomy midbass.
  # What's left is a gentle 500 Hz–1 kHz scoop to de-mud plus a 4/8/16 kHz
  # presence + air lift. The satellites are already detailed/slightly bright, so
  # the top lift is kept modest (≤ +2.5) to stay "not too sharp". All Bell,
  # RLC (BT), Q≈1.5. Tune live in the EasyEffects window — changes save back to
  # the bass-boost output preset.
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
    band0 = mkBand 32.0 0.0; # below the sub's ~45 Hz floor — left flat
    band1 = mkBand 64.0 0.0; # owned by the low-shelf — left flat
    band2 = mkBand 125.0 0.0; # midbass boom region — left flat
    band3 = mkBand 250.0 0.0;
    band4 = mkBand 500.0 (-1.0); # de-mud (scoop)
    band5 = mkBand 1000.0 (-1.5); # de-mud (scoop)
    band6 = mkBand 2000.0 0.0;
    band7 = mkBand 4000.0 1.5; # presence
    band8 = mkBand 8000.0 2.0; # detail
    band9 = mkBand 16000.0 2.5; # air
  };

  # — Audiophile (Harman-neutral) correction for the AirPods Pro 2 —
  #
  # These bands are the AutoEq parametric result for the AirPods Pro 2, measured
  # by HypetheSonics on a standardized GRAS RA0045 in-ear coupler
  # (github.com/jaakkopasanen/AutoEq → results/HypetheSonics/GRAS RA0045 in-ear/).
  # It corrects the stock response toward the Harman IE target — i.e. what makes
  # them sound "flat/reference". The bass BOOST is a separate low-shelf stacked on
  # top in filter#0 below (same pattern as the Pebble HDMI preset). So: this EQ
  # makes them neutral, the shelf makes them thump.
  #
  # `mode = "APO (DR)"` is the LSP "digital biquad" band mode — it reproduces the
  # EqualizerAPO/AutoEq filter math exactly, so these land as measured (RLC (BT),
  # used for the Pebbles' hand-tuned voicing, would drift slightly from AutoEq's
  # numbers). AutoEq's own preamp of -3.1 dB is folded into filter#0's input-gain
  # together with the bass-boost headroom. Type map: LSC→Lo-shelf, PK→Bell,
  # HSC→Hi-shelf. Alternative measurement (Harpo) exists in the same repo if you
  # want to A/B; regenerate from AutoEq if you ever re-measure. Tune live in the
  # EasyEffects window — changes save back to the airpods-bass output preset.
  mkApoBand = type: frequency: gain: q: {
    inherit type frequency gain q;
    mode = "APO (DR)";
    slope = "x1";
    mute = false;
    solo = false;
  };
  airpodsCorrectionBands = {
    band0 = mkApoBand "Lo-shelf" 105.0 (-1.2) 0.70;
    band1 = mkApoBand "Bell" 302.0 (-1.7) 0.51;
    band2 = mkApoBand "Bell" 2374.0 3.1 2.32;
    band3 = mkApoBand "Bell" 75.0 3.3 1.05;
    band4 = mkApoBand "Bell" 5218.0 2.5 2.96;
    band5 = mkApoBand "Hi-shelf" 10000.0 (-0.2) 0.70;
    band6 = mkApoBand "Bell" 6854.0 (-0.6) 6.00;
    band7 = mkApoBand "Bell" 428.0 (-0.6) 4.23;
    band8 = mkApoBand "Bell" 314.0 0.4 3.61;
    band9 = mkApoBand "Bell" 978.0 0.4 4.91;
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
  # — Bass boost for the Creative Pebble X Plus on HDMI —
  #
  # The Pebble X Plus is a 2.1 system with a real 3.5" subwoofer (down to ~45 Hz),
  # so — unlike the old 2" Pebble V3 — it does NOT need a huge fake-bass shelf to
  # invent low end it can't produce. It just needs a tasteful lift aimed at the
  # sub's deep range, kept clear of the ~100–160 Hz midbass where this system can
  # get boomy. EasyEffects already sits on the OUTPUT pipeline (apps → "Easy
  # Effects Sink" → the real device), so an output preset is the natural place to
  # voice it.
  #
  # Same eqMac-style headroom trick as before, just gentler: boost the sub band
  # but pull the WHOLE signal down by a matching amount (a "preamp" cut) so the
  # boosted low end lands at unity instead of clipping. Because we're reinforcing
  # real bass rather than faking it, the cut is small (-9 dB, not the V3's -11).
  #
  # Two plugins, in order:
  #   1. filter#0 as a Low-shelf: input-gain -9 dB knocks the whole signal down
  #      for headroom, then +9 dB below ~75 Hz brings the sub band back to roughly
  #      unity (so bass ≈ 0 dB, everything else ≈ -9 dB → the deep bass sits ~9 dB
  #      out front, nothing clips). Aimed LOW (75 Hz) on purpose: it leans on the
  #      sub's strength (45–90 Hz) and stays out of the boomy midbass.
  #      The bass-vs-rest emphasis is the shelf `gain`; the overall level/headroom
  #      is `input-gain`. Want less bass but same loudness? Lower BOTH together.
  #      Boomy on some tracks? The sub has a physical level knob — use it.
  #   2. equalizer#0 — voicing EQ (the V-shape; see `perfectEqBands`).
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

        # Low-shelf + preamp: -9 dB on everything (input-gain) for headroom, then
        # +9 dB below ~75 Hz. The sub band nets ≈ 0 dB, the rest ≈ -9 dB, so the
        # deep bass sits ~9 dB hotter than the rest and nothing clips. Aimed low
        # (75 Hz) to lean on the sub (45–90 Hz) and dodge the boomy midbass. RLC
        # (BT) is a gentle, musical shelf; slope x1 keeps it broad. Too much bass?
        # Lower `gain`, or use the sub's physical level knob.
        "filter#0" = {
          bypass = false;
          "input-gain" = -9.0;
          "output-gain" = 0.0;
          type = "Low-shelf";
          mode = "RLC (BT)";
          "equal-mode" = "IIR";
          slope = "x1";
          decramp = "Off";
          frequency = 75.0;
          width = 4.0;
          quality = 0.0;
          gain = 9.0;
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

    # — AirPods Pro 2: audiophile correction + bass boost on top —
    #
    # Same two-stage recipe as the Pebble `bass-boost` preset, but the voicing EQ
    # is a real measured AutoEq correction (see `airpodsCorrectionBands` above)
    # instead of a hand-tuned smile, since we have actual coupler measurements for
    # these. Loaded whenever the AirPods are the default sink, via ee-preset-sync's
    # `bluez_output.14_14_7D_E7_8C_E3.*` → airpods-bass mapping.
    #
    #   1. filter#0 Low-shelf — the bass BOOST + all the headroom. input-gain -8 dB
    #      pulls the whole signal down (AutoEq's own -3.1 dB preamp is subsumed
    #      here), then +6 dB below ~90 Hz brings the sub-bass back up to roughly
    #      unity. Net: sub-bass ≈ 0 dB, everything else ≈ -8 dB → bass sits ~6-8 dB
    #      hotter than the rest with clean headroom and no clipping. The AirPods
    #      have real sub-bass extension (unlike the 2" Pebbles), so this is a
    #      lower, tighter shelf (90 Hz) aimed at kick/sub PUNCH rather than midbass
    #      mud. Want more thump? Raise `gain`. Too quiet overall? Turn the volume
    #      up (that's the headroom working). Want them neutral again? Bypass
    #      filter#0 and you're left with just the flat AutoEq correction.
    #   2. equalizer#0 — the AutoEq Harman-neutral correction (10 bands).
    extraPresets.airpods-bass = {
      output = {
        blocklist = [ ];
        plugins_order = [
          "filter#0"
          "equalizer#0"
        ];

        "filter#0" = {
          bypass = false;
          "input-gain" = -8.0; # preamp cut: bass-boost headroom + AutoEq's -3.1 dB
          "output-gain" = 0.0;
          type = "Low-shelf";
          mode = "RLC (BT)";
          "equal-mode" = "IIR";
          slope = "x1";
          decramp = "Off";
          frequency = 90.0;
          width = 4.0;
          quality = 0.0;
          gain = 6.0; # sub-bass lift below ~90 Hz — raise for more thump
          balance = 0.0;
        };

        "equalizer#0" = {
          bypass = false;
          "input-gain" = 0.0;
          "output-gain" = 0.0;
          mode = "IIR";
          "num-bands" = 10;
          "split-channels" = false;
          left = airpodsCorrectionBands;
          right = airpodsCorrectionBands;
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
