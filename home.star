# Kyan's user layer on the Linux hosts' Tumbleweed roots, ported from the Home Manager generation in
# ~/.config/nix (users/kyandesutter). home/ mirrors ~ with every /nix/store path rewritten, and
# <host>/home/ holds the files that differ per host (monitors, logos, GPU env), which win over
# home/; GAPS.md lists what is not ported.

HOME = "/home/kyandesutter"
BIN = HOME + "/.local/bin"
# Where fspec links the executables of the pkg() resources below.
PKG_BIN = "/opt/fspec/current/bin"

# Files outside these keep the mode they have in the repo.
EXECUTABLE_DIRS = ["home/.local/bin/", "home/.claude/hooks/", "home/.claude-pulse/hooks/"]


# git() builds that link system libraries run in the target's own distro, so the sonames match;
# rustup follows the rust-toolchain.toml pins.
TUMBLEWEED = "registry.opensuse.org/opensuse/tumbleweed"
NATIVEDESKTOP_DEPS = ["gcc", "gcc-c++", "make", "pkgconf", "git-core", "curl", "tar", "xz", "fontconfig-devel", "freetype2-devel", "libxkbcommon-devel", "libxkbcommon-x11-devel", "wayland-devel", "vulkan-devel", "libX11-devel", "alsa-devel", "dbus-1-devel", "libopenssl-devel"]

def _files(h):
    files = {}
    for root in ["home/", h.name + "/home/"]:
        for src in glob(root + "**/*"):
            rel = src.removeprefix(root)
            perms = None
            for d in EXECUTABLE_DIRS:
                if ("home/" + rel).startswith(d):
                    perms = "0755"
            files[rel] = file("~/" + rel, src = src, perms = perms)
    return files.values()

def _merge(a, b):
    out = dict(a)
    out.update(b)
    return out

# A graphical-session user service, the shape Home Manager's autostart units had.
def _gui(name, exec, description, restart = "no", hyprland_only = False, needs = None, unit = {}, extra = {}, env = {}):
    # graphical-session.target can be up without the compositor's environment (a bare Hyprland
    # session); Restart= then loops the app every RestartSec, so it skips instead.
    u = {"After": "graphical-session.target", "PartOf": "graphical-session.target", "ConditionEnvironment": ["WAYLAND_DISPLAY"]}
    if hyprland_only:
        u["ConditionEnvironment"] = ["WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP=Hyprland"]
    if needs:
        # Apps from vendor repos or the fspec store skip cleanly until they are there.
        u["ConditionPathExists"] = needs
    systemd = _merge({"unit": _merge(u, unit), "install": {"WantedBy": "graphical-session.target"}}, extra)
    return service(name, exec = exec, user = True, restart = restart, description = description, env = env, systemd = systemd)

# Launched once per session; systemd starts it with the session and refuses manual restarts,
# so closing the window does not respawn it.
def _autostart(name, exec, description, unit = {}, **kw):
    return _gui(name, exec, description, unit = _merge({"RefuseManualStart": True, "RefuseManualStop": True}, unit), **kw)

