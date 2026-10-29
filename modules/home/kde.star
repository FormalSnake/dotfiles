load("//lib/paths.star", "BIN")
load("//lib/tree.star", "merge")
load("//lib/units.star", "autostart", "oneshot")

# Plasma's apps with no OnlyShowIn, which the Hyprland launcher would list. Each gets a shadowing
# entry limited to KDE.
KDE_ONLY = {
    "konsolesu": ("Terminal - Super User Mode", 'konsole --profile "Root Shell"', "utilities-terminal_su"),
    "org.kde.dolphin": ("Dolphin", "dolphin %u", "org.kde.dolphin"),
    "org.kde.dolphinsu": ("File Manager - Super User Mode", '/usr/bin/xdg-su -c "dolphin %U"', "system-file-manager"),
    "org.kde.drkonqi.coredump.gui": ("Crashed Processes Viewer", "drkonqi-coredump-gui", "tools-report-bug"),
    "org.kde.konsole": ("Konsole", "konsole", "utilities-terminal"),
    "org.kde.kwalletmanager": ("KWalletManager", "kwalletmanager5 %F", "kwalletmanager"),
    "org.kde.plasma-systemmonitor": ("System Monitor", "plasma-systemmonitor", "utilities-system-monitor"),
    "org.kde.qrca": ("Qrca", "qrca", "org.kde.qrca"),
    "org.kde.xwaylandvideobridge": ("Xwayland Video Bridge", "xwaylandvideobridge", "org.kde.xwaylandvideobridge"),
    "org.qt.qdbusviewer6": ("Qt 6 D-Bus Viewer", "qdbusviewer6", "qdbusviewer6"),
}

# Launcher entries the distro patterns pull in that nothing here asked for.
HIDDEN = [
    "kdesystemsettings", "org.opensuse.YaST", "org.opensuse.yast.Packager", "ipython-3.13", "jupyterlab",
    "jupyter-nbclassic", "jupyter-notebook", "org.alacritty.Alacritty", "org.gnome.Evince",
    "org.gnome.ColorProfileViewer", "uuctl", "winetricks",
]

def hide_app(id):
    return file("~/.local/share/applications/%s.desktop" % id, content = "[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n" % id)

def kde_only(id, name, exec, icon):
    return file("~/.local/share/applications/%s.desktop" % id, content = "[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=%s\nOnlyShowIn=KDE;\n" % (name, exec, icon))

IN_PLASMA = {"ConditionEnvironment": "XDG_CURRENT_DESKTOP=KDE", "PartOf": "graphical-session.target"}

KDE = [
    oneshot(
        "kde-config",
        "/usr/bin/sh -c 'kwriteconfig6 --file baloofilerc --group \"Basic Settings\" --key Indexing-Enabled false && kwriteconfig6 --file kwinrc --group EdgeBarrier --key EdgeBarrier 0 && kwriteconfig6 --file kwinrc --group EdgeBarrier --key CornerBarrier --type bool false'",
        "Plasma's Baloo and edge barrier keys",
        user = True,
    ),
    oneshot(
        "kwin-outputs",
        BIN + "/kwin-outputs",
        "Match the KWin output layout and scale to Hyprland",
        user = True,
        remain = False,
        unit = merge(IN_PLASMA, {"After": "plasma-kwin_wayland.service"}),
        install = {"WantedBy": "graphical-session.target"},
    ),
    oneshot(
        "steamed-theme",
        "/usr/bin/sh -c '[ \"$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)\" = Steamed ] || { plasma-apply-lookandfeel --apply Steamed && plasma-apply-wallpaperimage /usr/local/share/wallpapers/steam-classic.png; }'",
        "Apply the Steamed theme and wallpaper once",
        user = True,
        remain = False,
        unit = merge(IN_PLASMA, {"After": "plasma-plasmashell.service"}),
        install = {"WantedBy": "graphical-session.target"},
    ),
    # A Plasma logout otherwise leaves graphical-session.target up for the next Hyprland session.
    oneshot(
        "plasma-end-graphical-session",
        "/usr/bin/true",
        "Stop graphical-session.target when the Plasma workspace stops",
        user = True,
        ExecStop = "/usr/bin/systemctl --user --no-block --job-mode=replace-irreversibly stop graphical-session.target",
        unit = {"PartOf": "plasma-workspace.target"},
        install = {"WantedBy": "plasma-workspace.target"},
    ),
    autostart("discord-kde", BIN + "/discord", "Discord", unit = {"ConditionEnvironment": ["WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP=KDE"]}),
] + [kde_only(id, *entry) for id, entry in KDE_ONLY.items()] + [hide_app(id) for id in HIDDEN]
