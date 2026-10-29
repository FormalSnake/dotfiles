# Plasma beside Hyprland, with launcher entries that log straight into the other session. On a
# gaming host Plasma is the gaming desktop.

def sessions(gaming = False):
    labels = {"plasma": "Gaming Mode" if gaming else "Switch to Plasma", "hyprland-uwsm": "Switch to Hyprland"}
    icons = {"plasma": "steam" if gaming else "kde", "hyprland-uwsm": "hyprland"}
    units = ", ".join(['"session-switch@%s.service"' % s for s in labels])
    out = [file("/etc/polkit-1/rules.d/50-session-switch.rules", content = """polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.systemd1.manage-units" &&
      subject.user == "kyandesutter" &&
      [%s].indexOf(action.lookup("unit")) >= 0 &&
      action.lookup("verb") == "start") {
    return polkit.Result.YES;
  }
});
""" % units)]
    for s, label in labels.items():
        out.append(file("/usr/local/share/applications/session-switch-%s.desktop" % s, content = """[Desktop Entry]
Type=Application
Name=%s
Exec=/usr/local/bin/session-switch %s
Icon=%s
Categories=System;
""" % (label, s, icons[s])))
    return out