def _services():
    return [
        # Units `formalshell install` writes under their own names (home/.config/systemd/user),
        # since formalshell-watchdog and the shell's IPC restart formalshell.service by name.
        service("formalshell.service", user = True),
        service("formalshell-watchdog.timer", user = True),
        _autostart("discord", BIN + "/discord --start-minimized", "Discord (minimized to tray)", hyprland_only = True),
        _autostart("beeper", PKG_BIN + "/beeper", "Beeper", needs = PKG_BIN + "/beeper"),
        _autostart("flare", "/usr/bin/flatpak run de.schmidhuberj.Flare", "Flare (Signal)"),
        _autostart("messages", PKG_BIN + "/messages", "Messages", needs = PKG_BIN + "/messages"),
        _gui("1password", "/usr/bin/1password --silent", "1Password (tray)", restart = "on_failure", needs = "/usr/bin/1password", extra = {"RestartSec": 2}),
        _gui("wl-clip-persist", PKG_BIN + "/wl-clip-persist --clipboard regular", "wl-clip-persist (keep regular clipboard alive)", hyprland_only = True, needs = PKG_BIN + "/wl-clip-persist"),
        _gui(
            "helium",
            PKG_BIN + "/helium",
            "Helium (Chromium): waits for FormalShell's notification daemon",
            needs = PKG_BIN + "/helium",
            unit = {"After": ["formalshell.service", "graphical-session.target"], "Wants": "formalshell.service"},
            extra = {"ExecStartPre": "/usr/bin/bash -c 'for i in $(seq 50); do busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications 2>/dev/null | grep -q true && break; sleep 0.2; done'"},
        ),
        _gui(
            "librepods",
            PKG_BIN + "/librepods --headless",
            "librepods AirPods daemon (omarchy-pods build, headless)",
            restart = "on_failure",
            env = {"QT_LOGGING_RULES": "openpods.debug=false"},
            extra = {"RestartSec": 5},
        ),
        _gui(
            "macbook-mount",
            "/usr/bin/sshfs -f -o reconnect -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o idmap=user macbook: " + HOME + "/.macbook",
            "SSHFS mount of the macbook's home at ~/.macbook",
            restart = "on_failure",
            unit = {"After": ["graphical-session.target", "fspec-1password.service"], "Wants": "fspec-1password.service", "StartLimitIntervalSec": 0},
            extra = {
                "RestartSec": 30,
                "ExecStartPre": ["-/usr/bin/fusermount3 -uz " + HOME + "/.macbook", "/usr/bin/mkdir -p " + HOME + "/.macbook"],
                "ExecStopPost": "-/usr/bin/fusermount3 -uz " + HOME + "/.macbook",
            },
        ),
        _gui(
            "dualsense-sync",
            "/usr/bin/dualsensectl monitor add " + BIN + "/dualsense-settle",
            "Paint the DualSense lightbar and player LEDs on hotplug",
            restart = "always",
            needs = "/usr/bin/dualsensectl",
            extra = {"RestartSec": 5},
        ),
        _gui("dualsense-herdr", BIN + "/dualsense-herdr", "Mirror herdr agent state onto the DualSense lightbar", restart = "always", extra = {"RestartSec": 30}),
        _gui("dualsense-pad", BIN + "/dualsense-pad", "DualSense D-pad as a window and workspace remote", restart = "always", extra = {"RestartSec": 5}),
        timer("dualsense-battery", exec = BIN + "/dualsense-sync", schedule = "*/2 * * * *", user = True),
        _gui("streamdeck-keys", BIN + "/streamdeck-keys", "Stream Deck keys for Herdr agents, system and Discord controls", restart = "always", extra = {"RestartSec": 5}),
        _gui(
            "swayidle",
            "/usr/bin/swayidle -w timeout 900 " + BIN + "/idle-lock",
            "Idle manager for Wayland",
            restart = "always",
            unit = {"ConditionEnvironment": "WAYLAND_DISPLAY"},
            # Without a delay it burns its start limit while the compositor goes away at logout,
            # and the next login cannot start it for those ten seconds.
            extra = {"RestartSec": 2},
        ),
        _gui(
            "panel-gamma",
            PKG_BIN + "/wl-gammarelay-rs run",
            "Punchier panel gamma via wl-gammarelay-rs",
            restart = "on_failure",
            hyprland_only = True,
            needs = PKG_BIN + "/wl-gammarelay-rs",
            extra = {
                "Type": "dbus",
                "BusName": "rs.wl-gammarelay",
                "RestartSec": 2,
                "ExecStartPost": "/usr/bin/busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Gamma d 1.1",
            },
        ),
        _gui("power-saver-dim", BIN + "/power-saver-dim", "Dim backlight while the power-saver profile is active", restart = "always", extra = {"RestartSec": 2}),
        service(
            "gtk-session-css",
            exec = BIN + "/gtk-session-css",
            user = True,
            description = "Point GTK's session.css at the Hyprland theme",
            systemd = {
                "Type": "oneshot",
                "unit": {"Before": "wayland-session-pre@hyprland.desktop.target"},
                "install": {"WantedBy": "wayland-session-pre@hyprland.desktop.target"},
            },
        ),
        _gui(
            "nordvpn-tray-off",
            BIN + "/nordvpn-tray-off",
            "Disable the NordVPN tray icon (upstream double-registers it)",
            needs = "/usr/bin/nordvpn",
            extra = {"Type": "oneshot", "RemainAfterExit": True},
        ),
        _gui(
            "easyeffects",
            "/usr/bin/easyeffects --hide-window --service-mode",
            "Easyeffects daemon",
            restart = "on_failure",
            unit = {"After": ["graphical-session.target", "pipewire.service"], "PartOf": ["graphical-session.target", "pipewire.service"], "Wants": "pipewire.service"},
            extra = {"RestartSec": 5, "ExecStop": "/usr/bin/easyeffects --quit", "KillMode": "mixed", "TimeoutStopSec": 10},
        ),
        _gui(
            "ee-preset-sync",
            BIN + "/ee-preset-sync",
            "Sync EasyEffects output preset to the default sink",
            restart = "on_failure",
            unit = {"After": ["pipewire.service", "fspec-easyeffects.service"], "BindsTo": "fspec-easyeffects.service"},
            extra = {"RestartSec": 2, "install": {"WantedBy": "fspec-easyeffects.service"}},
        ),
        # Home Manager generated these from man pages on every switch; fish makes them once on its
        # first interactive start and this keeps them current after package updates.
        timer("fish-completions", exec = "/usr/bin/fish -c fish_update_completions", schedule = "0 4 * * 0", user = True),
        # Home Manager ran this as the file's onChange hook.
        service(
            "xrdb-merge",
            exec = "/usr/bin/xrdb -merge " + HOME + "/.Xresources",
            user = True,
            description = "Merge ~/.Xresources into the Xwayland resource database",
            systemd = {
                "Type": "oneshot",
                "RemainAfterExit": True,
                "unit": {"After": "graphical-session.target", "PartOf": "graphical-session.target", "ConditionEnvironment": "DISPLAY"},
                "install": {"WantedBy": "graphical-session.target"},
            },
        ),
        # Home Manager loaded these keys with `dconf load /` on every switch.
        service(
            "dconf-load",
            exec = "/usr/bin/sh -c 'dconf load / < " + HOME + "/.config/fspec/dconf.ini'",
            user = True,
            description = "Load the GNOME interface keys from ~/.config/fspec/dconf.ini",
            systemd = {"Type": "oneshot", "RemainAfterExit": True},
        ),
        # mixins/hardware/audio.nix.
        service(
            "audio-autoswitch",
            exec = BIN + "/audio-autoswitch",
            user = True,
            restart = "always",
            description = "Switch default output to newly-connected audio devices",
            systemd = {"RestartSec": 3, "unit": {"After": "wireplumber.service"}, "install": {"WantedBy": "pipewire.service"}},
        ),
    ]

