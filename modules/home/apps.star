load("//lib/paths.star", "HOME", "TUMBLEWEED")
load("//modules/linux/store.star", "sh")

NATIVEDESKTOP = "7ad936d8bcf2ef7c7d026798cb63044b9c088b71"
NATIVEDESKTOP_DEPS = [
    "gcc", "gcc-c++", "make", "pkgconf", "git-core", "curl", "tar", "xz", "fontconfig-devel",
    "freetype2-devel", "libxkbcommon-devel", "libxkbcommon-x11-devel", "wayland-devel", "vulkan-devel",
    "libX11-devel", "alsa-devel", "dbus-1-devel", "libopenssl-devel",
]

KOPUZ_BUILD = """set -e
cd "$FSPEC_SRC"
chmod +x kopuz
./kopuz --appimage-extract >/dev/null
install -Dm755 squashfs-root/usr/bin/kopuz "$FSPEC_OUT/bin/kopuz"
install -Dm644 squashfs-root/usr/lib/libxdo.so.3 "$FSPEC_OUT/lib/libxdo.so.3"
"""

# Stubs registerLinuxConfig, which rewrote Beeper.desktop on every launch. The stub is padded to
# the module's size so the asar header stays valid; Electron checks asar integrity only on macOS
# and Windows.
BEEPER_BUILD = """set -e
cd "$FSPEC_SRC"
chmod +x beeper
./beeper --appimage-extract >/dev/null
python3 - squashfs-root/resources/app.asar <<'PY'
import json, struct, sys
with open(sys.argv[1], "r+b") as f:
    head = f.read(16)
    base = 8 + struct.unpack_from("<I", head, 4)[0]
    header = json.loads(f.read(struct.unpack_from("<I", head, 12)[0]))
    main = header["files"]["build"]["files"]["main"]["files"]
    (name,) = [n for n in main if n.startswith("linux-") and n.endswith(".mjs")]
    stub = b"export function registerLinuxConfig(){}"
    assert len(stub) <= main[name]["size"]
    f.seek(base + int(main[name]["offset"]))
    f.write(stub.ljust(main[name]["size"]))
PY
cp -a squashfs-root/. "$FSPEC_OUT/"
mkdir -p "$FSPEC_OUT/bin"
printf '#!/bin/sh\nexec "$(dirname "$(readlink -f "$0")")/../AppRun" "$@"\n' > "$FSPEC_OUT/bin/beeper"
chmod +x "$FSPEC_OUT/bin/beeper"
"""

FLATPAKS = [
    pkg("flare", source = flatpak("de.schmidhuberj.Flare")),
    pkg("obsidian", source = flatpak("md.obsidian.Obsidian")),
    pkg("apostrophe", source = flatpak("org.gnome.gitlab.somas.Apostrophe")),
]

TOOLS = [
    pkg("t3code-desktop", version = "0.1.3", source = github("pingdotgg/t3code", asset = "T3-Code-*-x86_64.AppImage")),
    # Cargo.toml points at a NativeDesktop checkout beside the repo.
    pkg(
        "messages",
        source = git(
            "https://github.com/FormalStudio/messages",
            rev = "097b732d57198bbaa2386b6e072416f9e6c0184e",
            image = TUMBLEWEED,
            deps = ["rustup"] + NATIVEDESKTOP_DEPS,
        ),
        build = sh("; ".join([
            "set -e",
            'nd="$FSPEC_SRC/../nativedesktop-wt-msg-linux"',
            'git init -q "$nd"',
            'git -C "$nd" fetch -q --depth 1 https://github.com/FormalStudio/NativeDesktop ' + NATIVEDESKTOP,
            'git -C "$nd" checkout -q FETCH_HEAD',
            'cd "$FSPEC_SRC"',
            "cargo build --release --locked -p messages",
            'install -Dm755 target/release/messages "$FSPEC_OUT/bin/messages"',
        ])),
    ),
    # The distro's rustup starts with no default toolchain.
    file("~/.rustup/settings.toml", mode = "patch", owns = {"default_toolchain": "stable-x86_64-unknown-linux-gnu"}),
    # Its releases carry only darwin assets.
    pkg("lumen", source = git("https://github.com/jnsahaj/lumen", rev = "4ad27231c3614e3f2acbc07bc794a4e8fde06fbf")),
    # kopuzd opens the same database and an app older than the daemon refuses its schema: bump
    # them together. The AppImage's WebKit only works from Ubuntu's paths, so only the binary and
    # libxdo are kept.
    pkg(
        "kopuz",
        source = url("https://github.com/Kopuz-org/kopuz/releases/download/v0.67.0/Kopuz_0.67.0_x86_64.AppImage"),
        build = sh(KOPUZ_BUILD),
    ),
    pkg(
        "beeper",
        source = url("https://beeper-desktop.download.beeper.com/builds/Beeper-4.3.73-x86_64.AppImage"),
        build = sh(BEEPER_BUILD),
    ),
    # Cargo.toml points at ../nativedesktop, and libghostty-vt builds with zig 0.16.0.
    pkg(
        "formalmusic",
        source = git(
            "https://github.com/FormalStudio/formalmusic",
            rev = "4aeef799e584f6a69a40eef9fb69d92f73b1611d",
            image = TUMBLEWEED,
            deps = ["cargo"] + NATIVEDESKTOP_DEPS,
        ),
        build = sh("; ".join([
            "set -e",
            "w=$(mktemp -d)",
            "git clone -q https://github.com/FormalStudio/NativeDesktop $w/nativedesktop",
            "git -C $w/nativedesktop checkout -q " + NATIVEDESKTOP,
            "cp -r $FSPEC_SRC $w/formalmusic",
            "curl -fsSL https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz | tar -xJ -C $w",
            "PATH=$w/zig-x86_64-linux-0.16.0:$PATH cargo build --release --locked --manifest-path $w/formalmusic/Cargo.toml --package formalmusic",
            "install -Dm755 $w/formalmusic/target/release/formalmusic $FSPEC_OUT/bin/formalmusic",
        ])),
    ),
]
