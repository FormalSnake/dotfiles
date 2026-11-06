load("//lib/paths.star", "STORE", "TUMBLEWEED")
load("//lib/units.star", "gui")
load("//modules/linux/store.star", "sh")

# Hands the mouse and keyboard to the iPad left of the monitor, as a BLE HID device, and plays
# its audio here. A new iPad pairs with `padbridge --pair` while the service is stopped.
PADBRIDGE = [
    pkg(
        "padbridge",
        source = git(
            "https://github.com/FormalStudio/padbridge",
            rev = "b8815ceefcbff6e0fc9bf3c22a83b5e9c7d7b09b",
            image = TUMBLEWEED,
            deps = ["cargo", "gcc"],
        ),
        build = sh('cargo build --release --locked && install -Dm755 target/release/padbridge "$FSPEC_OUT/bin/padbridge"'),
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
