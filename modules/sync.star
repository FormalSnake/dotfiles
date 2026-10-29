load("//lib/paths.star", "STORE")

# App data `fspec sync` moves between the Linux pair. `live` items merge both ways, newest wins;
# `seed` items copy whole to a host that has none, since single-writer databases and rotating
# tokens break when two copies diverge. Flare, Beeper and 1Password link per device instead.

PAIR = ["g815", "e1504g"]

# Chromium apps encrypt cookies and logins with this key.
def _safe_storage(application):
    return keyring(schema = "chrome_libsecret_os_crypt_password_v2", attrs = {"application": application})

def _portal(app_id):
    return keyring(schema = "org.freedesktop.portal.Secret", attrs = {"app_id": app_id})

def _wallpapers():
    return [
        sync(
            "wallpapers",
            peers = PAIR,
            paths = ["~/Pictures/Wallpapers/"],
        ),
        sync(
            "active-wallpaper",
            peers = PAIR,
            keys = json_keys("~/.local/state/formalshell/state.json", ["wallpaper"]),
            after = ["wallpapers"],
            on_receive = "[ -S \"$XDG_RUNTIME_DIR/formalshell/ipc-default.sock\" ] || exit 0; " + STORE + "/formalshell ipc --any-display call wallpaper set {wallpaper}",
        ),
    ]

def _helium():
    return [
        sync(
            "helium",
            peers = PAIR,
            paths = ["~/.config/net.imput.helium/"],
            # Per-host extension state: a copied Service Worker registry or 1Password pairing hangs its popup.
            exclude = ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache", "WidevineCdm", "Service Worker", "Extension State", "aeblfdkhhhdcdjpifhhbdiojplfjncoa", "chrome-extension_aeblfdkhhhdcdjpifhhbdiojplfjncoa_0.indexeddb.leveldb"],
            mode = "seed",
            unless_running = ["helium"],
        ),
        # Its own item, so the profile still moves while the other host's keyring is locked.
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

# Tokens that do not rotate.
def _live_tokens():
    return [
        sync("gh", peers = PAIR, keyring = [keyring(schema = "org.freedesktop.Secret.Generic", attrs = {"service": "gh:github.com", "username": "FormalSnake"})]),
        sync("obsidian-account", peers = PAIR, paths = ["~/.var/app/md.obsidian.Obsidian/config/obsidian/Local Storage/"], unless_running = ["obsidian"]),
        sync("spotify", peers = PAIR, keyring = [_portal("com.spotify.Client")]),
        sync("goa-google", peers = PAIR, keyring = [keyring(schema = "org.gnome.OnlineAccounts", attrs = {"goa-identity": "google:*"})]),
        sync("remmina", peers = PAIR, keyring = [keyring(schema = "org.remmina.Password")]),
    ]

def sync_items():
    return _wallpapers() + _helium() + _seeded() + _live_tokens()
