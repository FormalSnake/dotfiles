# Homebrew stays Homebrew; the store carries what has no formula or cask.

FORMULAE = [
    "coreutils", "watchman", "terminal-notifier", "cmake", "go", "zig", "deno", "python@3.14",
    "pillow", "opencode", "ffmpeg", "cocoapods", "fastlane", "xcbeautify", "xcodegen", "mas", "yt-dlp",
    # libghostty-vt builds with zig 0.16.0.
    "zig@0.16",
    # clipssh's clipboard images
    "pngpaste",
    # network, remote iPhone, VPN
    "wireguard-tools", "libimobiledevice", "ideviceinstaller", "openssl@3",
    # CanaryPulse DB tunnel (yarn tunnel:db)
    "cloudflared",
    # Obsidian LiveSync's backend
    "couchdb",
    # FormalShell's night rig, hosts/fstestmac
    "lima",
]

CASKS = [
    "aldente", "android-studio", "betterdisplay", "bluebubbles",
    "codex", "font-geist", "font-geist-mono", "font-geist-serif", "font-sf-pro", "ghostty",
    "orbstack", "terminal-browser", "zulu@21",
]

BREW = (
    [pkg(n, source = brew()) for n in FORMULAE] +
    [pkg(n, source = brew(cask = True)) for n in CASKS] +
    [pkg("sunshine", source = brew(tap = "lizardbyte/homebrew"))]
)

def sh(*steps):
    return ["sh", "-c", " && ".join(["set -e", 'cd "$FSPEC_SRC"'] + list(steps))]

STORE = [
    pkg("pi", version = "1.1.0", source = github("badlogic/pi-mono", asset = "pi-darwin-arm64.tar.gz")),
    pkg("stripe", version = "1.43.2", source = github("stripe/stripe-cli", asset = "stripe_*_mac-os_arm64.tar.gz")),
    pkg("portless", version = "0.15.4", source = npm("portless")),
    # The macOS release carries only usbfluxctl. Built as nixpkgs does, against Homebrew's
    # libplist with the format constants libplist 2.3 renamed.
    pkg(
        "usbfluxd",
        source = git("https://github.com/corellium/usbfluxd", rev = "422734fd2b01ad4fefeefb9c8c4e65a5abd69f0f"),
        build = sh(
            "brew install -q autoconf automake libtool pkgconf libplist",
            "sed -i '' 's/with_static_libplist=yes/with_static_libplist=no/' configure.ac",
            "sed -i '' -e 's|PLIST_FORMAT_BINARY|//PLIST_FORMAT_BINARY|' -e 's|PLIST_FORMAT_XML,|NOT_PLIST_FORMAT_XML,|' usbfluxd/utils.h",
            "autoreconf -fi",
            "./configure",
            "make",
            "mkdir -p \"$FSPEC_OUT/bin\"",
            "install -m755 usbfluxd/usbfluxd tools/usbfluxctl \"$FSPEC_OUT/bin/\"",
        ),
    ),
]
