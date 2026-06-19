{
  # PipeWire audio stack (replaces PulseAudio).
  security.rtkit.enable = true;

  services.pulseaudio.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # — "Shit Mic" (Jschlatt-style blown-out lo-fi mic) —
    #
    # A filter-chain that captures the real default mic and re-exposes the
    # result as a virtual source named "shit_mic". Apps (Discord, OBS, …) can
    # select it directly, and SUPER+M (toggle-shit-mic in
    # users/kyandesutter/mixins/hyprland.nix) flips the default input to it.
    #
    # The distortion is built from stock PipeWire builtin nodes (no extra
    # packages):
    #   hp  — highpass ~450Hz: removes the lows, leaving a thin/tinny body.
    #   lp  — lowpass ~3kHz:  removes the highs → "telephone" band.
    #   honk— peaking boost in the mids for that nasal, honky character.
    #   drive — huge input gain (Mult). The mono float signal is pushed well
    #         past ±1.0 so it hard-clips when a consumer converts to int
    #         (Discord/OBS) → the blown-out fuzz. Crank Mult for more crust,
    #         move hp/lp Freq closer together for more "phone".
    #
    # Mono throughout (mics are mono; the builtin filters are single-port).
    # priority.session is low and capture is dont-reconnect so this source is
    # never auto-picked as the system default and its capture stays glued to
    # the real mic it first latched onto (can't feed back when shit_mic itself
    # becomes the default input).
    extraConfig.pipewire."99-shit-mic" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Shit Mic";
            "media.name" = "Shit Mic";
            "filter.graph" = {
              nodes = [
                {
                  type = "builtin";
                  name = "hp";
                  label = "bq_highpass";
                  control = {
                    "Freq" = 450.0;
                    "Q" = 0.7;
                  };
                }
                {
                  type = "builtin";
                  name = "lp";
                  label = "bq_lowpass";
                  control = {
                    "Freq" = 3000.0;
                    "Q" = 0.7;
                  };
                }
                {
                  type = "builtin";
                  name = "honk";
                  label = "bq_peaking";
                  control = {
                    "Freq" = 1800.0;
                    "Q" = 2.0;
                    "Gain" = 12.0;
                  };
                }
                {
                  type = "builtin";
                  name = "drive";
                  label = "linear";
                  control = {
                    "Mult" = 20.0;
                    "Add" = 0.0;
                  };
                }
              ];
              links = [
                {
                  output = "hp:Out";
                  input = "lp:In";
                }
                {
                  output = "lp:Out";
                  input = "honk:In";
                }
                {
                  output = "honk:Out";
                  input = "drive:In";
                }
              ];
              inputs = [ "hp:In" ];
              outputs = [ "drive:Out" ];
            };
            "capture.props" = {
              "node.name" = "shit_mic.capture";
              "node.passive" = true;
              "node.dont-reconnect" = true;
              "audio.position" = [ "MONO" ];
            };
            "playback.props" = {
              "node.name" = "shit_mic";
              "node.description" = "Shit Mic";
              "media.class" = "Audio/Source";
              "priority.session" = 100;
              "audio.position" = [ "MONO" ];
            };
          };
        }
      ];
    };
  };
}
