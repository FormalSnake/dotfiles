# The sessions the greeter offers, the one a host logs into at boot, and launcher entries that log
# straight into another.

# What each FormalShell session's greeter entry runs; the boot's locked login starts the same
# compositor (rootfs/etc/greetd/formalshell-login.sh).
DEFAULTS = {
    "hyprland-uwsm": "/usr/bin/uwsm start -e -D Hyprland hyprland.desktop",
    "formalwm-uwsm": "/usr/bin/uwsm start -e -D ShojiWM formalwm.desktop",
}

def sessions(gaming = False, default = "hyprland-uwsm"):
    if default not in DEFAULTS:
        fail("no FormalShell session %s, only %s" % (default, ", ".join(DEFAULTS.keys())))
    alternate = "gamescope-session-steam" if gaming else "plasma"
    labels = {
        alternate: "Gaming Mode" if gaming else "Switch to Plasma",
        "hyprland-uwsm": "Switch to Hyprland",
        "formalwm-uwsm": "Switch to formalwm",
    }
    icons = {alternate: "steam" if gaming else "kde", "hyprland-uwsm": "hyprland", "formalwm-uwsm": "preferences-system-windows"}
    units = ", ".join(['"session-switch@%s.service"' % s for s in labels])
    out = [
        file("/etc/formalshell-greeter/default-session", content = default + "\n"),
        file("/var/lib/formalshell-greeter/.config/formalshell/settings.json", content = """{
  "greeter": {
    "sessionDirs": [
      "/etc/formalshell-greeter/wayland-sessions"
    ],
    "sessionCommand": [
      "%s"
    ],
    "defaultSession": "%s"
  }
}
""" % (DEFAULTS[default], default)),
        file("/etc/polkit-1/rules.d/50-session-switch.rules", content = """polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.systemd1.manage-units" &&
      subject.user == "kyandesutter" &&
      [%s].indexOf(action.lookup("unit")) >= 0 &&
      action.lookup("verb") == "start") {
    return polkit.Result.YES;
  }
});
""" % units),
    ]
    for s, label in labels.items():
        out.append(file("/usr/local/share/applications/session-switch-%s.desktop" % s, content = """[Desktop Entry]
Type=Application
Name=%s
Exec=/usr/local/bin/session-switch %s
Icon=%s
Categories=System;
""" % (label, s, icons[s])))
    return out
