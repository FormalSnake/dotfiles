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

# What apps or Kyan edit in place: symlinks into the repo, so the edit lands here.
LINKED_DIRS = [
    ".config/sketchybar",
    ".config/lynk-browser",
    ".hammerspoon",
    ".pi/agent/extensions/mcp-bridge",
    ".pi/agent/extensions/mode-cycle",
    ".claude/agents",
    ".claude/commands",
    ".claude/hooks",
]
LINKED_FILES = [
    ".config/karabiner/karabiner.json",
    ".config/omniwm/settings.toml",
    ".pi/agent/settings.json",
    ".pi/agent/keybindings.json",
    ".claude/CLAUDE.md",
    ".claude/AGENTS.md",
    ".claude/CLAUDE-cloudflare.md",
    ".claude/CLAUDE-cloudflare-mini.md",
]

# The second Claude Code profile shares the primary's config and plugins; it signs in separately.
PULSE = ["CLAUDE.md", "AGENTS.md", "settings.json", "agents", "commands", "hooks", "rules", "skills", "plugins"]

# Media and the big caches live on the external SSD; the links dangle while it is unmounted.
DRIVE = "/Volumes/Kyan Drive"
ON_DRIVE = {"Movies": "Movies", ".gradle": "gradle", "Library/Developer/CoreSimulator": "CoreSimulator"}

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
    # an apply from here pulls the locked fspec for an older remote with oras
    "oras",
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

# From third-party taps: (name, tap, cask).
TAPPED = [
    ("omniwm", "barutsrb/tap", True),
    ("tinycast", "abue-ammar/tinycast", True),
    ("markdown-preview", "pluk-inc/tap", True),
    ("sketchybar", "felixkratz/formulae", False),
]

def _brew():
    out = [pkg(n, source = brew()) for n in FORMULAE]
    out += [pkg(n, source = brew(cask = True)) for n in CASKS]
    out += [pkg(n, source = brew(cask = c, tap = t)) for n, t, c in TAPPED]
    return out

# A NativeDesktop app has no release yet: build it at the rev ~/.config/nix's flake.lock pins and
# wrap the binary in the bundle its nix package makes. Cargo.lock pins the NativeDesktop crates.
def _nd_app(name, title, repo, rev, icon):
    plist = "".join([
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
        # nix wrapped both with ffmpeg on PATH; from the Dock PATH has no /opt/homebrew/bin, and
        # LaunchServices applies LSEnvironment to every launch it makes.
        "<key>LSEnvironment</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>",
        "</dict></plist>",
    ])
    app = "$FSPEC_OUT/%s.app/Contents" % title
    return pkg(
        name,
        source = git("https://github.com/" + repo, rev = rev),
        build = ["sh", "-c", " && ".join([
            "set -e",
            "cd \"$FSPEC_SRC\"",
            "cargo build --release --locked --package " + name,
            "mkdir -p \"%s/MacOS\" \"%s/Resources\" \"$FSPEC_OUT/bin\"" % (app, app),
            "printf '%%s' '%s' > \"%s/Info.plist\"" % (plist, app),
            "printf 'APPL????' > \"%s/PkgInfo\"" % app,
            # macOS 26's sips fails (error 13) writing a 1024px PNG straight to icns; iconutil takes an iconset.
            "mkdir -p \"$FSPEC_SRC.iconset\"",
            "for s in 16 32 128 256 512; do sips -z $s $s %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}.png\" > /dev/null; sips -z $((s*2)) $((s*2)) %s --out \"$FSPEC_SRC.iconset/icon_${s}x${s}@2x.png\" > /dev/null; done" % (icon, icon),
            "iconutil -c icns \"$FSPEC_SRC.iconset\" -o \"%s/Resources/AppIcon.icns\"" % app,
            "cp target/release/%s \"%s/MacOS/%s\"" % (name, app, name),
            "ln -s ../%s.app/Contents/MacOS/%s \"$FSPEC_OUT/bin/%s\"" % (title, name, name),
        ])],
        apps = [title + ".app"],
    )