# mixins/desktop/kde.nix: the Plasma session's user side. kwin-outputs is per host (<host>/home).
def _kde():
    kde = {"ConditionEnvironment": "XDG_CURRENT_DESKTOP=KDE", "PartOf": "graphical-session.target"}
    return [
        # Home Manager ran these kwriteconfig6 calls on every switch: no Baloo indexing, no edge or
        # corner barriers between outputs.
        service(
            "kde-config",
            exec = "/usr/bin/sh -c 'kwriteconfig6 --file baloofilerc --group \"Basic Settings\" --key Indexing-Enabled false && kwriteconfig6 --file kwinrc --group EdgeBarrier --key EdgeBarrier 0 && kwriteconfig6 --file kwinrc --group EdgeBarrier --key CornerBarrier --type bool false'",
            user = True,
            description = "Plasma's Baloo and edge barrier keys",
            systemd = {"Type": "oneshot", "RemainAfterExit": True},
        ),
        service(
            "kwin-outputs",
            exec = BIN + "/kwin-outputs",
            user = True,
            description = "Match the KWin output layout and scale to Hyprland",
            systemd = {"Type": "oneshot", "unit": _merge(kde, {"After": "plasma-kwin_wayland.service"}), "install": {"WantedBy": "graphical-session.target"}},
        ),
        service(
            "steamed-theme",
            exec = "/usr/bin/sh -c '[ \"$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)\" = Steamed ] || { plasma-apply-lookandfeel --apply Steamed && plasma-apply-wallpaperimage /usr/local/share/wallpapers/steam-classic.png; }'",
            user = True,
            description = "Apply the Steamed theme and wallpaper once",
            systemd = {"Type": "oneshot", "unit": _merge(kde, {"After": "plasma-plasmashell.service"}), "install": {"WantedBy": "graphical-session.target"}},
        ),
        # A Plasma logout otherwise leaves graphical-session.target up, and the Hyprland session
        # after it starts with the Plasma one's units.
        service(
            "plasma-end-graphical-session",
            exec = "/usr/bin/true",
            user = True,
            description = "Stop graphical-session.target when the Plasma workspace stops",
            systemd = {
                "Type": "oneshot",
                "RemainAfterExit": True,
                "ExecStop": "/usr/bin/systemctl --user --no-block --job-mode=replace-irreversibly stop graphical-session.target",
                "unit": {"PartOf": "plasma-workspace.target"},
                "install": {"WantedBy": "plasma-workspace.target"},
            },
        ),
        _autostart("discord-kde", BIN + "/discord", "Discord", unit = {"ConditionEnvironment": ["WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP=KDE"]}),
        file("~/Desktop/switch-to-hyprland.desktop", perms = "0755", content = "[Desktop Entry]\nType=Application\nName=Switch to Hyprland\nExec=/usr/local/bin/session-switch hyprland-uwsm\nIcon=hyprland\n"),
    ]

