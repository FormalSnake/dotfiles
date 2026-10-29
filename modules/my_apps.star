load("//lib/paths.star", "TUMBLEWEED")

# The apps I make, one version for every host. NativeDesktop comes in through each app's Cargo.lock.

# `rust` is what builds it on Linux: rustup follows a rust-toolchain.toml, else the distro's cargo.
APPS = {
    "messages": {"title": "Messages", "rev": "52c563b95cac01962e30a0c5c9a56bcf808094ce", "icon": "packaging/linux/dev.formalsnake.messages.png", "rust": "rustup"},
    "formalmusic": {"title": "FormalMusic", "rev": "4aeef799e584f6a69a40eef9fb69d92f73b1611d", "icon": "packaging/icon.png", "rust": "cargo"},
}

# kopuzd opens the app's database, and an app older than the daemon refuses its schema, so both
# come from one release.
KOPUZ = "0.67.0"

ND_DEPS = [
    "gcc", "gcc-c++", "make", "pkgconf", "git-core", "curl", "tar", "xz", "fontconfig-devel",
    "freetype2-devel", "libxkbcommon-devel", "libxkbcommon-x11-devel", "wayland-devel", "vulkan-devel",
    "libX11-devel", "alsa-devel", "dbus-1-devel", "libopenssl-devel",
]

# libghostty-vt builds with zig 0.16.0.
ZIG = "https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz"

# The AppImage's WebKit only works from Ubuntu's paths, so only the binary and libxdo are kept.
KOPUZ_LINUX = """set -e
cd "$FSPEC_SRC"
chmod +x kopuz
./kopuz --appimage-extract >/dev/null
install -Dm755 squashfs-root/usr/bin/kopuz "$FSPEC_OUT/bin/kopuz"
install -Dm644 squashfs-root/usr/lib/libxdo.so.3 "$FSPEC_OUT/lib/libxdo.so.3"
"""

def _sh(*steps):
    return ["sh", "-c", " && ".join(["set -e", 'cd "$FSPEC_SRC"'] + list(steps))]

def _plist(name, title):
    return "".join([
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

def _nd_app(host, name, app):
    """A NativeDesktop app built from source: a bundle like its nix package made on the macbook,
    the bare binary on Linux."""
    url = "https://github.com/FormalStudio/" + name
    if host.platform.is_linux:
        return pkg(
            name,
            source = git(url, rev = app["rev"], image = TUMBLEWEED, deps = [app["rust"]] + ND_DEPS),
            build = _sh(
                'mkdir -p "$FSPEC_SRC.zig"',
                'curl -fsSL %s | tar -xJ -C "$FSPEC_SRC.zig" --strip-components 1' % ZIG,
                'PATH="$FSPEC_SRC.zig:$PATH" cargo build --release --locked --package ' + name,
                'install -Dm755 target/release/%s "$FSPEC_OUT/bin/%s"' % (name, name),
            ),
        )
    title, icon = app["title"], app["icon"]
    contents = "$FSPEC_OUT/%s.app/Contents" % title
    return pkg(
        name,
        source = git(url, rev = app["rev"]),
        build = _sh(
            "cargo build --release --locked --package " + name,
            "mkdir -p \"%s/MacOS\" \"%s/Resources\" \"$FSPEC_OUT/bin\"" % (contents, contents),
            "printf '%%s' '%s' > \"%s/Info.plist\"" % (_plist(name, title), contents),
            "printf 'APPL????' > \"%s/PkgInfo\"" % contents,
            # macOS 26's sips fails writing a 1024px PNG straight to icns; iconutil takes an iconset.
            "mkdir -p \"$FSPEC_SRC.iconset\"",
            "for s in 16 32 128 256 512; do sips -z $s $s %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}.png\" > /dev/null; sips -z $((s*2)) $((s*2)) %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}@2x.png\" > /dev/null; done" % (icon, icon),
            "iconutil -c icns \"$FSPEC_SRC.iconset\" -o \"%s/Resources/AppIcon.icns\"" % contents,
            "cp target/release/%s \"%s/MacOS/%s\"" % (name, contents, name),
            "ln -s ../%s.app/Contents/MacOS/%s \"$FSPEC_OUT/bin/%s\"" % (title, name, name),
        ),
        apps = [title + ".app"],
    )

def my_apps(host):
    linux = host.platform.is_linux
    kopuzd_build = {"image": TUMBLEWEED, "deps": ["rustup", "gcc", "cmake", "make", "pkgconf", "alsa-devel", "dbus-1-devel", "libopenssl-devel", "git-core", "gcc-c++"]} if linux else {}
    return [_nd_app(host, name, app) for name, app in APPS.items()] + [
        pkg(
            "kopuz",
            version = KOPUZ,
            source = github("Kopuz-org/kopuz", asset = "Kopuz_*_x86_64.AppImage" if linux else "Kopuz_*_aarch64.dmg"),
            **({"build": ["sh", "-c", KOPUZ_LINUX]} if linux else {"apps": ["Kopuz.app"]})
        ),
        pkg(
            "kopuzd",
            source = git("https://github.com/Kopuz-org/kopuz", rev = "v" + KOPUZ, **kopuzd_build),
            build_flags = ["-p", "kopuz-kopuzd", "-p", "kopuz-ctl"],
            bins = ["kopuzd", "kopuzctl"],
        ),
        pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "69f954dca8ac24b7e5b269f486f3dae3fc2ec7b5")),
    ]