# What no Homebrew formula or cask carries, from upstream releases at the versions nix runs.
def _store():
    return [
        pkg("fut", version = "0.24", source = github("mikker/fut", asset = "fut-macos-arm64.tar.gz")),
        # Upstream releases ship Linux binaries only.
        pkg("tmux-agent-sidebar", source = git("https://github.com/hiroppy/tmux-agent-sidebar", rev = "2cff1cb955363394f8dd9c52d040d027536cfbd8")),
        pkg("t3", version = "0.1.2", source = github("pingdotgg/t3code", asset = "t3-*-darwin-arm64.tar.gz")),
        pkg("pi", version = "1.1.0", source = github("badlogic/pi-mono", asset = "pi-darwin-arm64.tar.gz")),
        pkg("stripe", version = "1.43.2", source = github("stripe/stripe-cli", asset = "stripe_*_mac-os_arm64.tar.gz")),
        pkg("usbfluxd", version = "1.0", source = github("corellium/usbfluxd", asset = "usbfluxd-macho-arm64.tar.gz")),
        # The platform tarball holds the real binary; the main npm package's bin is a stub its
        # postinstall replaces. Claude Code updates itself from there.
        pkg("claude", source = url("https://registry.npmjs.org/@anthropic-ai/claude-code-darwin-arm64/-/claude-code-darwin-arm64-2.1.310.tgz"), mode = "self_managed"),
        pkg("portless", version = "0.15.4", source = npm("portless")),
        # The SDK astro-ls falls back to (init.lua sets vim.g.tsdk from it); 7.x dropped tsserverlibrary.js.
        pkg("typescript", version = "5.9.3", source = npm("typescript")),
        pkg("astro-ls", version = "2.16.10", source = npm("@astrojs/language-server")),
        pkg("docker-compose-langserver", version = "0.2.0", source = npm("@microsoft/compose-language-service")),
        # Source builds at the revisions ~/.config/nix's flake.lock pins; CI builds them on macos-26.
        pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "ca70d10d27e8fc1a0f0afc5c7d691887cb2c4020")),
        pkg("fetch", source = git("https://github.com/areofyl/fetch", rev = "7b19d22c2d8e4b7b2295cc625c9fdf87adcabbcd")),
        pkg("fast", source = git("https://github.com/maaslalani/fast", rev = "26d8fc9c189ba748c68f8930af11dee5c2467f7e", deps = ["go"])),
        pkg(
            "clipssh",
            source = git("https://github.com/samuellawrentz/clipssh", rev = "c7f4e8ddcf102302c6375ba51534c7505ddc2616"),
            build = ["sh", "-c", "mkdir -p $FSPEC_OUT/bin && install -m755 $FSPEC_SRC/clipssh $FSPEC_OUT/bin/clipssh"],
            bins = ["clipssh"],
        ),
        pkg("kopuz", version = "0.22.0", source = github("Kopuz-org/kopuz", asset = "Kopuz_*_aarch64.dmg"), apps = ["Kopuz.app"]),
        _nd_app("messages", "Messages", "FormalStudio/messages", "e9455505f88f101897d001f4a61ab9c82b0232c7", "packaging/linux/dev.formalsnake.messages.png"),
        _nd_app("formalmusic", "FormalMusic", "FormalStudio/formalmusic", "9a9d93af0fbb75594f3e91f087cf77e6c8a7f576", "packaging/icon.png"),
        pkg(
            "kopuzd",
            source = git("https://github.com/Kopuz-org/kopuz", rev = "23db9b35fe45bd773e3cdcdf0d6584b13ae5b8cc"),
            build_flags = ["-p", "kopuz-kopuzd", "-p", "kopuz-ctl"],
            bins = ["kopuzd", "kopuzctl"],
        ),
        # sketchybar's Lua config loads this module through LUA_CPATH.
        pkg(
            "sbarlua",
            source = git("https://github.com/FelixKratz/SbarLua", rev = "dba9cc421b868c918d5c23c408544a28aadf2f2f"),
            build = ["sh", "-c", "cd \"$FSPEC_SRC\" && make install INSTALL_DIR=\"$FSPEC_OUT/lib/lua/5.5\""],
        ),
        # The sudo mesh's PAM module, which no package manager builds for macOS: nixpkgs' recipe
        # and patches, against the system OpenPAM. Modern autoconf picks gnu23, which breaks the
        # K&R code in openbsd-compat, and the SDK's fortify macros collide with its replacements.
        pkg(
            "pam_ssh_agent_auth",
            source = git("https://github.com/jbeverly/pam_ssh_agent_auth", rev = "7ff785809f6ecad45051e333c0ffa72e15ba4f2a"),
            patches = glob(MB + "patches/pam_ssh_agent_auth-*.patch"),
            build = ["sh", "-c", " && ".join([
                "set -e",
                "cd \"$FSPEC_SRC\"",
                "git clone -q https://github.com/floodyberry/ed25519-donna \"$FSPEC_SRC.donna\"",
                "git -C \"$FSPEC_SRC.donna\" checkout -q 8757bd4cd209cb032853ece0ce413f122eef212c",
                "mkdir -p ed25519-donna && cp -R \"$FSPEC_SRC.donna/.\" ed25519-donna/",
                "brew install -q autoconf automake openssl@3",
                "autoreconf -fi",
                "ssl=$(brew --prefix openssl@3)",
                "CFLAGS=\"-std=gnu99 -D_FORTIFY_SOURCE=0\" ./configure --without-openssl-header-check --with-cflags=\"-I$PWD -I$ssl/include\" --with-ldflags=\"-L$ssl/lib\"",
                "make LD=cc",
                "mkdir -p \"$FSPEC_OUT/lib\"",
                "install -m755 pam_ssh_agent_auth.so \"$FSPEC_OUT/lib/pam_ssh_agent_auth.so\"",
            ])],
        ),
    ]