def _flatpaks():
    return [
        pkg("flare", source = flatpak("de.schmidhuberj.Flare")),
        pkg("obsidian", source = flatpak("md.obsidian.Obsidian")),
        pkg("parsec", source = flatpak("com.parsecgaming.parsec")),
        pkg("apostrophe", source = flatpak("org.gnome.gitlab.somas.Apostrophe")),
    ]

# nixpkgs' Discord with moonlight (pkgs/by-name/di/discord, withMoonlight): Discord's own distro,
# a brotli tar with the app under files/ beside a delta manifest, one more per module, and
# moonlight's release dist. The patch moves app.asar aside for moonlight's injector.
DISCORD_VERSION = "1.0.160"
DISCORD_DISTRO = "https://stable.dl2.discordapp.net/distro/app/stable/linux/x64/" + DISCORD_VERSION
DISCORD_MODULES = {
    "discord_cloudsync": 1, "discord_desktop_core": 2, "discord_dispatch": 1, "discord_erlpack": 1,
    "discord_game_utils": 1, "discord_krisp": 1, "discord_modules": 1, "discord_rpc": 1,
    "discord_spellcheck": 1, "discord_sysimg": 1, "discord_utils": 1, "discord_voice": 1, "discord_zstd": 1,
}
DISCORD = "/opt/fspec/current/pkgs/discord"

# nixpkgs' stageModules and disable-breaking-updates: Discord loads its modules from the config
# dir and would update itself into the read-only store, so the modules are links there and the
# host update is skipped.
DISCORD_LAUNCHER = """#!/bin/sh
conf="${XDG_CONFIG_HOME:-$HOME/.config}/discord"
mods="$conf/%s/modules"
rm -rf "$mods"
mkdir -p "$mods"
for m in %s/modules/*; do
	ln -sn "$m/files" "$mods/${m##*/}"
done
printf '%%s' '%s' >"$mods/installed.json"
python3 - "$conf/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        settings = json.load(f)
except (OSError, ValueError):
    settings = {}
settings["SKIP_HOST_UPDATE"] = True
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
PY
exec %s/files/Discord ${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true} "$@"
""" % (
    DISCORD_VERSION,
    DISCORD,
    "{" + ",".join(['"%s":{"installedVersion":%d}' % (m, v) for m, v in DISCORD_MODULES.items()]) + "}",
    DISCORD,
)

