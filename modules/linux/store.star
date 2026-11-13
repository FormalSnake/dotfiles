load("//lib/paths.star", "LIBEXEC", "TUMBLEWEED")

# What no Tumbleweed repo carries: vendor repos, upstream releases and source builds.

NIL_BUILD = """set -e
rustup -q default stable
cargo build --release --locked --manifest-path "$FSPEC_SRC/Cargo.toml" --target-dir "$FSPEC_SRC/target" -p nil
install -Dm755 "$FSPEC_SRC/target/release/nil" "$FSPEC_OUT/bin/nil"
"""

ANCS4LINUX_BUILD = """set -e
python3.13 -m pip install --no-deps --no-build-isolation --target "$FSPEC_OUT/lib" "$FSPEC_SRC"
mkdir -p "$FSPEC_OUT/bin"
for m in observer advertising ctl desktop_integration; do
  c="$FSPEC_OUT/bin/ancs4linux-$(echo $m | tr _ -)"
  cat > "$c" <<EOF
#!/bin/sh
PYTHONPATH="\\$(dirname "\\$(readlink -f "\\$0")")/../lib" exec /usr/bin/python3.13 -c 'from ancs4linux.$m.main import app; app()' "\\$@"
EOF
  chmod 755 "$c"
done
"""

STEAMED = "Steamed-14e8a1c0db188870ab3ac2059dbf941fad9c3065"

def sh(script):
    return ["sh", "-c", script]

HELIUM_BUILD = """set -e
cp -a "$FSPEC_SRC"/. "$FSPEC_OUT/"
mkdir -p "$FSPEC_OUT/bin"
wrapper=$(cd "$FSPEC_OUT" && echo helium-*_linux/helium-wrapper)
cat > "$FSPEC_OUT/bin/helium" <<EOF
#!/bin/sh
exec """ + LIBEXEC + """/helium-guard "\\$(dirname "\\$(readlink -f "\\$0")")/../$wrapper" "\\$@"
EOF
chmod +x "$FSPEC_OUT/bin/helium"
"""

# dev/tarball.sh is upstream's release build. WORK in the cache keeps rev bumps incremental.
FORMALSHELL = pkg(
    "formalshell",
    source = git(
        "https://github.com/FormalStudio/FormalShell",
        rev = "d9cc2c920e6c6f1d629fb859b7efa5bcdfc5b516",
        image = "docker.io/library/debian:bookworm",
    ),
    build = sh('WORK="$FSPEC_CACHE" bash "$FSPEC_SRC/dev/tarball.sh" "$FSPEC_OUT.tar" && tar -xzf "$FSPEC_OUT.tar"/formalshell-*-linux.tar.gz -C "$FSPEC_OUT" && rm -rf "$FSPEC_OUT.tar"'),
)

# formalwm (FormalShell's wm/, the compositor of the ShojiWM session) and ShojiWM's portal from
# the rev formalwm's Cargo.lock pins. Both link Smithay's system libraries, too new for the
# shell's Debian image. The toolchain, cargo's registry and target live in the cache, so a rev
# bump builds incrementally.
SHOJI_REV = "74bc0a2e13804b94640075cb089cf940763f1079"

SHOJI_DEPS = [
    "rustup", "clang", "gcc", "gcc-c++", "make", "cmake", "pkgconf", "git-core", "wayland-devel",
    "wayland-protocols-devel", "libxkbcommon-devel", "systemd-devel", "libinput-devel", "libgbm-devel",
    "Mesa-libEGL-devel", "libglvnd-devel", "libpixman-1-0-devel", "seatd-devel", "libdrm-devel",
    "liblcms2-devel", "libxcb-devel", "xcb-util-cursor-devel", "dbus-1-devel", "pipewire-devel",
]

def _cargo(manifest, package):
    return """set -e
export RUSTUP_HOME="$FSPEC_CACHE/rustup" CARGO_HOME="$FSPEC_CACHE/cargo"
rustup -q default stable
cargo build --release --locked --manifest-path "$FSPEC_SRC/%s" --target-dir "$FSPEC_CACHE/target" -p %s
install -Dm755 "$FSPEC_CACHE/target/release/%s" "$FSPEC_OUT/bin/%s"
""" % (manifest, package, package, package)

