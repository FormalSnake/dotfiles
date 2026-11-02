load("//modules/linux/store.star", "sh")

# ArtCraft's Craft apps (getartcraft.com), from each app's GitHub release rather than the ArtCraft
# Launcher. Its flatpak remote serves from private ghcr packages, so anonymous installs get a 401.
CRAFTS = [
    "cadcraft", "deckcraft", "designcraft", "effectcraft", "figcraft", "filmcraft", "gridcraft",
    "lightcraft", "pdfcraft", "photocraft", "soundcraft", "texturecraft", "vectorcraft", "wordcraft",
]

# The tarball is a prefix inside a versioned top directory; lifting it keeps the share paths fixed.
LIFT = 'cp -a "$FSPEC_SRC"/*/. "$FSPEC_OUT/"'

def _craft(name):
    entry = "applications/ai.storyteller.%s.desktop" % name
    icon = "icons/hicolor/512x512/apps/ai.storyteller.%s.png" % name
    return pkg(
        name,
        # `?.` keeps pdfcraft-cli and figcraft-server out of the match.
        source = github("storytold/" + name, asset = name + "-?.*-linux-x86_64.tar.gz"),
        build = sh(LIFT),
        share = {entry: "share/" + entry, icon: "share/" + icon},
    )

def artcraft(host):
    return [_craft(n) for n in CRAFTS] if host.platform.is_linux else []
