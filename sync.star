# App data the spec cannot declare, moved between the Linux pair by `fspec sync` (docs/design.md,
# "Sync between hosts"). Both hosts load the same items from spec.star.
#
# live  both hosts write, newest wins per file, keyring item and JSON key.
# seed  copied whole to a host that has none of it, then each keeps its own: single-writer
#       LevelDB/SQLite profiles and rotating refresh tokens break when two copies diverge.
#       `fspec sync <item> --from <host>` hands one over again.
#
# Never synced, each host links itself, so nobody adds them here:
#   Flare (Signal): a linked device per host.
#   Beeper: Matrix device keys, one session per device.
#   1Password: each host is a registered device.

PAIR = ["g815", "e1504g"]
PKG_BIN = "/opt/fspec/current/bin"

# Chromium-family apps encrypt cookies and logins with this key; a profile without it comes up
# signed out.
def _safe_storage(application):
    return keyring(schema = "chrome_libsecret_os_crypt_password_v2", attrs = {"application": application})

# Flathub apps keep their secret through the portal, one item per app id.
def _portal(app_id):
    return keyring(schema = "org.freedesktop.portal.Secret", attrs = {"app_id": app_id})

def _wallpapers():
    return [
        sync(
            "wallpapers",
            peers = PAIR,
            # dark/, light/, originals/ and the loose files at the top, which pickers also offer.
            paths = ["~/Pictures/Wallpapers/"],
        ),
        # The rest of state.json is per host. formalshell-greeter-mirror.path (system.star) watches
        # state.json, so the greeter follows.
        sync(
            "active-wallpaper",
            peers = PAIR,
            keys = json_keys("~/.local/state/formalshell/state.json", ["wallpaper"]),
            after = ["wallpapers"],
            # With no shell running (logged out) there is nothing to tell: it reads state.json at start.
            on_receive = "[ -S \"$XDG_RUNTIME_DIR/formalshell/ipc-default.sock\" ] || exit 0; " + PKG_BIN + "/formalshell ipc --any-display call wallpaper set {wallpaper}",
        ),
    ]

# The e1504g also syncs a helium-profile folder through syncthing; that folder goes once this seed
# has run. Syncthing itself stays.
def _helium():
    return [
        sync(
            "helium",
            peers = PAIR,
            paths = ["~/.config/net.imput.helium/"],
            # Per-host extension state: a copied Service Worker registry or 1Password pairing leaves its popup spinning forever.
            exclude = ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache", "WidevineCdm", "Service Worker", "Extension State", "aeblfdkhhhdcdjpifhhbdiojplfjncoa", "chrome-extension_aeblfdkhhhdcdjpifhhbdiojplfjncoa_0.indexeddb.leveldb"],
            mode = "seed",
            unless_running = ["helium"],
        ),
        # Its own item, since a locked keyring fails the item that carries it: the profile can move
        # while the other host is logged out, and the key follows once both keyrings are open.
        sync("helium-key", peers = PAIR, keyring = [_safe_storage("chromium")], mode = "seed", after = ["helium"]),
    ]

def _seeded():
    return [
        sync("discord", peers = PAIR, paths = ["~/.config/discord/"], exclude = ["Cache", "Code Cache", "GPUCache", "modules"], mode = "seed", unless_running = ["Discord"]),
        sync("steam", peers = PAIR, paths = ["~/.local/share/Steam/config/loginusers.vdf", "~/.local/share/Steam/config/config.vdf"], mode = "seed", unless_running = ["steam"]),
        sync(
            "heroic",
            peers = PAIR,
            paths = ["~/.config/heroic/"],
            keyring = [
                keyring(schema = "org.freedesktop.Secret.Generic", attrs = {"service": "com.epicgames.eglv2.prod", "username": "credentials"}),
                keyring(schema = "org.freedesktop.Secret.Generic", attrs = {"service": "com.epicgames.eglv2.dpop", "username": "v1"}),
            ],
            mode = "seed",
            unless_running = ["heroic"],
        ),
        sync("prismlauncher", peers = PAIR, paths = ["~/.local/share/PrismLauncher/accounts.json", "~/.local/share/ModrinthApp/"], mode = "seed", unless_running = ["prismlauncher", "ModrinthApp"]),
        sync("claude-code", peers = PAIR, paths = ["~/.claude/.credentials.json"], mode = "seed"),
        sync("kopuz", peers = PAIR, paths = ["~/.config/kopuz/"], mode = "seed", unless_running = ["kopuz", "kopuzd"]),
        sync("lynk", peers = PAIR, paths = ["~/.config/lynk/"], mode = "seed", unless_running = ["lynk"]),
    ]

# Plain tokens that do not rotate: both hosts hold the same one.
def _live_tokens():
    return [
        sync("gh", peers = PAIR, keyring = [keyring(schema = "org.freedesktop.Secret.Generic", attrs = {"service": "gh:github.com", "username": "FormalSnake"})]),
        # The account token sits in Electron's Local Storage, a LevelDB, so it moves only while
        # Obsidian is closed on both ends.
        sync("obsidian-account", peers = PAIR, paths = ["~/.var/app/md.obsidian.Obsidian/config/obsidian/Local Storage/"], unless_running = ["obsidian"]),
        sync("spotify", peers = PAIR, keyring = [_portal("com.spotify.Client")]),
        sync("goa-google", peers = PAIR, keyring = [keyring(schema = "org.gnome.OnlineAccounts", attrs = {"goa-identity": "google:*"})]),
        sync("remmina", peers = PAIR, keyring = [keyring(schema = "org.remmina.Password")]),
    ]

def sync_items():
    return _wallpapers() + _helium() + _seeded() + _live_tokens()
