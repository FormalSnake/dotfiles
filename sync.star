# Draft: nothing loads this yet. Wire `sync_items()` into the g815 and e1504g modules in spec.star
# when fspec has sync. The builtins (`sync`, `json_keys`, `keyring`) are the shape proposed to
# formalspec, not ones the engine has.
#
# Peer to peer and encrypted between the hosts, no GitHub or other relay. Two modes:
#   live  both hosts write; a change goes to the peers, `conflict` decides between two writes.
#   seed  copied once to a host that lacks it, then each host keeps its own. For single-writer
#         LevelDB/SQLite stores and rotating refresh tokens, which break when two copies diverge.
# `keyring` items are Secret Service entries matched by schema and attributes, moved with the files
# they unlock.
#
# Never synced, linked on each device instead, so nobody adds them here:
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
            paths = ["~/Pictures/Wallpapers/dark/", "~/Pictures/Wallpapers/light/", "~/Pictures/Wallpapers/originals/"],
            mode = "live",
            conflict = "newest",
        ),
        # The rest of state.json is per host. The receiving host waits for the collection to hold
        # the file before it switches; formalshell-greeter-mirror.path (system.star) then copies it
        # to the greeter, since it watches state.json.
        sync(
            "active-wallpaper",
            peers = PAIR,
            keys = json_keys("~/.local/state/formalshell/state.json", ["wallpaper"]),
            mode = "live",
            conflict = "newest",
            after = ["wallpapers"],
            on_receive = PKG_BIN + "/formalshell ipc --any-display call wallpaper set {wallpaper}",
        ),
    ]

# The e1504g syncs a helium-profile folder live through syncthing today; that folder goes when
# Helium moves to seed here. Syncthing itself stays for now.
def _helium():
    return [
        sync(
            "helium",
            peers = PAIR,
            paths = ["~/.config/net.imput.helium/"],
            keyring = [_safe_storage("chromium")],
            mode = "seed",
            # A profile copied while Helium has it open is torn.
            unless_running = ["helium"],
        ),
    ]

def _seeded():
    return [
        # Discord runs from Flathub on Tumbleweed (NixOS kept it in ~/.config/discord).
        sync("discord", peers = PAIR, paths = ["~/.var/app/com.discordapp.Discord/config/discord/"], keyring = [_portal("com.discordapp.Discord")], mode = "seed", unless_running = ["Discord"]),
        sync("steam", peers = PAIR, paths = ["~/.local/share/Steam/config/loginusers.vdf", "~/.local/share/Steam/config/config.vdf"], mode = "seed", unless_running = ["steam"]),
        sync(
            "heroic",
            peers = PAIR,
            paths = ["~/.config/heroic/"],
            keyring = [
                keyring(label = "keyring:credentials@com.epicgames.eglv2.prod"),
                keyring(label = "keyring:v1@com.epicgames.eglv2.dpop"),
            ],
            mode = "seed",
            unless_running = ["heroic"],
        ),
        sync("prismlauncher", peers = PAIR, paths = ["~/.local/share/PrismLauncher/accounts.json", "~/.local/share/ModrinthApp/"], mode = "seed", unless_running = ["prismlauncher", "ModrinthApp"]),
        sync("claude-code", peers = PAIR, paths = ["~/.claude/.credentials.json"], mode = "seed"),
        sync("kopuz", peers = PAIR, paths = ["~/.config/kopuz/"], mode = "seed", unless_running = ["kopuz", "kopuzd"]),
        sync("lynk", peers = PAIR, paths = ["~/.config/lynk/"], mode = "seed", unless_running = ["lynk"]),
    ]

# Plain tokens that do not rotate: both hosts can hold the same one.
def _live_tokens():
    return [
        sync("gh", peers = PAIR, keyring = [keyring(label = "Password for 'FormalSnake' on 'gh:github.com'")], mode = "live", conflict = "newest"),
        # The account token sits in Electron's Local Storage, a LevelDB: it moves only while
        # Obsidian is closed on both ends.
        sync("obsidian-account", peers = PAIR, paths = ["~/.config/obsidian/Local Storage/"], mode = "live", conflict = "newest", unless_running = ["obsidian"]),
        sync("spotify", peers = PAIR, keyring = [_portal("com.spotify.Client")], mode = "live", conflict = "newest"),
        sync("goa-google", peers = PAIR, keyring = [keyring(schema = "org.gnome.OnlineAccounts", attrs = {"goa-identity": "google:*"})], mode = "live", conflict = "newest"),
        sync("remmina", peers = PAIR, keyring = [keyring(schema = "org.remmina.Password")], mode = "live", conflict = "newest"),
    ]

def sync_items():
    return _wallpapers() + _helium() + _seeded() + _live_tokens()
