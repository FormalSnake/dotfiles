load("//lib/paths.star", "STORE", "TUMBLEWEED")

# The apps I make, one version for every host. NativeDesktop comes in through each app's Cargo.lock.

# `rust` is what builds it on Linux: rustup follows a rust-toolchain.toml, else the distro's cargo.
APPS = {
    "messages": {"title": "Messages", "rev": "c51a96332f874a9665a8b81be81763ea70ff12b5", "icon": "packaging/linux/dev.formalsnake.messages.png", "rust": "rustup"},
    "formalmusic": {"title": "FormalMusic", "rev": "4aeef799e584f6a69a40eef9fb69d92f73b1611d", "icon": "packaging/icon.png", "rust": "cargo"},
    "formalnotes": {"title": "Formal Notes", "rev": "3b664864da8c08cdfdd54fbd98f70bda6679a7c1", "icon": "packaging/icon.png", "rust": "rustup", "desktop": "dev.formalsnake.formalnotes"},
    # `dbus` names D-Bus services the app ships in packaging/linux, `portal` its xdg-desktop-portal backend.
    "trove": {"title": "Trove", "rev": "f4b2889e9d81dda0b2c253545b8def33314f27dd", "icon": "packaging/icon.png", "rust": "rustup", "desktop": "dev.formalsnake.trove",
              "dbus": ["org.freedesktop.impl.portal.desktop.trove", "org.freedesktop.FileManager1"], "portal": "trove"},
}

# The AppImage carries its own kopuzd.
KOPUZ = "1.0.1"

ND_DEPS = [
    "gcc", "gcc-c++", "make", "pkgconf", "git-core", "curl", "tar", "xz", "fontconfig-devel",
    "freetype2-devel", "libxkbcommon-devel", "libxkbcommon-x11-devel", "wayland-devel", "vulkan-devel",
    "libX11-devel", "alsa-devel", "dbus-1-devel", "libopenssl-devel",
]

# libghostty-vt builds with zig 0.16.0.
ZIG = "https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz"

# The AppImage's bundled libs are older copies of the distro's, so only the binaries are kept.
KOPUZ_LINUX = """set -e
cd "$FSPEC_SRC"
chmod +x kopuz
./kopuz --appimage-extract >/dev/null
for b in kopuz kopuzd kopuzctl; do install -Dm755 squashfs-root/usr/bin/$b "$FSPEC_OUT/bin/$b"; done
install -Dm644 squashfs-root/kopuz.desktop "$FSPEC_OUT/applications/kopuz.desktop"
install -Dm644 squashfs-root/usr/share/icons/hicolor/440x440/apps/kopuz.png "$FSPEC_OUT/icons/hicolor/440x440/apps/kopuz.png"
"""
KOPUZ_SHARE = ["applications/kopuz.desktop", "icons/hicolor/440x440/apps/kopuz.png"]

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
    url = "https://github.com/" + app.get("repo", "FormalStudio/" + name)
    if host.platform.is_linux:
        steps = [
            'mkdir -p "$FSPEC_SRC.zig"',
            'curl -fsSL %s | tar -xJ -C "$FSPEC_SRC.zig" --strip-components 1' % ZIG,
            'PATH="$FSPEC_SRC.zig:$PATH" cargo build --release --locked --package ' + name,
            'install -Dm755 target/release/%s "$FSPEC_OUT/bin/%s"' % (name, name),
        ]
        share = {}
        desktop = app.get("desktop")
        if desktop:
            entry = "applications/%s.desktop" % desktop
            icon = "icons/hicolor/512x512/apps/%s.png" % desktop
            steps += [
                'install -Dm644 packaging/linux/%s.png "$FSPEC_OUT/%s"' % (desktop, icon),
                'install -Dm644 packaging/linux/%s.desktop "$FSPEC_OUT/%s"' % (desktop, entry),
            ]
            share[entry] = entry
            share[icon] = icon
        # D-Bus runs Exec as written, so it names the store's link to the binary.
        for service in app.get("dbus", []):
            dest = "dbus-1/services/%s.service" % service
            steps += [
                'mkdir -p "$FSPEC_OUT/dbus-1/services"',
                "sed 's|^Exec=/usr/bin/%s |Exec=%s/%s |' packaging/linux/%s.service > \"$FSPEC_OUT/%s\"" % (name, STORE, name, service, dest),
            ]
            share[dest] = dest
        portal = app.get("portal")
        if portal:
            dest = "xdg-desktop-portal/portals/%s.portal" % portal
            steps.append('install -Dm644 packaging/linux/%s.portal "$FSPEC_OUT/%s"' % (portal, dest))
            share[dest] = dest
        return pkg(
            name,
            source = git(url, rev = app["rev"], image = TUMBLEWEED, deps = [app["rust"]] + ND_DEPS),
            build = _sh(*steps),
            share = share,
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
            "ln -s \"../%s.app/Contents/MacOS/%s\" \"$FSPEC_OUT/bin/%s\"" % (title, name, name),
        ),
        apps = [title + ".app"],
    )

def my_apps(host):
    linux = host.platform.is_linux
    return [_nd_app(host, name, app) for name, app in APPS.items() if linux or not app.get("linux_only")] + ([
        # A desktop music player: not on the headless macbook.
        pkg(
            "kopuz",
            version = KOPUZ,
            source = github("Kopuz-org/kopuz", asset = "Kopuz_*_x86_64.AppImage"),
            build = ["sh", "-c", KOPUZ_LINUX],
            share = {p: p for p in KOPUZ_SHARE},
        ),
    ] if linux else []) + [
        pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "69f954dca8ac24b7e5b269f486f3dae3fc2ec7b5")),
    ] + ([
        # Runs Mac apps; mac(...) packages install through it.
        pkg("atoll", version = "0.1.10", source = github("FormalStudio/atoll")),
    ] if linux else [])