# D-Bus and systemd run Exec as written, so both name the store's link to the binary.
SHOJI_PORTAL_BUILD = _cargo("Cargo.toml", "xdg-desktop-portal-shojiwm") + """cd "$FSPEC_SRC/dist"
install -Dm644 shojiwm.portal "$FSPEC_OUT/xdg-desktop-portal/portals/shojiwm.portal"
mkdir -p "$FSPEC_OUT/dbus-1/services" "$FSPEC_OUT/systemd/user"
sed 's|/usr/bin/|%s/|' org.freedesktop.impl.portal.desktop.shojiwm.service > "$FSPEC_OUT/dbus-1/services/org.freedesktop.impl.portal.desktop.shojiwm.service"
sed 's|/usr/bin/|%s/|' xdg-desktop-portal-shojiwm.service > "$FSPEC_OUT/systemd/user/xdg-desktop-portal-shojiwm.service"
""" % ("/opt/fspec/current/bin", "/opt/fspec/current/bin")

SHOJI = [
    pkg(
        "formalwm",
        source = git(
            "https://github.com/FormalStudio/FormalShell",
            rev = "d9cc2c920e6c6f1d629fb859b7efa5bcdfc5b516",
            image = TUMBLEWEED,
            deps = SHOJI_DEPS,
        ),
        build = sh(_cargo("wm/Cargo.toml", "formalwm")),
    ),
    pkg(
        "xdg-desktop-portal-shojiwm",
        source = git("https://github.com/FormalSnake/ShojiWM", rev = SHOJI_REV, image = TUMBLEWEED, deps = SHOJI_DEPS),
        build = sh(SHOJI_PORTAL_BUILD),
        share = {
            "xdg-desktop-portal/portals/shojiwm.portal": "xdg-desktop-portal/portals/shojiwm.portal",
            "dbus-1/services/org.freedesktop.impl.portal.desktop.shojiwm.service": "dbus-1/services/org.freedesktop.impl.portal.desktop.shojiwm.service",
        },
    ),
    # The user manager reads /etc/systemd/user, not /usr/local/share.
    file(
        "/etc/systemd/user/xdg-desktop-portal-shojiwm.service",
        mode = "link",
        target = "/opt/fspec/current/pkgs/xdg-desktop-portal-shojiwm/systemd/user/xdg-desktop-portal-shojiwm.service",
    ),
]

HERDR_APP_BUILD = """set -e
cp -a "$FSPEC_SRC/herdr-app" "$FSPEC_OUT/lib"
mkdir -p "$FSPEC_OUT/bin" "$FSPEC_OUT/share/applications" "$FSPEC_OUT/share/icons/hicolor/scalable/apps"
ln -s ../lib/herdr-app "$FSPEC_OUT/bin/herdr-app"
cp "$FSPEC_SRC/herdr-app/herdr-app.svg" "$FSPEC_OUT/share/icons/hicolor/scalable/apps/"
cat > "$FSPEC_OUT/share/applications/herdr-app.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Herdr
Comment=Terminals and coding agents that keep running
Exec=herdr-app
Icon=herdr-app
Terminal=false
Categories=Development;
StartupWMClass=herdr-app
EOF
"""

# A Hyprland plugin must be built against the headers of the exact Hyprland it loads into, and
# the image's live repos are already past the hosts' locked snapshot. The build takes the image
# back to the snapshot of fspec.lock's [zypper.<host>] first. Both it and the rev move with each
# Hyprland bump: the rev is upstream's hyprpm.toml pin for that Hyprland. hyprland-devel requires
# none of glslang-devel, lua55-devel and libgbm-devel, though its headers include all three, and
# its pkg-config file leaves out lua's include directory.
DYNAMIC_CURSORS_SNAPSHOT = "20261024"

DYNAMIC_CURSORS_BUILD = """set -e
zypper -q mr -d -a
zypper -q ar https://download.opensuse.org/history/%s/tumbleweed/repo/oss/ fspec-oss
zypp="zypper --non-interactive --gpg-auto-import-keys --cache-dir $FSPEC_CACHE/zypp"
$zypp dup --allow-downgrade --no-recommends
$zypp install --no-recommends hyprland-devel glslang-devel lua55-devel libgbm-devel gcc-c++ make pkgconf
make -C "$FSPEC_SRC" -j"$(nproc)" all CXX=g++ EXTRA_CXXFLAGS="$(pkg-config --cflags lua5.5)"
mkdir -p "$FSPEC_OUT/lib"
cp "$FSPEC_SRC/out/dynamic-cursors.so" "$FSPEC_OUT/lib/"
""" % DYNAMIC_CURSORS_SNAPSHOT

