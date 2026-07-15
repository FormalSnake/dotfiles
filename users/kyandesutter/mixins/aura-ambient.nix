{ config, lib, pkgs, ... }:
let
  # ASUS Aura "Ambient" on Linux: sample the focused screen and stream it to the
  # keyboard's per-key LEDs (Ambilight spread). asusd exposes only one keyboard
  # zone, so per-key goes through OpenRGB's Direct mode instead — the same layer
  # Armoury Crate uses. Keyboard COLOUR time-shares with asusd by power source:
  # OpenRGB owns it on AC (this service), aura-repaint owns it otherwise. asusd
  # keeps owning brightness, fans, battery limit and suspend flags throughout.
  # Start/stop is driven by power-tune (niri.nix) on AC/battery transitions.
  # OpenRGB with a G815LP laptop-keyboard entry patched in: upstream matches ASUS
  # laptops by DMI board name and has no "G815LP" row, so it early-returns and the
  # device falls back to a 84-key layout (no numpad, no lightbar). The patch adds
  # a G815LP device reusing the G733QR zones (keyboard w/ numpad + lid + lightbar);
  # ASUS N-KEY LED indices are consistent across models. Pending upstream as a
  # device request. overrideAttrs so the system's own OpenRGB is untouched.
  openrgb = pkgs.openrgb.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./g815lp-openrgb.patch ];
  });

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.openrgb-python
    ps.pillow
  ]);

  # Launch a private, localhost-only OpenRGB SDK server, run the streamer against
  # it, and tear the server down on exit. Kept per-session (not a system daemon)
  # so OpenRGB never holds the keyboard while ambient is off — asusd stays the
  # sole owner then.
  ambient = pkgs.writeShellApplication {
    name = "aura-ambient";
    runtimeInputs = [
      openrgb
      pythonEnv
      pkgs.grim
      pkgs.niri
      pkgs.coreutils
    ];
    text = ''
      openrgb --server --server-host 127.0.0.1 --server-port 6742 >/dev/null 2>&1 &
      trap 'kill %1 2>/dev/null || true' EXIT
      python3 ${./aura-ambient-streamer.py}
    '';
  };
in
{
  options.kyan.auraAmbient.enable =
    lib.mkEnableOption "screen-reactive per-key keyboard lighting (OpenRGB ambient)";

  config = lib.mkIf config.kyan.auraAmbient.enable {
    home.packages = [
      ambient
      openrgb # patched CLI for probing devices (`openrgb -l`)
    ];

    # No [Install] / WantedBy: power-tune (niri.nix) is the only thing that starts
    # and stops this, on AC/battery transitions, so it never runs concurrently
    # with asusd's aura-repaint. PartOf graphical-session ties it to the session.
    systemd.user.services.aura-ambient = {
      Unit = {
        Description = "Screen-reactive per-key keyboard lighting (OpenRGB Direct)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${ambient}/bin/aura-ambient";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
