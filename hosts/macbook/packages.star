# Homebrew stays Homebrew; the store carries what has no formula or cask.

FORMULAE = [
    "coreutils", "stow", "watchman", "terminal-notifier", "cmake", "go", "zig", "deno", "python@3.14",
    "pillow", "opencode", "dipc", "ffmpeg", "cocoapods", "fastlane", "xcbeautify", "mas", "libadwaita",
    # clipssh's clipboard images
    "pngpaste",
    # network, remote iPhone, VPN
    "wireguard-tools", "libimobiledevice", "ideviceinstaller", "openssl@3",
    # Obsidian LiveSync's backend
    "couchdb",
]

CASKS = [
    "aldente", "android-studio", "betterdisplay", "bluebubbles",
    "clop", "codex", "font-sf-pro", "ghostty", "google-chrome", "gstreamer-runtime",
    "jump-desktop-connect", "orbstack", "syncthing-app", "t3-code",
    "terminal-browser", "the-unarchiver", "zulu@21",
]

BREW = (
    [pkg(n, source = brew()) for n in FORMULAE] +
    [pkg(n, source = brew(cask = True)) for n in CASKS] +
    [pkg("markdown-preview", source = brew(cask = True, tap = "pluk-inc/tap"))]
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
    # sudo's PAM module, with nixpkgs' patches against the system OpenPAM. Modern autoconf picks
    # gnu23, which breaks the K&R code in openbsd-compat, and the SDK's fortify macros collide
    # with its replacements.
    pkg(
        "pam_ssh_agent_auth",
        source = git("https://github.com/jbeverly/pam_ssh_agent_auth", rev = "7ff785809f6ecad45051e333c0ffa72e15ba4f2a"),
        patches = glob("patches/pam_ssh_agent_auth-*.patch"),
        build = sh(
            "git clone -q https://github.com/floodyberry/ed25519-donna \"$FSPEC_SRC.donna\"",
            "git -C \"$FSPEC_SRC.donna\" checkout -q 8757bd4cd209cb032853ece0ce413f122eef212c",
            "mkdir -p ed25519-donna && cp -R \"$FSPEC_SRC.donna/.\" ed25519-donna/",
            "brew install -q autoconf automake openssl@3",
            "autoreconf -fi",
            "ssl=$(brew --prefix openssl@3)",
            "CFLAGS=\"-std=gnu99 -D_FORTIFY_SOURCE=0\" ./configure --without-openssl-header-check --with-cflags=\"-I$PWD -I$ssl/include\" --with-ldflags=\"-L$ssl/lib\"",
            "make LD=cc",
            "mkdir -p \"$FSPEC_OUT/lib\"",
            "install -m755 pam_ssh_agent_auth.so \"$FSPEC_OUT/lib/pam_ssh_agent_auth.so\"",
        ),
    ),
]
