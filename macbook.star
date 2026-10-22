# Kyan's macbook, the dev server the two laptops reach over ssh and mosh, ported from the
# nix-darwin and Home Manager config in ~/.config/nix. Homebrew stays Homebrew; the fspec store
# carries what Homebrew has no formula or cask for. macbook/GAPS.md lists what is not ported.

HOME = "/Users/kyandesutter"
MB = "macbook/"
BREW = "/opt/homebrew/bin"
STORE = "/opt/fspec/current/bin"
SECRETS = "/var/run/fspec/secrets"
LOGS = HOME + "/Library/Logs"
PATH = ":".join([HOME + "/.local/bin", STORE, BREW, "/opt/homebrew/opt/node@24/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"])

# Files that apps or Kyan edit in place: symlinks into the repo, so the edit lands here.
LINKED = [
    "home/.config/karabiner/",
    "home/.config/omniwm/",
    "home/.config/sketchybar/",
    "home/.config/lynk-browser/",
    "home/.hammerspoon/",
    "home/.pi/agent/",
    "home/.claude/CLAUDE",
    "home/.claude/AGENTS.md",
    "home/.claude/agents/",
    "home/.claude/commands/",
    "home/.claude/hooks/",
]

# The second Claude Code profile shares the primary's config.
PULSE = ["CLAUDE.md", "AGENTS.md", "settings.json", "agents/", "commands/", "hooks/", "rules/", "skills/"]

# ---- packages ----

FORMULAE = [
    # shell and terminal
    "fish", "tmux", "mosh", "bat", "btop", "lsd", "fd", "fzf", "ripgrep", "zoxide", "yazi", "fastfetch",
    "direnv", "just", "jq", "wget", "coreutils", "stow", "chafa", "watchman", "terminal-notifier",
    # git and dev
    "git", "git-lfs", "gh", "lazygit", "lazydocker", "neovim", "cmake", "go", "zig", "deno", "bun",
    "node@24", "uv", "python@3.14", "pillow", "lua", "opencode", "herdr", "dipc", "ffmpeg", "imagemagick",
    "cocoapods", "fastlane", "xcbeautify", "mas", "libadwaita",
    # what nvim's config calls: language servers, formatters, parser builds, snacks' PDF previews
    "lua-language-server", "rust-analyzer", "gopls", "marksman", "taplo", "nixfmt", "yaml-language-server",
    "tailwindcss-language-server", "vscode-langservers-extracted", "dockerfile-language-server", "vtsls",
    "tree-sitter-cli", "ghostscript",
    # clipssh reads the clipboard image with pngpaste
    "pngpaste",
    # network, remote iPhone, VPN
    "tailscale", "wireguard-tools", "libimobiledevice", "ideviceinstaller", "openssl@3",
    # Obsidian LiveSync backend on 127.0.0.1:5984
    "couchdb",
]

CASKS = [
    "1password", "1password-cli", "alcove", "aldente", "android-studio", "betterdisplay", "bluebubbles",
    "clop", "discord", "font-sf-pro", "ghostty", "google-chrome", "gstreamer-runtime", "jump-desktop-connect",
    "karabiner-elements", "nordvpn", "orbstack", "parsec", "stats", "syncthing-app", "t3-code",
    "terminal-browser", "thaw", "the-unarchiver", "zulu@21",
]

# Casks and formulae from third-party taps, which Homebrew 6 only installs once the tap is trusted.
TAPPED = [
    ("barutsrb/tap/omniwm", True),
    ("abue-ammar/tinycast/tinycast", True),
    ("pluk-inc/tap/markdown-preview", True),
    ("felixkratz/formulae/sketchybar", False),
]

def _brew():
    out = [pkg(n, source = brew()) for n in FORMULAE]
    out += [pkg(n, source = brew(cask = True)) for n in CASKS]
    out += [pkg(n.split("/")[-1], source = brew(n, cask = c)) for n, c in TAPPED]
    return out