# ---- files ----

def _under(rel, dirs):
    for d in dirs:
        if rel == d or rel.startswith(d + "/"):
            return True
    return False

def _home():
    out = []
    for src in glob(MB + "home/**/*"):
        rel = src.removeprefix(MB + "home/")
        if _under(rel, LINKED_DIRS):
            continue
        out.append(file("~/" + rel, src = src, mode = "link" if rel in LINKED_FILES else "managed"))
    out += [file("~/" + d, src = MB + "home/" + d, mode = "link") for d in LINKED_DIRS]
    out += [file("~/.claude-pulse/" + p, mode = "link", target = "~/.claude/" + p) for p in PULSE]
    out += [file("~/" + p, mode = "link", target = DRIVE + "/" + sub) for p, sub in ON_DRIVE.items()]
    out += [
        file("~/.pi/agent/CLAUDE.md", src = MB + "home/.claude/CLAUDE.md", mode = "link"),
        # claude-code rewrites this on nearly every turn; the second profile only needs the trust
        # flag for the config repo.
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
        # /etc/pam.d/sudo includes sudo_local, so an agent holding a machine key authenticates sudo.
        file("/etc/pam.d/sudo_local", content = "auth       sufficient     /opt/fspec/current/pkgs/pam_ssh_agent_auth/lib/pam_ssh_agent_auth.so file=/etc/ssh/sudo_authorized_keys\n"),
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

# The remote work server has to stay reachable with nobody at it. On 2026-07-23 an unattended
# reboot left it at the login window, asleep within minutes and unreachable.
def _system():
    return [
        setting("pmset", "sleep", 0),
        # Wake on LAN and Bonjour wake-on-demand, for a lid close or a manual sleep.
        setting("pmset", "womp", 1),
        setting("systemsetup", "restartfreeze", True),
        setting("systemsetup", "remotelogin", True),
        # The firewall drops inbound UDP to ad-hoc-signed binaries, which kills mosh, and its allow
        # list stopped taking effect in macOS 26.5.2. Tailscale and the network edge gate inbound.
        setting("firewall", "globalstate", False),
        # An unattended update reboot parks the machine at the FileVault screen.
        defaults("com.apple.SoftwareUpdate", "AutomaticallyInstallMacOSUpdates", False, system = True),
        # Screen Sharing would lock the screen again when a session that unlocked it ends.
        defaults("com.apple.RemoteManagement", "RestoreMachineState", False, system = True),
    ]

# ---- launchd ----

def _logs(name, extra = {}):
    d = {"StandardOutPath": LOGS + "/" + name + ".log", "StandardErrorPath": LOGS + "/" + name + ".log"}
    d.update(extra)
    return d

# Menu-bar apps started hidden at login.
LOGIN_APPS = {
    "omniwm": "OmniWM", "nordvpn": "NordVPN", "tinycast": "Tinycast", "aldente": "AlDente",
    "orbstack": "OrbStack", "betterdisplay": "BetterDisplay",
}

def _poll(name, exec, interval, env = {"PATH": PATH}, extra = {}):
    return service(name, exec = exec, user = True, env = env, launchd = _logs(name, dict({"StartInterval": interval}, **extra)))

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
            exec = STORE + "/portless proxy start --foreground --port 443 --https --skip-trust",
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
            launchd = {"ThrottleInterval": 5, "StandardOutPath": HOME + "/.portless/service.log", "StandardErrorPath": HOME + "/.portless/service.log"},
        ),
        # Puts a phone plugged into a Linux laptop in Xcode here. It renames /var/run/usbmuxd while it
        # runs, so it stays loaded but idle until `usbflux on` kickstarts it.
        service(
            "usbfluxd",
            exec = STORE + "/usbfluxd -f -m -r 100.114.32.78:5000",
            launchd = {"RunAtLoad": False, "KeepAlive": False, "StandardOutPath": "/var/log/usbfluxd.log", "StandardErrorPath": "/var/log/usbfluxd.log"},
        ),
        service(
            "couchdb",
            exec = "/opt/homebrew/opt/couchdb/bin/couchdb",
            user = True,
            restart = "always",
            launchd = {"LimitLoadToSessionType": ["Aqua", "Background", "LoginWindow", "StandardIO", "System"]},
        ),
        service(
            "sketchybar",
            exec = BREW + "/sketchybar",
            user = True,
            restart = "always",
            env = {"PATH": PATH, "LUA_CPATH": "/opt/fspec/current/pkgs/sbarlua/lib/lua/5.5/?.so;;"},
            launchd = {
                "ProcessType": "Interactive",
                "StandardOutPath": HOME + "/.cache/sketchybar/out.log",
                "StandardErrorPath": HOME + "/.cache/sketchybar/err.log",
            },
        ),
        # omniwmctl exits while OmniWM's IPC is down, so it respawns until the socket exists.
        service(
            "omniwm-sketchybar-watch",
            exec = "/Applications/OmniWM.app/Contents/MacOS/omniwmctl watch active-workspace,windows-changed,layout-changed --exec %s/sketchybar --trigger omniwm_update" % BREW,
            user = True,
            restart = "always",
            env = {"PATH": PATH},
            launchd = {"ThrottleInterval": 5},
        ),
        service(
            "t3code",
            exec = STORE + "/t3 serve --host 127.0.0.1 --port 3773 " + HOME + "/Developer",
            user = True,
            restart = "always",
            env = {"PATH": PATH, "SHELL": BREW + "/fish"},
            launchd = _logs("t3code", {"WorkingDirectory": HOME}),
        ),
        # The second Claude account as its own T3 Code provider (home.star has the Linux side).
        file("~/.t3/userdata/settings.json", mode = "patch", owns = {"providerInstances.claude-pulse": {
            "driver": "claudeAgent",
            "displayName": "Claude Pulse",
            "enabled": True,
            "config": {"homePath": HOME + "/.claude-pulse"},
        }}),
        # Keeps ~/Notes current off CouchDB's _changes feed without the Obsidian app open.
        service(
            "obsidian-livesync-daemon",
            exec = "/bin/bash " + HOME + "/.local/bin/obsidian-livesync-daemon.sh",
            user = True,
            restart = "always",
            env = {"PATH": PATH},
            launchd = _logs("obsidian-livesync-daemon", {"ThrottleInterval": 30}),
        ),
        _poll("t3code-serve", BREW + "/tailscale serve --bg --https=8773 http://127.0.0.1:3773", 300, env = {}),
        # tailscale serve run from a dev session replaces the / handler on 443 and every device's
        # LiveSync stops, so this reasserts it.
        _poll("obsidian-livesync-serve", BREW + "/tailscale serve --bg --https=443 http://127.0.0.1:5984", 300, env = {}),
        _poll("obsidian-note-watcher", "/bin/bash " + HOME + "/.local/bin/obsidian-note-watcher.sh", 300),
        # WatchPaths fires on any change in the scan inbox; the interval covers missed events.
        _poll("obsidian-scan-watcher", "/bin/bash " + HOME + "/.local/bin/obsidian-scan-watcher.sh", 600, extra = {
            "WatchPaths": [HOME + "/Notes/_inbox/scans"],
            "ThrottleInterval": 15,
        }),
        _poll("dev-vm-reaper", "/bin/bash " + HOME + "/.local/bin/dev-vm-reaper.sh", 900, env = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": HOME}),
        # Daily: agent worktrees regrow tens of GB of build output between runs. A redirect, so the
        # log holds one run.
        timer(
            "storage-gc",
            exec = "/bin/sh -c '/bin/bash %s/.local/bin/storage-gc.sh --apply --prune-worktrees > %s/storage-gc.log 2>&1'" % (HOME, LOGS),
            schedule = "0 12 * * *",
            user = True,
            env = {"PATH": PATH + ":" + HOME + "/.cargo/bin", "HOME": HOME},
        ),
    ]
    return out

def _all(h):
    return _brew() + _store() + _home() + _rootfs() + _secrets() + _defaults() + _system() + _services()

macbook = host(
    name = "macbook",
    platform = "aarch64-darwin",
    users = [user("kyandesutter", uid = 502, shell = BREW + "/fish")],
    modules = [_all],
)

hosts = [macbook]
