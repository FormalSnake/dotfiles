load("//lib/paths.star", "BIN", "HOME", "STORE")
load("//lib/units.star", "autostart", "gui", "oneshot")

MACBOOK_MOUNT = HOME + "/.macbook"

SERVICES = [
    # `formalshell install` names these units, and its watchdog restarts them by name.
    service("formalshell.service", user = True),
    service("formalshell-watchdog.timer", user = True),
    # Serves ~/.ssh/id_ed25519, which sudo's pam_ssh_agent_auth and the other hosts accept.
    service("gcr-ssh-agent.socket", user = True),
    # The spec checkout FSPEC_SPEC names, which `fspec app` commits installs from the shell to and
    # fast-forwards before each one. Cloned over https since the repo is public; pushes
    # authenticate through gh.
    oneshot(
        "formalspec-checkout",
        "/usr/bin/sh -c 'test -d " + HOME + "/.config/formalspec/.git || git clone -q " +
        "-c credential.helper= -c \"credential.helper=!gh auth git-credential\" " +
        "https://github.com/FormalSnake/dotfiles.git " + HOME + "/.config/formalspec'",
        "Clone the spec that installs from the shell commit to",
        user = True,
        unit = {"After": "network-online.target"},
    ),

    autostart("discord", BIN + "/discord --start-minimized", "Discord (minimized to tray)", hyprland = True),
    autostart("beeper", STORE + "/beeper", "Beeper", needs = STORE + "/beeper"),
    autostart("flare", "/usr/bin/flatpak run de.schmidhuberj.Flare", "Flare (Signal)"),
    autostart("messages", STORE + "/messages", "Messages", needs = STORE + "/messages"),
    gui("1password", "/usr/bin/1password --silent", "1Password (tray)", restart = "on_failure", needs = "/usr/bin/1password", RestartSec = 2),
    gui(
        "wl-clip-persist",
        STORE + "/wl-clip-persist --clipboard regular",
        "wl-clip-persist (keep regular clipboard alive)",
        hyprland = True,
        needs = STORE + "/wl-clip-persist",
    ),
    gui(
        "helium",
        STORE + "/helium",
        "Helium (Chromium): waits for FormalShell's notification daemon",
        needs = STORE + "/helium",
        unit = {"After": ["formalshell.service", "graphical-session.target"], "Wants": "formalshell.service"},
        ExecStartPre = "/usr/bin/bash -c 'for i in $(seq 50); do busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications 2>/dev/null | grep -q true && break; sleep 0.2; done'",
    ),
    gui(
        "librepods",
        STORE + "/librepods --headless",
        "librepods AirPods daemon (omarchy-pods build, headless)",
        restart = "on_failure",
        env = {"QT_LOGGING_RULES": "openpods.debug=false"},
        RestartSec = 5,
    ),
    gui(
        "macbook-mount",
        "/usr/bin/sshfs -f -o reconnect -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o idmap=user macbook: " + MACBOOK_MOUNT,
        "SSHFS mount of the macbook's home at ~/.macbook",
        restart = "on_failure",
        unit = {"After": ["graphical-session.target", "fspec-1password.service"], "Wants": "fspec-1password.service", "StartLimitIntervalSec": 0},
        RestartSec = 30,
        ExecStartPre = ["-/usr/bin/fusermount3 -uz " + MACBOOK_MOUNT, "/usr/bin/mkdir -p " + MACBOOK_MOUNT],
        ExecStopPost = "-/usr/bin/fusermount3 -uz " + MACBOOK_MOUNT,
    ),
    gui(
        "dualsense-sync",
        "/usr/bin/dualsensectl monitor add " + BIN + "/dualsense-settle",
        "Paint the DualSense lightbar and player LEDs on hotplug",
        restart = "always",
        needs = "/usr/bin/dualsensectl",
        RestartSec = 5,
    ),
    gui("dualsense-agents", BIN + "/dualsense-agents", "Mirror T3 Code agent state onto the DualSense lightbar", restart = "always", RestartSec = 30),
    gui("dualsense-pad", BIN + "/dualsense-pad", "DualSense D-pad as a window and workspace remote", restart = "always", RestartSec = 5),
    timer("dualsense-battery", exec = BIN + "/dualsense-sync", schedule = "*/2 * * * *", user = True),
    gui("streamdeck-keys", BIN + "/streamdeck-keys", "Stream Deck keys for T3 Code agents, system and Discord controls", restart = "always", RestartSec = 5),
    # Without a delay it burns its start limit while the compositor goes away at logout.
    gui(
        "swayidle",
        "/usr/bin/swayidle -w timeout 900 " + BIN + "/idle-lock",
        "Idle manager for Wayland",
        restart = "always",
        unit = {"ConditionEnvironment": "WAYLAND_DISPLAY"},
        RestartSec = 2,
    ),
    gui(
        "panel-gamma",
        STORE + "/wl-gammarelay-rs run",
        "Punchier panel gamma via wl-gammarelay-rs",
        restart = "on_failure",
        hyprland = True,
        needs = STORE + "/wl-gammarelay-rs",
        Type = "dbus",
        BusName = "rs.wl-gammarelay",
        RestartSec = 2,
        ExecStartPost = "/usr/bin/busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Gamma d 1.1",
    ),
    gui("power-saver-dim", BIN + "/power-saver-dim", "Dim backlight while the power-saver profile is active", restart = "always", RestartSec = 2),
    oneshot(
        "gtk-session-css",
        BIN + "/gtk-session-css",
        "Point GTK's session.css at the Hyprland theme",
        user = True,
        remain = False,
        unit = {"Before": "wayland-session-pre@hyprland.desktop.target"},
        install = {"WantedBy": "wayland-session-pre@hyprland.desktop.target"},
    ),
    gui(
        "nordvpn-tray-off",
        BIN + "/nordvpn-tray-off",
        "Disable the NordVPN tray icon (upstream double-registers it)",
        needs = "/usr/bin/nordvpn",
        Type = "oneshot",
        RemainAfterExit = True,
    ),
    gui(
        "easyeffects",
        "/usr/bin/easyeffects --hide-window --service-mode",
        "Easyeffects daemon",
        restart = "on_failure",
        unit = {"After": ["graphical-session.target", "pipewire.service"], "PartOf": ["graphical-session.target", "pipewire.service"], "Wants": "pipewire.service"},
        RestartSec = 5,
        ExecStop = "/usr/bin/easyeffects --quit",
        KillMode = "mixed",
        TimeoutStopSec = 10,
    ),
    gui(
        "ee-preset-sync",
        BIN + "/ee-preset-sync",
        "Sync EasyEffects output preset to the default sink",
        restart = "on_failure",
        unit = {"After": ["pipewire.service", "fspec-easyeffects.service"], "BindsTo": "fspec-easyeffects.service"},
        RestartSec = 2,
        install = {"WantedBy": "fspec-easyeffects.service"},
    ),
    timer("fish-completions", exec = "/usr/bin/fish -c fish_update_completions", schedule = "0 4 * * 0", user = True),
    oneshot(
        "xrdb-merge",
        "/usr/bin/xrdb -merge " + HOME + "/.Xresources",
        "Merge ~/.Xresources into the Xwayland resource database",
        user = True,
        unit = {"After": "graphical-session.target", "PartOf": "graphical-session.target", "ConditionEnvironment": "DISPLAY"},
        install = {"WantedBy": "graphical-session.target"},
    ),
    oneshot(
        "dconf-load",
        "/usr/bin/sh -c 'dconf load / < " + HOME + "/.config/fspec/dconf.ini'",
        "Load the GNOME interface keys from ~/.config/fspec/dconf.ini",
        user = True,
    ),
    service(
        "audio-autoswitch",
        exec = BIN + "/audio-autoswitch",
        user = True,
        restart = "always",
        description = "Switch default output to newly-connected audio devices",
        systemd = {"RestartSec": 3, "unit": {"After": "wireplumber.service"}, "install": {"WantedBy": "pipewire.service"}},
    ),
]