# What no Homebrew formula or cask carries, from upstream releases at the versions nix runs.
def _store():
    return [
        pkg("fut", version = "0.24", source = github("mikker/fut", asset = "fut-macos-arm64.tar.gz")),
        pkg("tmux-agent-sidebar", version = "0.13.0", source = github("hiroppy/tmux-agent-sidebar", asset = "tmux-agent-sidebar-darwin-aarch64")),
        pkg("t3", version = "0.1.0", source = github("pingdotgg/t3code", asset = "t3-*-darwin-arm64.tar.gz")),
        pkg("pi", version = "1.1.0", source = github("badlogic/pi-mono", asset = "pi-darwin-arm64.tar.gz")),
        pkg("stripe", version = "1.43.2", source = github("stripe/stripe-cli", asset = "stripe_*_mac-os_arm64.tar.gz")),
        pkg("usbfluxd", version = "1.0", source = github("corellium/usbfluxd", asset = "usbfluxd-macho-arm64.tar.gz")),
        # The platform tarball holds the real binary; the main npm package's bin is a stub its
        # postinstall replaces. Claude Code updates itself from there.
        pkg("claude", source = url("https://registry.npmjs.org/@anthropic-ai/claude-code-darwin-arm64/-/claude-code-darwin-arm64-2.1.289.tgz"), mode = "self_managed"),
        pkg("portless", version = "0.15.4", source = npm("portless")),
        # The SDK astro-ls falls back to (init.lua sets vim.g.tsdk from it); 7.x dropped tsserverlibrary.js.
        pkg("typescript", version = "5.9.3", source = npm("typescript")),
        pkg("astro-ls", version = "2.16.10", source = npm("@astrojs/language-server")),
        pkg("docker-compose-langserver", version = "0.2.0", source = npm("@microsoft/compose-language-service")),
        # Source builds at the revisions ~/.config/nix's flake.lock pins; CI builds them on macos-14.
        pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "ca70d10d27e8fc1a0f0afc5c7d691887cb2c4020")),
        pkg("fetch", source = git("https://github.com/areofyl/fetch", rev = "7b19d22c2d8e4b7b2295cc625c9fdf87adcabbcd")),
        pkg("fast", source = git("https://github.com/maaslalani/fast", rev = "26d8fc9c189ba748c68f8930af11dee5c2467f7e")),
        pkg(
            "clipssh",
            source = git("https://github.com/samuellawrentz/clipssh", rev = "c7f4e8ddcf102302c6375ba51534c7505ddc2616"),
            build = ["sh", "-c", "install -Dm755 $FSPEC_SRC/clipssh $FSPEC_OUT/bin/clipssh"],
            bins = ["clipssh"],
        ),
        pkg(
            "kopuzd",
            source = git("https://github.com/Kopuz-org/kopuz", rev = "23db9b35fe45bd773e3cdcdf0d6584b13ae5b8cc"),
            build_flags = ["-p", "kopuz-kopuzd", "-p", "kopuz-ctl"],
            bins = ["kopuzd", "kopuzctl"],
        ),
        # sketchybar's Lua config loads this module (GAPS.md: no stable path to it yet).
        pkg(
            "sbarlua",
            source = git("https://github.com/FelixKratz/SbarLua", rev = "dba9cc421b868c918d5c23c408544a28aadf2f2f"),
            build = ["sh", "-c", "cd \"$FSPEC_SRC\" && make install INSTALL_DIR=\"$FSPEC_OUT/lib/lua/5.5\""],
        ),
    ]

# ---- files ----

def _linked(src):
    for d in LINKED:
        if src.startswith(d):
            return True
    return False

def _home():
    out = []
    for src in glob(MB + "home/**/*"):
        rel = src.removeprefix(MB)
        out.append(file("~/" + rel.removeprefix("home/"), src = src, mode = "link" if _linked(rel) else "managed"))
    for src in glob(MB + "home/.claude/**/*"):
        rel = src.removeprefix(MB + "home/.claude/")
        for p in PULSE:
            if rel == p or (p.endswith("/") and rel.startswith(p)):
                out.append(file("~/.claude-pulse/" + rel, src = src))
    out += [
        file("~/.pi/agent/CLAUDE.md", src = MB + "home/.claude/CLAUDE.md", mode = "link"),
        # claude-code rewrites this on nearly every turn; the second profile only needs the trust
        # flag for the config repo, and it signs in separately.
        file(
            "~/.claude-pulse/.claude.json",
            mode = "seed",
            perms = "0600",
            content = '{"mcpServers": {}, "projects": {"' + HOME + '/.config/nix": {"hasTrustDialogAccepted": true}}}\n',
        ),
    ]
    return out

def _rootfs():
    def f(path, perms = None):
        return file("/" + path, src = MB + "rootfs/" + path, perms = perms)
    return [
        f("etc/ssh/sshd_config.d/100-fspec.conf"),
        f("etc/ssh/authorized_keys.d/kyandesutter", perms = "0644"),
        # pam_ssh_agent_auth's key list; not the builder key, which would get passwordless sudo.
        f("etc/ssh/sudo_authorized_keys", perms = "0444"),
        f("etc/sudoers.d/10-fspec", perms = "0440"),
        f("Library/Fonts/MEK-Mono.otf"),
        f("Library/Fonts/MEKSans-Regular.otf"),
        f("Library/Fonts/GROUT-Display.otf"),
    ]

