load("//lib/launchd.star", "BIN", "BREW", "HOME", "PATH", "agent", "logs", "poll")
load("//lib/paths.star", "STORE")
load("//modules/tailscale.star", "serve")

LOGIN_APPS = {"nordvpn": "NordVPN", "aldente": "AlDente", "orbstack": "OrbStack", "betterdisplay": "BetterDisplay"}

SERVICES = [
    service("login-" + k, exec = "/usr/bin/open -g -j -a /Applications/%s.app" % v, user = True)
    for k, v in LOGIN_APPS.items()
] + [
    # Awake from boot, before anyone logs in.
    service("caffeinate", exec = "/usr/bin/caffeinate -i -s", restart = "always"),
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
    # Puts a phone plugged into a Linux laptop in Xcode. It renames /var/run/usbmuxd while it runs,
    # so it stays idle until `usbflux on` kickstarts it.
    service(
        "usbfluxd",
        exec = STORE + "/usbfluxd -f -m -r 100.114.32.78:5000",
        launchd = {"RunAtLoad": False, "KeepAlive": False, "StandardOutPath": "/var/log/usbfluxd.log", "StandardErrorPath": "/var/log/usbfluxd.log"},
    ),
    service(
        "couchdb",
        exec = "/bin/bash " + BIN + "/couchdb-start.sh",
        user = True,
        restart = "always",
        launchd = logs("couchdb", {"LimitLoadToSessionType": ["Aqua", "Background", "LoginWindow", "StandardIO", "System"]}),
    ),
    # Keeps ~/Notes current off CouchDB's _changes feed without Obsidian open.
    agent("obsidian-livesync-daemon", "/bin/bash " + BIN + "/obsidian-livesync-daemon.sh", ThrottleInterval = 30),
    agent("meshtop-web", STORE + "/meshtop serve --listen 127.0.0.1:7314 --allow-host macbook-pro-2.tailb24294.ts.net", ThrottleInterval = 30),
    serve("meshtop-web-serve", 8314, "http://127.0.0.1:7314"),
    agent(
        "messages-agent",
        BREW + "/bun " + HOME + "/Developer/ecosystem/messages/apps/mac-agent/src/agent.ts",
        log = "messages/agent",
        WorkingDirectory = HOME + "/Developer/ecosystem/messages/apps/mac-agent",
    ),
    serve("obsidian-livesync-serve", 443, "http://127.0.0.1:5984"),
    poll("obsidian-note-watcher", "/bin/bash " + BIN + "/obsidian-note-watcher.sh", 300),
    # WatchPaths fires on the scan inbox; the interval covers missed events.
    poll("obsidian-scan-watcher", "/bin/bash " + BIN + "/obsidian-scan-watcher.sh", 600, WatchPaths = [HOME + "/Notes/_inbox/scans"], ThrottleInterval = 15),
    poll("dev-vm-reaper", "/bin/bash " + BIN + "/dev-vm-reaper.sh", 900, env = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": HOME}),
]
