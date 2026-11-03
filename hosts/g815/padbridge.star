load("//lib/paths.star", "STORE")
load("//lib/units.star", "gui")
load("//modules/linux/store.star", "sh")

# Hands the mouse and keyboard to the iPad left of the monitor, as a BLE HID device. A new iPad
# pairs with `padbridge --pair` while the service is stopped.
PADBRIDGE = [
    pkg(
        "padbridge",
        source = git("https://github.com/FormalStudio/padbridge", rev = "48779ef110c5962b3d5ec94a17e7b017083840fe"),
        build = sh('install -Dm755 "$FSPEC_SRC/padbridge.py" "$FSPEC_OUT/bin/padbridge"'),
    ),
    gui(
        "padbridge",
        STORE + "/padbridge",
        "Share the mouse and keyboard with the iPad",
        restart = "always",
        hyprland = True,
        needs = STORE + "/padbridge",
        RestartSec = 2,
    ),
]
