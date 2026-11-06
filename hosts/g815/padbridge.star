load("//lib/paths.star", "STORE", "TUMBLEWEED")
load("//lib/units.star", "gui", "oneshot")
load("//modules/linux/store.star", "sh")

# Hands the mouse and keyboard to the iPad left of the monitor, as a BLE HID device, and plays
# its audio here. A new iPad pairs with `padbridge --pair` while the service is stopped.
PADBRIDGE = [
    pkg(
        "padbridge",
        source = git(
            "https://github.com/FormalStudio/padbridge",
            rev = "1a4b45ca66ca47254bd990578226ff688cd95b6e",
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
    # The iPad parks an idle link in sniff mode, where g815 may send one report per ~38ms and
    # motion arrives late. The adapter's default policy is reapplied on every power up.
    oneshot(
        "padbridge-no-sniff",
        STORE + "/padbridge --no-sniff",
        "Keep Bluetooth links out of sniff mode for the iPad's input",
        unit = {"After": "bluetooth.service", "ConditionPathExists": STORE + "/padbridge"},
        remain = False,
        install = {"WantedBy": ["bluetooth.service"]},
    ),
]