# agenix's secrets, the same .age files, decrypted with agenix's identity on this host.
SECRET_NAMES = ["openai", "anthropic", "gemini", "deepseek", "nucleo-license", "npm-github-token",
                "npm-registry-token", "wstunnel-path-prefix", "wstunnel-endpoint", "couchdb-admin",
                "lastfm-api-key"]

def _secrets():
    ids = ["~/.config/age/keys.txt"]
    out = [
        secret(SECRETS + "/" + n, src = "secrets/%s.age" % n, owner = "kyandesutter:staff", identities = ids)
        for n in SECRET_NAMES
    ]
    out.append(secret(SECRETS + "/livesync-passphrase", src = MB + "secrets/livesync-passphrase.age", owner = "kyandesutter:staff", identities = ids))
    # /var/run is emptied at boot.
    out.append(service("secrets", exec = "/usr/local/bin/fspec secret install"))
    return out

# ---- macOS defaults ----

def _dock_tile(app):
    return {"tile-data": {"file-data": {"_CFURLString": app, "_CFURLStringType": 0}}}

DEFAULTS = {
    "NSGlobalDomain": {
        "AppleInterfaceStyle": "Dark",
        "AppleShowAllExtensions": True,
        # sketchybar owns the top edge.
        "_HIHideMenuBar": True,
        "KeyRepeat": 2,
        "ApplePressAndHoldEnabled": False,
        "NSAutomaticSpellingCorrectionEnabled": False,
        "NSAutomaticCapitalizationEnabled": False,
        "NSAutomaticDashSubstitutionEnabled": False,
        "NSAutomaticPeriodSubstitutionEnabled": True,
        "NSAutomaticQuoteSubstitutionEnabled": False,
        "NSNavPanelExpandedStateForSaveMode": True,
        "com.apple.trackpad.scaling": 0.6875,
        "com.apple.swipescrolldirection": True,
        "com.apple.mouse.scaling": 1.5,
    },
    "com.apple.dock": {
        "autohide": True,
        "orientation": "bottom",
        "tilesize": 48,
        "magnification": True,
        "largesize": 57,
        "minimize-to-application": True,
        "persistent-apps": [_dock_tile(a) for a in [
            "/Applications/LaunchOS.app",
            "/Applications/Helium.app",
            "/Applications/Ghostty.app",
            "/Applications/OrbStack.app",
            "/System/Applications/Calendar.app",
            "/System/Applications/Messages.app",
        ]],
    },
    "com.apple.finder": {
        "AppleShowAllFiles": True,
        "ShowPathbar": True,
        "ShowStatusBar": True,
        "FXPreferredViewStyle": "clmv",
        "FXDefaultSearchScope": "SCcf",
    },
    "com.apple.screencapture": {
        "location": "~/Pictures/screenshots",
        "type": "png",
        "disable-shadow": True,
        "show-thumbnail": True,
        "style": "window",
        "showsClicks": True,
    },
    # The machine is reached over ssh and VNC; a password gate or a screen saver only gets in the way.
    "com.apple.screensaver": {"askForPassword": False, "idleTime": 0},
    "com.apple.AppleMultitouchTrackpad": {"TrackpadThreeFingerDrag": False},
    "com.apple.driver.AppleBluetoothMultitouch.trackpad": {"TrackpadThreeFingerDrag": False},
    "com.apple.WindowManager": {"GloballyEnabled": False},
    # On the external SSD; Xcode recreates the directory itself.
    "com.apple.dt.Xcode": {"IDECustomDerivedDataLocation": "/Volumes/Kyan Drive/DerivedData"},
}

def _defaults():
    return [defaults(d, k, v) for d, keys in DEFAULTS.items() for k, v in keys.items()]

# ---- launchd ----

def _logged(cmd, log):
    return "/bin/sh -c 'mkdir -p %s && exec %s >> %s 2>&1'" % (LOGS, cmd, LOGS + "/" + log)

# Menu-bar apps started hidden at login.
LOGIN_APPS = {
    "omniwm": "OmniWM", "nordvpn": "NordVPN", "tinycast": "Tinycast", "aldente": "AlDente",
    "orbstack": "OrbStack", "betterdisplay": "BetterDisplay",
}

