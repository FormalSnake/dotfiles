{ config, lib, pkgs, ... }:
let
  # Gated on the nvidia stack, not the desktop: this is a Blackwell-driver
  # resume workaround, meaningless on a host without the dGPU.
  cfg = config.kyan.nvidia;

  # Blackwell (RTX 5070) + nvidia-drm has an s2idle-resume regression: on wake,
  # the display pipeline's atomic pageflip stalls forever ("Pageflip timed
  # out"), so an external monitor comes up detected-but-dark and the niri
  # session — blocked waiting on that flip — stops servicing input and IPC (which
  # also makes freshly hot-plugged USB look dead: nothing is processing it).
  # Present on driver 610.43.02, unfixed upstream as of 2026-07, and it hits KWin
  # too — so it's driver-side, NOT a compositor/session-freeze race (our sessions
  # freeze normally on suspend and there are no nvidia-suspend services in the
  # finegrained/RTD3 setup here).
  #
  # There's nothing in the kernel log to key off and the compositor's error
  # string is unreliable, so detection is a liveness probe instead: a wedged
  # compositor blocks its event loop on the stalled flip and stops answering
  # `niri msg`. If the compositor is unresponsive for a sustained window after
  # resume, restart the display-manager — a fresh greeter/compositor re-modesets
  # the dGPU, which is the one confirmed recovery short of the full power-cycle
  # it otherwise takes.
  resumeRecovery = pkgs.writeShellApplication {
    name = "nvidia-resume-recovery";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux # runuser
      config.systemd.package # systemctl
      config.programs.niri.package # niri msg
    ];
    text = ''
      user=${config.users.users.kyandesutter.name}
      uid="$(id -u "$user" 2>/dev/null || true)"
      [ -n "$uid" ] && [ -d "/run/user/$uid" ] || exit 0
      runtime="/run/user/$uid"

      # No live niri instance (e.g. resumed to the greeter, or the session
      # already gone) → nothing here to recover, and don't restart-loop the DM.
      # niri msg needs NIRI_SOCKET ($XDG_RUNTIME_DIR/niri.<display>.sock) —
      # discover it from the socket that actually exists (niri, unlike DMS,
      # has no fixed well-known socket path to just connect to).
      sock=""
      for s in "$runtime"/niri.*.sock; do
        [ -e "$s" ] && sock="$s" && break
      done
      [ -n "$sock" ] || exit 0

      alive() {
        runuser -u "$user" -- env XDG_RUNTIME_DIR="$runtime" NIRI_SOCKET="$sock" \
          timeout 5 niri msg version >/dev/null 2>&1
      }

      # Let the session thaw before the first probe.
      sleep 8

      # A stalled pageflip never recovers on its own, so require sustained
      # unresponsiveness (~30s of failed probes) before the disruptive restart —
      # a momentarily busy compositor must not trip it.
      for _ in 1 2 3 4 5 6; do
        if alive; then exit 0; fi
        sleep 4
      done

      echo "nvidia-resume-recovery: niri unresponsive after resume — restarting display-manager to recover the display" >&2
      systemctl restart display-manager.service
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    # Runs on resume (ordered after the sleep services, pulled in by them), never
    # blocking the suspend path itself. See the comment on `resumeRecovery`.
    systemd.services.nvidia-resume-recovery = {
      description = "Recover niri if nvidia-drm pageflip stalls after resume (Blackwell s2idle bug)";
      after = [
        "systemd-suspend.service"
        "systemd-hibernate.service"
        "systemd-hybrid-sleep.service"
        "systemd-suspend-then-hibernate.service"
      ];
      wantedBy = [
        "systemd-suspend.service"
        "systemd-hibernate.service"
        "systemd-hybrid-sleep.service"
        "systemd-suspend-then-hibernate.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${resumeRecovery}/bin/nvidia-resume-recovery";
        # Worst case ≈ 8s thaw + 6×(5s probe + 4s) ≈ 62s; cap above that.
        TimeoutStartSec = 90;
      };
    };
  };
}
