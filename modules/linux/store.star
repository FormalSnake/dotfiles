load("//lib/paths.star", "TUMBLEWEED")

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

# dev/tarball.sh is upstream's release build. WORK in the cache keeps rev bumps incremental.
FORMALSHELL = pkg(
    "formalshell",
    source = git(
        "https://github.com/FormalStudio/FormalShell",
        rev = "ce12c5ede7d373d9ded5b0d5e964b79885f1095c",
        image = "docker.io/library/debian:bookworm",
    ),
    build = sh('WORK="$FSPEC_CACHE" bash "$FSPEC_SRC/dev/tarball.sh" "$FSPEC_OUT.tar" && tar -xzf "$FSPEC_OUT.tar"/formalshell-*-linux.tar.gz -C "$FSPEC_OUT" && rm -rf "$FSPEC_OUT.tar"'),
)

STORE = [
    # 0.10.0 is the first with the Stream Deck Mini Discord Edition; Tumbleweed has 0.9.8.
    pkg(
        "python-streamdeck",
        source = url("https://files.pythonhosted.org/packages/e9/c2/f6ffbad24afae8a19692edf68011cad105832f7b8a460be051fec9455c20/streamdeck-0.10.0.tar.gz"),
        share = {"python/streamdeck": "streamdeck-0.10.0/src"},
    ),
    pkg(
        "bibata",
        version = "2.0.7",
        source = github("ful1e5/Bibata_Cursor", asset = "Bibata-Modern-Classic.tar.xz"),
        share = {"icons/Bibata-Modern-Classic": "Bibata-Modern-Classic"},
    ),
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
        "geist-mono-nerd-font",
        version = "3.4.0",
        source = github("ryanoasis/nerd-fonts", asset = "GeistMono.tar.xz"),
        share = {"fonts/GeistMonoNerdFont": "."},
    ),
    FORMALSHELL,
    # helium-wrapper sets LD_LIBRARY_PATH to its own directory.
    pkg(
        "helium",
        version = "0.19.4.1",
        source = github("imputnet/helium-linux", asset = "helium-*_linux.tar.xz"),
        links = {"helium": "helium-wrapper"},
    ),
    pkg("matugen", version = "4.2.0", source = github("InioX/matugen", asset = "matugen-*-x86_64.tar.gz")),
    pkg("wl-clip-persist", source = git("https://github.com/Linus789/wl-clip-persist", rev = "v0.5.0")),
    pkg("wl-gammarelay-rs", source = git("https://github.com/MaxVerevkin/wl-gammarelay-rs", rev = "v1.0.1")),
    pkg(
        "librepods",
        source = git(
            "https://github.com/thisisgm/omarchy-pods",
            rev = "307c5a6d2109f088d8e6a558c933ebe4f6b1db01",
            image = TUMBLEWEED,
            deps = [
                "cmake", "make", "gcc-c++", "pkgconf", "qt6-base-devel", "qt6-declarative-devel",
                "qt6-quickcontrols2-devel", "qt6-connectivity-devel", "qt6-tools-devel",
                "qt6-linguist-devel", "libopenssl-devel", "libpulse-devel",
            ],
        ),
        patches = glob("patches/librepods-*.patch"),
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
        source = url("https://github.com/CachyOS/ananicy-rules/archive/03ef03fbf7e834385377432ccecaedd32e3414bb.tar.gz"),
        share = {"ananicy-rules/cachyos": "ananicy-rules-03ef03fbf7e834385377432ccecaedd32e3414bb"},
    ),
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