def _discord():
    return [
        pkg(
            "discord",
            source = url(DISCORD_DISTRO + "/full.distro"),
            parts = dict(
                {"modules/%s" % m: url("%s/%s/%d/full.distro" % (DISCORD_DISTRO, m, v)) for m, v in DISCORD_MODULES.items()},
                moonlight = url("https://github.com/moonlight-mod/moonlight/releases/download/v2026.10.0/dist.tar.gz"),
            ),
            patches = ["patches/discord-moonlight.patch"],
            links = {"discord-app": "Discord"},
        ),
        file("~/.local/bin/discord", perms = "0755", content = DISCORD_LAUNCHER),
        file("~/.local/share/applications/discord.desktop", content = """[Desktop Entry]
Type=Application
Name=Discord
GenericName=Instant Messenger
Exec=""" + BIN + """/discord
Icon=""" + DISCORD + """/files/discord.png
Categories=Network;InstantMessaging;
MimeType=x-scheme-handler/discord;
StartupWMClass=discord
"""),
        # matugen rewrites it on every re-theme; moonlight-css drops a path it cannot stat at load.
        file("~/.config/moonlight-mod/matugen.css", mode = "seed", content = ""),
        # The Last.fm key is a secret, so stable.json is rendered at login rather than shipped.
        service(
            "moonlight-config",
            exec = BIN + "/moonlight-config",
            user = True,
            description = "Render moonlight's stable.json with the Last.fm key",
            systemd = {"Type": "oneshot", "RemainAfterExit": True},
        ),
    ]

# The second Claude Code profile; its .claude.json only gets the keys the primary had when seeded,
# since fspec's patch keys split on dots and the trusted project path has one.
def _claude_pulse():
    return [
        file(
            "~/.claude-pulse/.claude.json",
            mode = "seed",
            perms = "0600",
            content = '{"mcpServers": {}, "projects": {"/home/kyandesutter/.config/nix": {"hasTrustDialogAccepted": true}}}\n',
        ),
    ]

# T3 Code: the server runs on the g815 only. The desktop app always starts its own backend and
# refuses a data directory the server owns, so it gets ~/.t3-desktop and reaches every server, this
# host's included, over ssh. It reads saved-environments.json once, to migrate it into its encrypted
# connection catalog; the ids are each server's ~/.t3/userdata/environment-id.
T3_SERVERS = {
    "macbook": {"alias": "macbook-t3", "id": "5c911926-9553-4e77-afea-49eacc89b011"},
    "g815": {"alias": "g815", "id": "d0c1975c-343f-40d3-8370-2689724f8040"},
}

# The second Claude account as its own provider, so the model picker switches between the logins.
T3_PULSE = {"driver": "claudeAgent", "displayName": "Claude Pulse", "enabled": True, "config": {"homePath": HOME + "/.claude-pulse"}}

