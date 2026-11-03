load("//lib/paths.star", "STORE")
load("//lib/units.star", "gui")
load("//modules/linux/store.star", "sh")

# Hands the mouse and keyboard to the iPad left of the monitor, as a BLE HID device, and plays
# its audio here. A new iPad pairs with `padbridge --pair` while the service is stopped.
PADBRIDGE = [
    pkg(
        "padbridge",
        source = git("https://github.com/FormalStudio/padbridge", rev = "a25547dacf938c31b371bc7ea6cd58f0159f45a7"),
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
