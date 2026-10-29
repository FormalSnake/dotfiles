load("//lib/paths.star", "BIN", "HOME", "STORE")

# The desktop app always starts its own backend and refuses a data directory a server owns, so it
# gets ~/.t3-desktop and reaches every server over ssh. saved-environments.json is read once, to
# migrate into its encrypted catalog; ids are each server's ~/.t3/userdata/environment-id.
SERVERS = {
    "macbook": {"alias": "macbook-t3", "id": "5c911926-9553-4e77-afea-49eacc89b011"},
    "g815": {"alias": "g815", "id": "d0c1975c-343f-40d3-8370-2689724f8040"},
}

# The second Claude account as its own provider, so the model picker switches logins.
def pulse_provider(home):
    return {"driver": "claudeAgent", "displayName": "Claude Pulse", "enabled": True, "config": {"homePath": home + "/.claude-pulse"}}

def _environment(name, s):
    return {
        "environmentId": s["id"],
        "label": name,
        "httpBaseUrl": "http://127.0.0.1:3773",
        "wsBaseUrl": "ws://127.0.0.1:3773",
        "createdAt": "2026-10-25T00:00:00.000Z",
        "lastConnectedAt": None,
        "desktopSsh": {"alias": s["alias"], "hostname": s["alias"], "username": None, "port": None},
    }

def t3code(host):
    pulse = {"providerInstances.claude-pulse": pulse_provider(HOME)}
    out = [
        file("~/.t3-desktop/userdata/settings.json", mode = "patch", owns = pulse),
        file("~/.t3-desktop/userdata/saved-environments.json", mode = "seed", perms = "0600", content = {
            "version": 1,
            "records": [_environment(name, s) for name, s in SERVERS.items()],
        }),
    ]
    if host in SERVERS:
        out += [
            file("~/.t3/userdata/settings.json", mode = "patch", owns = pulse),
            service(
                "t3code",
                exec = STORE + "/t3 serve --host 127.0.0.1 --port 3773 " + HOME + "/Developer",
                user = True,
                restart = "always",
                after = ["network"],
                description = "T3 Code server",
                env = {"PATH": BIN + ":" + STORE + ":" + HOME + "/.bun/bin:/usr/bin:/bin", "SHELL": "/usr/bin/fish"},
                systemd = {"RestartSec": 5, "WorkingDirectory": HOME, "unit": {"ConditionPathExists": STORE + "/t3"}},
            ),
            timer("t3code-serve", exec = "/usr/bin/tailscale serve --bg --https=8773 http://127.0.0.1:3773", schedule = "*/5 * * * *", user = True),
        ]
    return out