def _t3code(h):
    out = [
        file("~/.t3-desktop/userdata/settings.json", mode = "patch", owns = {"providerInstances.claude-pulse": T3_PULSE}),
        file("~/.t3-desktop/userdata/saved-environments.json", mode = "seed", perms = "0600", content = {
            "version": 1,
            "records": [
                {
                    "environmentId": s["id"],
                    "label": name,
                    "httpBaseUrl": "http://127.0.0.1:3773",
                    "wsBaseUrl": "ws://127.0.0.1:3773",
                    "createdAt": "2026-10-25T00:00:00.000Z",
                    "lastConnectedAt": None,
                    "desktopSsh": {"alias": s["alias"], "hostname": s["alias"], "username": None, "port": None},
                }
                for name, s in T3_SERVERS.items()
            ],
        }),
    ]
    if h.name in T3_SERVERS:
        out += [
            file("~/.t3/userdata/settings.json", mode = "patch", owns = {"providerInstances.claude-pulse": T3_PULSE}),
            service(
                "t3code",
                exec = PKG_BIN + "/t3 serve --host 127.0.0.1 --port 3773 " + HOME + "/Developer",
                user = True,
                restart = "always",
                after = ["network"],
                description = "T3 Code server",
                env = {"PATH": BIN + ":" + PKG_BIN + ":" + HOME + "/.bun/bin:/usr/bin:/bin", "SHELL": "/usr/bin/fish"},
                systemd = {"RestartSec": 5, "WorkingDirectory": HOME, "unit": {"ConditionPathExists": PKG_BIN + "/t3"}},
            ),
            timer("t3code-serve", exec = "/usr/bin/tailscale serve --bg --https=8773 http://127.0.0.1:3773", schedule = "*/5 * * * *", user = True),
        ]
    return out

def _tools():
    return [
        # The plugin's .tmux script falls back to tmux-agent-sidebar on PATH when its bin/ is empty.
        pkg("t3", version = "0.1.0", source = github("pingdotgg/t3code", asset = "t3-*-linux-x64.tar.gz")),
        pkg("t3code-desktop", version = "0.1.0", source = github("pingdotgg/t3code", asset = "T3-Code-*-x86_64.AppImage")),
        # Cargo.toml points at a NativeDesktop checkout beside the repo; the rev is the one its flake locks.
        # rust-toolchain.toml picks the compiler, so the build runs from the checkout.
        pkg(
            "messages",
            source = git("https://github.com/FormalStudio/messages", rev = "8df17ef38312e240f89428e98f85ef55e95b9c95", image = TUMBLEWEED, deps = ["rustup"] + NATIVEDESKTOP_DEPS),
            build = ["sh", "-c", "set -e; nd=\"$FSPEC_SRC/../nativedesktop-wt-msg-linux\"; git init -q \"$nd\"; git -C \"$nd\" fetch -q --depth 1 https://github.com/FormalStudio/NativeDesktop 7ad936d8bcf2ef7c7d026798cb63044b9c088b71; git -C \"$nd\" checkout -q FETCH_HEAD; cd \"$FSPEC_SRC\"; cargo build --release --locked -p messages; install -Dm755 target/release/messages \"$FSPEC_OUT/bin/messages\""],
        ),
        pkg("tmux-agent-sidebar", version = "0.13.0", source = github("hiroppy/tmux-agent-sidebar", asset = "tmux-agent-sidebar-linux-*")),
    ]

# The language servers and formatters the NixOS neovim wrapper put on PATH that Tumbleweed lacks.
# taplo, gopls, lua-language-server, tree-sitter and typescript are Tumbleweed packages; nil is a
# source build in system.star.
def _nvim():
    return [
        pkg("rust-analyzer", version = "2026-09-28", source = aqua("rust-lang/rust-analyzer")),
        pkg("marksman", version = "2026-02-08", source = aqua("artempyanykh/marksman")),
        pkg("nixfmt", version = "1.5.0", source = github("NixOS/nixfmt", asset = "nixfmt")),
        pkg("vtsls", version = "0.3.0", source = npm("@vtsls/language-server")),
        pkg("tailwindcss-language-server", version = "0.16.0", source = npm("@tailwindcss/language-server")),
        pkg("astro-ls", version = "2.16.10", source = npm("@astrojs/language-server")),
        pkg("yaml-language-server", version = "1.24.0", source = npm("yaml-language-server")),
        pkg("docker-langserver", version = "0.15.0", source = npm("dockerfile-language-server-nodejs")),
        pkg("docker-compose-langserver", version = "0.2.0", source = npm("@microsoft/compose-language-service")),
        # nixpkgs builds 1.126.04524 from the VS Code tree; npm's newest is 4.10.0.
        pkg("vscode-langservers-extracted", version = "4.10.0", source = npm("vscode-langservers-extracted")),
    ]

