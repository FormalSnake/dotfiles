{ pkgs, ... }:
let
  # — How these services find their executables —
  #
  # systemd resolves a *bare* `ExecStart` name against the manager process's own
  # PATH, which PAM fixes when `systemd --user` first starts — long before the
  # niri session imports the rich session PATH into the user manager. That
  # early PATH lacks /run/current-system/sw/bin and the per-user profile, so a
  # bare `ExecStart=steam` (or even `sh`) fails at login with status=203/EXEC and
  # the app silently never starts. (noctalia/easyeffects dodge this only because
  # their units use absolute /nix/store paths.)
  #
  # Fix: launch each app through a login shell. `bash -lc` rebuilds the full
  # session PATH (/run/current-system/sw/bin + the per-user profile), exactly the
  # environment hl.exec_cmd gave these apps before. `exec` replaces the shell so
  # the app stays the unit's main PID — tray behaviour and Type=simple are
  # unchanged. This is the systemd-unit analogue of the old shell-launched
  # exec-once, not a behaviour change.
  loginExec = cmd: "${pkgs.bash}/bin/bash -lc 'exec ${cmd}'";
in
{
  # — DE-agnostic login items (generic GUI apps) —
  #
  # Generic GUI apps, not compositor-coupled, so they live here as home-manager
  # systemd user services bound to graphical-session.target (which niri.service
  # BindsTo, so they start and stop with the niri session). See loginExec above
  # for how their executables are resolved.
  #
  # Deliberately NO `Restart=`: closing one of these apps must not relaunch it
  # (login items, not daemons). Window rules in niri.nix still pin
  # each one to its named workspace. The one exception is 1Password (below), which
  # carries `Restart = on-failure` because it's a credential daemon that must stay
  # present — see its block for the rationale.
  #
  # Every `[Unit]` below carries `X-SwitchMethod = "keep-old"`. home-manager
  # switches user units with sd-switch, whose default action for a changed unit
  # is stop-start — so each `nixos-rebuild switch` would kill and relaunch these
  # login apps (and occasionally just leave them closed when the restart races
  # graphical-session.target). Their `ExecStart` embeds `${pkgs.bash}`'s store
  # path, so any nixpkgs bump rewrites the unit and re-triggers that churn.
  # `keep-old` tells sd-switch to leave an already-running app untouched across a
  # switch (the new definition applies at the next login) while still starting it
  # if it isn't running. Rebuilds no longer disturb the running session.

  # Steam, launched minimized to the tray so it doesn't grab focus at login.
  # Window rule sends it to workspace 9 (gaming, HDMI-A-1). Runs on the iGPU
  # like every other app (the client is no longer offload-wrapped — gaming
  # lives on Windows; see programs.steam in modules/nixos/mixins/gaming.nix),
  # so it's safe to autostart on any power source and never touches the dGPU.
  # Steam's Chromium UI repeatedly fails to create a drawable under niri/Xwayland
  # (black but still interactive window). Software-render its UI only; this does
  # not affect the renderer used by games or Proton.
  systemd.user.services.steam = {
    Unit = {
      Description = "Steam (minimized to tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "steam -silent -cef-disable-gpu";
    };
  };

  # Equibop (Discord), launched minimized to the tray. Window rule sends it to
  # workspace 4 (communication, eDP-1).
  systemd.user.services.equibop = {
    Unit = {
      Description = "Equibop (minimized to tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "equibop --start-minimized";
    };
  };

  # 1Password to the tray (--silent): keeps the desktop app running so the
  # integrated `op` CLI and browser unlock work from login without focus.
  #
  # UNLIKE the other login apps, this one auto-restarts. 1Password's embedded
  # Chromium occasionally exits abnormally mid-session (it tears its GPU process
  # down with a SIGTRAP core-dump on SIGTERM, and has hit status=1 exits), and
  # without a `Restart=` the tray daemon just vanished until the next login —
  # taking `op` CLI and browser unlock with it. `on-failure` (not `always`) brings
  # it back on a crash while still honouring an intentional quit from the tray
  # (clean exit 0). It does NOT interfere with the dGPU/AC relog or a reboot:
  # those stop the unit via graphical-session.target going down (a commanded stop),
  # and `Restart=` never fires on a commanded stop.
  systemd.user.services."1password" = {
    Unit = {
      Description = "1Password (tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "1password --silent";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Beeper messaging client. Window rule pins it to workspace 4 (communication).
  systemd.user.services.beeper = {
    Unit = {
      Description = "Beeper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "beeper";
    };
  };

  # BlueBubbles messaging client. Window rule pins it to workspace 4.
  systemd.user.services.bluebubbles = {
    Unit = {
      Description = "BlueBubbles";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "bluebubbles";
    };
  };

  # Spotify music player (installed as the com.spotify.Client flatpak — there is
  # no `spotify` binary on PATH). Window rule pins it to workspace 8 (media).
  systemd.user.services.spotify = {
    Unit = {
      Description = "Spotify";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "flatpak run com.spotify.Client";
    };
  };

  # Clipboard: noctalia's native ClipboardService records history by polling the
  # Wayland selection itself (browse it with SUPER+ñ). wl-clip-persist takes
  # ownership of the regular clipboard so its contents survive the source app
  # closing (Wayland otherwise drops a selection when the app that offered it
  # exits), giving noctalia's poller a chance to capture it.
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "wl-clip-persist (keep regular clipboard alive)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "wl-clip-persist --clipboard regular";
    };
  };

  # LocalSend receiver (AirDrop-style file/link sharing). Kept running so files
  # can arrive without manually opening the app. It opens a window at launch;
  # enable "launch minimized / minimize to tray" in-app to suppress that.
  # System-level programs.localsend.enable provides the binary (`localsend_app`)
  # + firewall port.
  systemd.user.services.localsend = {
    Unit = {
      Description = "LocalSend (file sharing receiver)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "localsend_app";
    };
  };

  # UxPlay AirPlay screen-mirroring receiver. Kept running so an iPhone can start
  # mirroring at any time (it opens no window until a phone connects). `-p` pins
  # its ports to the fixed legacy set that the firewall opens — bare `uxplay`
  # picks random ports the firewall drops, so the phone connects but the stream
  # never establishes. System-level package + avahi publishing + firewall ports
  # live in ../../../modules/nixos/mixins/airplay.nix.
  systemd.user.services.uxplay = {
    Unit = {
      Description = "UxPlay (AirPlay mirroring receiver)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = loginExec "uxplay -p";
    };
  };

  # librepods — AirPods tray app (package in mixins/airpods.nix). DE-agnostic
  # tray app, so it lives here like the other login items. Absolute store path
  # (no loginExec needed); starts hidden to the tray, and its icon is picked up
  # by noctalia's `tray` widget. No Restart: quitting from the tray must not
  # relaunch it. g815-only (imported via linux.nix); macOS handles AirPods
  # natively.
  systemd.user.services.librepods = {
    Unit = {
      Description = "librepods (AirPods daemon, hidden to tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.librepods}/bin/librepods --hide";
    };
  };

  # Helium (Chromium browser). Window rule pins it to workspace 1 (web).
  #
  # Helium picks its notification backend ONCE at startup: it probes the
  # org.freedesktop.Notifications D-Bus name and, if nothing owns it yet, falls
  # back to Chrome's built-in message-center for the whole session and never
  # re-checks. noctalia (our notification daemon) is a systemd user service
  # coming up in parallel, so launching helium bare races it — intermittently you
  # get built-in Chrome notifications. The ExecStartPre below waits (≤10s) for
  # noctalia to claim the name before helium starts so it always latches onto the
  # daemon. busctl is from systemd → always on PATH here.
  #
  # noctalia.service is ordered before this (After/Wants) as a hint, but the
  # ExecStartPre busctl wait is the real guard (it polls until the name is owned).
  systemd.user.services.helium = {
    Unit = {
      Description = "Helium (Chromium) — waits for noctalia's notification daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "noctalia.service" "graphical-session.target" ];
      Wants = [ "noctalia.service" ];
      "X-SwitchMethod" = "keep-old";
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.bash}/bin/bash -lc 'for i in $(seq 50); do busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications 2>/dev/null | grep -q true && break; sleep 0.2; done'";
      ExecStart = loginExec "helium";
    };
  };
}