BIBATA = pkg(
    "bibata",
    version = "2.0.7",
    source = github("ful1e5/Bibata_Cursor", asset = "Bibata-Modern-Classic.tar.xz"),
    share = {"icons/Bibata-Modern-Classic": "Bibata-Modern-Classic"},
)

STORE = [
    # Pinned rather than left to its updater, which writes under ~/.local/share.
    pkg(
        "herdr-app",
        source = url("https://releases.herdr.dev/app/0.1.14/herdr-app-linux-x86_64.tar.gz"),
        build = sh(HERDR_APP_BUILD),
        bins = ["herdr-app"],
        share = {
            "applications/herdr-app.desktop": "share/applications/herdr-app.desktop",
            "icons/hicolor/scalable/apps/herdr-app.svg": "share/icons/hicolor/scalable/apps/herdr-app.svg",
        },
    ),
    # 0.10.0 is the first with the Stream Deck Mini Discord Edition; Tumbleweed has 0.9.8.
    pkg(
        "python-streamdeck",
        source = url("https://files.pythonhosted.org/packages/e9/c2/f6ffbad24afae8a19692edf68011cad105832f7b8a460be051fec9455c20/streamdeck-0.10.0.tar.gz"),
        share = {"python/streamdeck": "streamdeck-0.10.0/src"},
    ),
    BIBATA,
    pkg(
        "colloid-icon-theme",
        source = git(
            "https://github.com/vinceliuice/Colloid-icon-theme",
            rev = "e3a8f89fac888af715233f8f8ef0a5b1e350f0dd",
            image = TUMBLEWEED,
            deps = ["bash", "sed", "findutils", "gtk3-tools"],
        ),
        build = sh('cd "$FSPEC_SRC" && mkdir -p "$FSPEC_OUT/icons" && bash ./install.sh -d "$FSPEC_OUT/icons" -s default -t default'),
        share = {"icons/" + t: "icons/" + t for t in ["Colloid", "Colloid-Light", "Colloid-Dark"]},
    ),
    # Without it FormalShell's gtk-theme setting leaves GTK3 apps light.
    pkg(
        "adw-gtk3",
        version = "6.5",
        source = github("lassekongo83/adw-gtk3", asset = "adw-gtk3v*.tar.xz"),
        share = {"themes/adw-gtk3": "adw-gtk3", "themes/adw-gtk3-dark": "adw-gtk3-dark"},
    ),
    pkg(
        "geist-font",
        version = "1.9.0",
        source = github("vercel/geist-font", asset = "geist-font-v*.zip"),
        share = {"fonts/" + f: "geist-font/%s/ttf" % f for f in ["Geist", "GeistMono", "GeistSerif", "GeistPixel"]},
    ),
    pkg(
        "geist-mono-nerd-font",
        version = "3.4.0",
        source = github("ryanoasis/nerd-fonts", asset = "GeistMono.tar.xz"),
        share = {"fonts/GeistMonoNerdFont": "."},
    ),
    FORMALSHELL,
    # helium-wrapper sets LD_LIBRARY_PATH to its own directory. bin/helium hands it to the guard
    # every launch goes through (modules/linux/rootfs/usr/local/libexec/helium-guard).
    pkg(
        "helium",
        version = "0.19.4.1",
        source = github("imputnet/helium-linux", asset = "helium-*_linux.tar.xz"),
        build = sh(HELIUM_BUILD),
    ),
    pkg("matugen", version = "4.2.0", source = github("InioX/matugen", asset = "matugen-*-x86_64.tar.gz")),
    pkg("wl-clip-persist", source = git("https://github.com/Linus789/wl-clip-persist", rev = "v0.5.0")),
    pkg("wl-gammarelay-rs", source = git("https://github.com/MaxVerevkin/wl-gammarelay-rs", rev = "v1.0.1")),
    pkg(
        "librepods",
        source = git(
            "https://github.com/FormalSnake/omarchy-pods",
            rev = "bed4b892f6af2d7d9a206eec14351dad81671f45",
            image = TUMBLEWEED,
            deps = [
                "cmake", "make", "gcc-c++", "pkgconf", "qt6-base-devel", "qt6-declarative-devel",
                "qt6-quickcontrols2-devel", "qt6-connectivity-devel", "qt6-tools-devel",
                "qt6-linguist-devel", "libopenssl-devel", "libpulse-devel",
            ],
        ),
        build = sh('cmake -S "$FSPEC_SRC/daemon" -B "$FSPEC_CACHE/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FSPEC_OUT" && cmake --build "$FSPEC_CACHE/build" -j && cmake --install "$FSPEC_CACHE/build"'),
    ),
    # No Linux release, and its build script asks nix for its builtins. Tumbleweed's nix segfaults
    # in a container, so it builds on Debian.
    pkg(
        "nil",
        source = git(
            "https://github.com/oxalica/nil",
            rev = "dbbb5c24f9215476992aa1bd305f8e5398e89654",
            image = "docker.io/library/debian:trixie",
            deps = ["rustup", "ca-certificates", "gcc", "libc6-dev", "nix-bin"],
        ),
        build = sh(NIL_BUILD),
        bins = ["nil"],
    ),
    pkg(
        "ancs4linux",
        source = git(
            "https://github.com/pzmarzly/ancs4linux",
            rev = "138451721ff10d3c8634b32656ae3d38a99b9163",
            image = TUMBLEWEED,
            deps = ["python313-pip", "python313-hatchling"],
        ),
        patches = ["patches/ancs4linux-0-metadata.patch", "patches/ancs4linux-authorize.patch"],
        build = sh(ANCS4LINUX_BUILD),
    ),
    # Past v1.2.0, whose tag misses headers glibc 2.42 no longer pulls in.
    pkg(
        "ananicy-cpp",
        source = git(
            "https://gitlab.com/ananicy-cpp/ananicy-cpp",
            rev = "3554447c1ca495478bd00e002078847dfd2205d6",
            image = TUMBLEWEED,
            deps = [
                "cmake", "make", "gcc-c++", "pkgconf", "fmt-devel", "spdlog-devel", "nlohmann_json-devel",
                "systemd-devel", "pcre2-devel", "clang", "bpftool", "libbpf-devel", "libelf-devel", "zlib-devel",
            ],
        ),
        build_flags = [
            "-DUSE_BPF_PROC_IMPL=ON", "-DBPF_BUILD_LIBBPF=OFF", "-DENABLE_SYSTEMD=ON", "-DENABLE_REGEX_SUPPORT=ON",
            "-DUSE_EXTERNAL_FMTLIB=ON", "-DUSE_EXTERNAL_JSON=ON", "-DUSE_EXTERNAL_SPDLOG=ON", "-DVERSION=1.2.0",
        ],
        bins = ["ananicy-cpp"],
    ),
    pkg(
        "ananicy-rules",
        source = git(
            "https://github.com/CachyOS/ananicy-rules",
            rev = "03ef03fbf7e834385377432ccecaedd32e3414bb",
            image = TUMBLEWEED,
        ),
        patches = ["patches/ananicy-rules-steam.patch"],
        build = sh('mkdir -p "$FSPEC_OUT/rules" && cp -a "$FSPEC_SRC"/. "$FSPEC_OUT/rules/" && rm -rf "$FSPEC_OUT/rules/.git"'),
        share = {"ananicy-rules/cachyos": "rules"},
    ),
    # Loaded by hyprland.lua from /opt/fspec/current/pkgs/hypr-dynamic-cursors/lib.
    pkg(
        "hypr-dynamic-cursors",
        source = git(
            "https://github.com/VirtCode/hypr-dynamic-cursors",
            rev = "5a224284872208b5324759d535d65061043725de",
            image = TUMBLEWEED,
        ),
        build = sh(DYNAMIC_CURSORS_BUILD),
    ),
]

KDE_STORE = [
    pkg(
        "steamed",
        source = url("https://github.com/gaspar-of-time/Steamed/archive/14e8a1c0db188870ab3ac2059dbf941fad9c3065.tar.gz"),
        share = {
            "color-schemes/Steamed.colors": STEAMED + "/color-schemes/Steamed.colors",
            "aurorae/themes/Steamed": STEAMED + "/aurorae/themes/Steamed",
            "plasma/desktoptheme/Steamed": STEAMED + "/plasma/desktoptheme/Steamed",
            "plasma/look-and-feel/Steamed": STEAMED + "/plasma/look-and-feel/Steamed",
            "fonts/Steamed": STEAMED + "/fonts",
        },
    ),
]
