load("//modules/linux/store.star", "sh")

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
    # The distro's rustup starts with no default toolchain.
    file("~/.rustup/settings.toml", mode = "patch", owns = {"default_toolchain": "stable-x86_64-unknown-linux-gnu"}),
    # Its releases carry only darwin assets.
    pkg("lumen", source = git("https://github.com/jnsahaj/lumen", rev = "4ad27231c3614e3f2acbc07bc794a4e8fde06fbf")),
    pkg(
        "beeper",
        source = url("https://beeper-desktop.download.beeper.com/builds/Beeper-4.3.73-x86_64.AppImage"),
        build = sh(BEEPER_BUILD),
    ),
]
