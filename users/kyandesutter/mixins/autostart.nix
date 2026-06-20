{ ... }:
{
  # — DE-agnostic login items (generic GUI apps) —
  #
  # These were previously launched from Hyprland's hyprland.start via
  # hl.exec_cmd; they are generic GUI apps, not compositor-coupled, so they live
  # here as home-manager systemd user services bound to graphical-session.target
  # (which uwsm starts/stops with the Hyprland session). The services inherit the
  # imported graphical-session env — the same env noctalia's own user service runs
  # in — so bare command names resolve exactly as they did under hl.exec_cmd.
  #
  # Deliberately NO `Restart=`: closing one of these apps must not relaunch it
  # (matches the old exec-once semantics). Window rules in hyprland.nix still pin
  # each one to its named workspace.

  # Steam, launched minimized to the tray so it doesn't grab focus at login.
  # Window rule sends it to workspace 9 (gaming, HDMI-A-1).
  systemd.user.services.steam = {
    Unit = {
      Description = "Steam (minimized to tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "steam -silent";
    };
  };

  # Equibop (Discord), launched minimized to the tray. Window rule sends it to
  # workspace 4 (communication, eDP-1).
  systemd.user.services.equibop = {
    Unit = {
      Description = "Equibop (minimized to tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "equibop --start-minimized";
    };
  };

  # 1Password to the tray (--silent): keeps the desktop app running so the
  # integrated `op` CLI and browser unlock work from login without focus.
  systemd.user.services."1password" = {
    Unit = {
      Description = "1Password (tray)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "1password --silent";
    };
  };

  # Beeper messaging client. Window rule pins it to workspace 4 (communication).
  systemd.user.services.beeper = {
    Unit = {
      Description = "Beeper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "beeper";
    };
  };

  # BlueBubbles messaging client. Window rule pins it to workspace 4.
  systemd.user.services.bluebubbles = {
    Unit = {
      Description = "BlueBubbles";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "bluebubbles";
    };
  };

  # Spotify music player. Window rule pins it to workspace 8 (media).
  systemd.user.services.spotify = {
    Unit = {
      Description = "Spotify";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "spotify";
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
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "wl-clip-persist --clipboard regular";
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
    };
    Install.WantedBy = [ "graphical-session.target" ];
    Service = {
      Type = "simple";
      ExecStartPre = "sh -c 'for i in $(seq 50); do busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications 2>/dev/null | grep -q true && break; sleep 0.2; done'";
      ExecStart = "helium";
    };
  };
}
