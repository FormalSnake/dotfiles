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

def nd_app(name, title, repo, rev, icon):
    """A NativeDesktop app built from source and wrapped in the bundle its nix package makes."""
    plist = "".join([
        '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>',
        "<key>CFBundleDevelopmentRegion</key><string>en</string>",
        "<key>CFBundleExecutable</key><string>%s</string>" % name,
        "<key>CFBundleIdentifier</key><string>dev.formalsnake.%s</string>" % name,
        "<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>",
        "<key>CFBundleName</key><string>%s</string>" % title,
        "<key>CFBundleDisplayName</key><string>%s</string>" % title,
        "<key>CFBundlePackageType</key><string>APPL</string>",
        "<key>CFBundleShortVersionString</key><string>0.1.0</string>",
        "<key>CFBundleVersion</key><string>0.1.0</string>",
        "<key>CFBundleIconFile</key><string>AppIcon</string>",
        "<key>LSMinimumSystemVersion</key><string>14.0</string>",
        "<key>NSPrincipalClass</key><string>NSApplication</string>",
        "<key>NSHighResolutionCapable</key><true/>",
        # A Dock launch has no Homebrew on PATH, and the apps shell out to ffmpeg.
        "<key>LSEnvironment</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>",
        "</dict></plist>",
    ])
    app = "$FSPEC_OUT/%s.app/Contents" % title
    return pkg(
        name,
        source = git("https://github.com/" + repo, rev = rev),
        build = sh(
            "cargo build --release --locked --package " + name,
            "mkdir -p \"%s/MacOS\" \"%s/Resources\" \"$FSPEC_OUT/bin\"" % (app, app),
            "printf '%%s' '%s' > \"%s/Info.plist\"" % (plist, app),
            "printf 'APPL????' > \"%s/PkgInfo\"" % app,
            # macOS 26's sips fails writing a 1024px PNG straight to icns; iconutil takes an iconset.
            "mkdir -p \"$FSPEC_SRC.iconset\"",
            "for s in 16 32 128 256 512; do sips -z $s $s %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}.png\" > /dev/null; sips -z $((s*2)) $((s*2)) %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}@2x.png\" > /dev/null; done" % (icon, icon),
            "iconutil -c icns \"$FSPEC_SRC.iconset\" -o \"%s/Resources/AppIcon.icns\"" % app,
            "cp target/release/%s \"%s/MacOS/%s\"" % (name, app, name),
            "ln -s ../%s.app/Contents/MacOS/%s \"$FSPEC_OUT/bin/%s\"" % (title, name, name),
        ),
        apps = [title + ".app"],
    )

STORE = [
    pkg("pi", version = "1.1.0", source = github("badlogic/pi-mono", asset = "pi-darwin-arm64.tar.gz")),
    pkg("stripe", version = "1.43.2", source = github("stripe/stripe-cli", asset = "stripe_*_mac-os_arm64.tar.gz")),
    pkg("portless", version = "0.15.4", source = npm("portless")),
    pkg("kopuz", version = "0.67.0", source = github("Kopuz-org/kopuz", asset = "Kopuz_*_aarch64.dmg"), apps = ["Kopuz.app"]),
    nd_app("messages", "Messages", "FormalStudio/messages", "29ac1eeedd10745377486851075691e0ec45800e", "packaging/linux/dev.formalsnake.messages.png"),
    nd_app("formalmusic", "FormalMusic", "FormalStudio/formalmusic", "4aeef799e584f6a69a40eef9fb69d92f73b1611d", "packaging/icon.png"),
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
