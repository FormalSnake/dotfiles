{ pkgs, ... }:
let
  chime = pkgs.runCommand "formalos-chime.wav" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./chime.py} $out
  '';

  # No PipeWire exists yet at boot, and ALSA's default device routes to it,
  # so the chime goes to the hardware directly: the first "Analog" playback
  # PCM (an HDA or SOF codec's speakers and jack), never HDMI or a USB mic.
  # A cold codec can come up muted, so the mixer is opened first; WirePlumber
  # restores its own levels when the session starts.
  play = pkgs.writeShellApplication {
    name = "formalos-chime";
    runtimeInputs = [ pkgs.alsa-utils pkgs.gnugrep pkgs.coreutils ];
    text = ''
      # A start long after boot is a switch picking the unit up, not a boot.
      [ "$(cut -d. -f1 /proc/uptime)" -lt 120 ] || exit 0
      # sound.target comes before SOF has loaded its firmware and registered
      # the card, so wait for the PCM while the splash is still up.
      for _ in $(seq 50); do
        grep -lqE '^(id|name): .*Analog' /proc/asound/card*/pcm*p/info 2>/dev/null && break
        sleep 0.2
      done
      for info in /proc/asound/card*/pcm*p/info; do
        grep -qE '^(id|name): .*Analog' "$info" || continue
        card=$(grep '^card:' "$info" | cut -d' ' -f2)
        dev=$(grep '^device:' "$info" | cut -d' ' -f2)
        for control in Master Speaker Headphone PCM; do
          amixer -q -c "$card" sset "$control" unmute 2>/dev/null || true
        done
        amixer -q -c "$card" sset Master 60% 2>/dev/null || true
        amixer -q -c "$card" sset PCM 100% 2>/dev/null || true
        exec aplay -q -D "plughw:$card,$dev" ${chime}
      done
    '';
  };
in
{
  # The boot chime, while the FormalOS splash is up. It starts ahead of the
  # greeter without holding it back, and never fails the boot.
  systemd.services.formalos-chime = {
    description = "FormalOS boot chime";
    wantedBy = [ "multi-user.target" ];
    wants = [ "sound.target" ];
    after = [ "sound.target" ];
    before = [ "display-manager.service" ];
    unitConfig.DefaultDependencies = false;
    # Boot only. restartIfChanged covers a changed unit; RemainAfterExit keeps
    # it active after playing, since switch-to-configuration starts any
    # inactive unit multi-user.target wants, so every rebuild replayed it.
    restartIfChanged = false;
    serviceConfig = {
      Type = "exec";
      RemainAfterExit = true;
      ExecStart = "-${play}/bin/formalos-chime";
    };
  };
}