# The Nix-built apps and CLIs, from their upstream sources at the revisions ~/.config/nix locks.
def _apps():
    return [
        pkg("lazydocker", version = "0.25.2", source = aqua("jesseduffield/lazydocker")),
        # v2.30.0; its releases carry only darwin assets.
        pkg("lumen", source = git("https://github.com/jnsahaj/lumen", rev = "4ad27231c3614e3f2acbc07bc794a4e8fde06fbf")),
        # The platform tarball holds the real binary; the main npm package's bin is a stub its
        # postinstall replaces.
        pkg("claude", source = url("https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64/-/claude-code-linux-x64-2.1.289.tgz")),
        pkg("kopuz", version = "0.22.0", source = github("Kopuz-org/kopuz", asset = "kopuz_v*_x86_64-linux.tar.gz")),
        # mixins/apps/beeper.nix: nixpkgs' AppImage. Its desktop entry is in home/.
        pkg("beeper", source = url("https://beeper-desktop.download.beeper.com/builds/Beeper-4.3.73-x86_64.AppImage")),
        # formalmusic starts kopuzd when no daemon runs; the release tarball has only the player.
        # rookie's build script shells out to git, and a C++ dependency builds through cc-rs.
        pkg(
            "kopuzd",
            source = git("https://github.com/Kopuz-org/kopuz", rev = "23db9b35fe45bd773e3cdcdf0d6584b13ae5b8cc", image = TUMBLEWEED, deps = ["rustup", "gcc", "cmake", "make", "pkgconf", "alsa-devel", "dbus-1-devel", "libopenssl-devel", "git-core", "gcc-c++"]),
            build_flags = ["-p", "kopuz-kopuzd", "-p", "kopuz-ctl"],
            bins = ["kopuzd", "kopuzctl"],
        ),
        # Cargo.toml points at ../nativedesktop, and libghostty-vt builds with zig 0.16.0.
        pkg(
            "formalmusic",
            source = git("https://github.com/FormalStudio/formalmusic", rev = "9ee98746fd0bbb804aebb8007132d1e05f992940", image = TUMBLEWEED, deps = ["cargo"] + NATIVEDESKTOP_DEPS),
            build = ["sh", "-c", "set -e; w=$(mktemp -d); git clone -q https://github.com/FormalStudio/NativeDesktop $w/nativedesktop; git -C $w/nativedesktop checkout -q 7ad936d8bcf2ef7c7d026798cb63044b9c088b71; cp -r $FSPEC_SRC $w/formalmusic; curl -fsSL https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz | tar -xJ -C $w; PATH=$w/zig-x86_64-linux-0.16.0:$PATH cargo build --release --locked --manifest-path $w/formalmusic/Cargo.toml --package formalmusic; install -Dm755 $w/formalmusic/target/release/formalmusic $FSPEC_OUT/bin/formalmusic"],
        ),
        pkg("fast", source = git("https://github.com/maaslalani/fast", rev = "26d8fc9c189ba748c68f8930af11dee5c2467f7e")),
        pkg("fetch", source = git("https://github.com/areofyl/fetch", rev = "7b19d22c2d8e4b7b2295cc625c9fdf87adcabbcd")),
        pkg("fut", version = "0.24", source = github("mikker/fut")),
        pkg(
            "clipssh",
            source = git("https://github.com/samuellawrentz/clipssh", rev = "c7f4e8ddcf102302c6375ba51534c7505ddc2616"),
            build = ["sh", "-c", "install -Dm755 $FSPEC_SRC/clipssh $FSPEC_OUT/bin/clipssh"],
            bins = ["clipssh"],
        ),
        pkg("dcal", version = "1.6.1", source = github("AvengeMedia/dankcalendar", asset = "dcal-linux-amd64.tar.gz"), links = {"dcal": "dcal-linux-amd64"}),
    ]

# Called with the host facts when listed in host(modules = [home]).
def home(h):
    return list(_files(h)) + _services() + _kde() + _flatpaks() + _discord() + _claude_pulse() + _t3code(h) + _tools() + _nvim() + _apps()