def _services():
    out = [
        service("login-" + k, exec = "/usr/bin/open -g -j -a /Applications/%s.app" % v, user = True)
        for k, v in LOGIN_APPS.items()
    ]
    out += [
        # The remote work server must stay awake from boot, before anyone logs in.
        service("caffeinate", exec = "/usr/bin/caffeinate -i -s", restart = "always"),
        service("tailscaled", exec = BREW + "/tailscaled", restart = "always"),
        # Root binds 127.0.0.1:443 next to tailscale serve's *:443; state stays in the user's home.
        service(
            "portless-proxy",
            exec = _logged(STORE + "/portless proxy start --foreground --port 443 --https --skip-trust", "portless-proxy.log"),
            restart = "always",
            env = {
                "HOME": HOME,
                "SUDO_USER": "kyandesutter",
                "SUDO_UID": "502",
                "SUDO_GID": "20",
                "PORTLESS_STATE_DIR": HOME + "/.portless",
                "PORTLESS_PORT": "443",
                "PORTLESS_HTTPS": "1",
                "PORTLESS_LAN": "0",
                "PORTLESS_WILDCARD": "0",
                "PATH": "/opt/homebrew/opt/openssl@3/bin:/opt/homebrew/opt/node@24/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            },
        ),
        service("couchdb", exec = "/opt/homebrew/opt/couchdb/bin/couchdb", user = True, restart = "always"),
        service(
            "sketchybar",
            exec = "/bin/sh -c 'mkdir -p %s/.cache/sketchybar && exec %s/sketchybar >> %s/.cache/sketchybar/out.log 2>> %s/.cache/sketchybar/err.log'" % (HOME, BREW, HOME, HOME),
            user = True,
            restart = "always",
            env = {"PATH": PATH},
        ),
        # omniwmctl exits while OmniWM's IPC is down, so it respawns until the socket exists.
        service(
            "omniwm-sketchybar-watch",
            exec = "/Applications/OmniWM.app/Contents/MacOS/omniwmctl watch active-workspace,windows-changed,layout-changed --exec %s/sketchybar --trigger omniwm_update" % BREW,
            user = True,
            restart = "always",
            env = {"PATH": PATH},
        ),
        service(
            "t3code",
            exec = _logged(STORE + "/t3 serve --host 127.0.0.1 --port 3773 " + HOME + "/Developer", "t3code.log"),
            user = True,
            restart = "always",
            env = {"PATH": PATH, "SHELL": BREW + "/fish"},
        ),
        service(
            "obsidian-livesync-daemon",
            exec = _logged("/bin/bash " + HOME + "/.local/bin/obsidian-livesync-daemon.sh", "obsidian-livesync-daemon.log"),
            user = True,
            restart = "always",
            env = {"PATH": PATH},
        ),
    ]
    # launchd StartInterval jobs, as calendar timers until fspec has a launchd interval.
    out += [
        timer("t3code-serve", exec = _logged(BREW + "/tailscale serve --bg --https=8773 http://127.0.0.1:3773", "t3code-serve.log"), schedule = "*/5 * * * *", user = True),
        # tailscale serve run from a dev session replaces the / handler on 443 and every device's
        # LiveSync stops, so this reasserts it.
        timer("obsidian-livesync-serve", exec = _logged(BREW + "/tailscale serve --bg --https=443 http://127.0.0.1:5984", "obsidian-livesync-serve.log"), schedule = "*/5 * * * *", user = True),
        timer("obsidian-note-watcher", exec = _logged("env PATH=%s /bin/bash %s/.local/bin/obsidian-note-watcher.sh" % (PATH, HOME), "obsidian-note-watcher.log"), schedule = "*/5 * * * *", user = True),
        timer("obsidian-scan-watcher", exec = _logged("env PATH=%s /bin/bash %s/.local/bin/obsidian-scan-watcher.sh" % (PATH, HOME), "obsidian-scan-watcher.log"), schedule = "*/10 * * * *", user = True),
        timer("dev-vm-reaper", exec = _logged("env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash %s/.local/bin/dev-vm-reaper.sh" % HOME, "dev-vm-reaper.log"), schedule = "*/15 * * * *", user = True),
        # Two hours after the Saturday update window, daily: agent worktrees regrow fast.
        timer("storage-gc", exec = "/bin/sh -c 'mkdir -p %s && env PATH=%s:%s/.cargo/bin /bin/bash %s/.local/bin/storage-gc.sh --apply --prune-worktrees > %s/storage-gc.log 2>&1'" % (LOGS, PATH, HOME, HOME, LOGS), schedule = "0 12 * * *", user = True),
    ]
    return out

def _all(h):
    return _brew() + _store() + _home() + _rootfs() + _secrets() + _defaults() + _services()

macbook = host(
    name = "macbook",
    platform = "aarch64-darwin",
    users = [user("kyandesutter", uid = 502, shell = BREW + "/fish")],
    modules = [_all],
)

hosts = [macbook]
