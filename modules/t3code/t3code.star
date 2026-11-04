load("//lib/launchd.star", "BREW", "PATH", "agent")
load("//lib/paths.star", "BIN", "STORE", "home_of")
load("//modules/tailscale.star", "serve")

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

# Every server prints its thread state for the Linux hosts' Stream Deck, DualSense lightbar and
# FormalShell badges, which poll it over ssh.
def agents(host):
    if host not in SERVERS:
        return []
    return [file("~/.local/bin/t3-agents", src = "modules/t3code/t3-agents", perms = "0755")]

# The macbook's server drives its iOS simulators and devices.
DEVICES = {"enableDeviceSupport": True, "deviceOnboardingCompleted": True, "enableAgentDeviceAccess": True}

def t3code(host):
    """The desktop app on Linux, and the server on each host in SERVERS."""
    mac = host.platform.is_darwin
    home = home_of(host)
    pulse = {"providerInstances.claude-pulse": pulse_provider(home)}
    out = []
    if not mac:
        out += [
            file("~/.t3-desktop/userdata/settings.json", mode = "patch", owns = pulse),
            file("~/.t3-desktop/userdata/saved-environments.json", mode = "seed", perms = "0600", content = {
                "version": 1,
                "records": [_environment(name, s) for name, s in SERVERS.items()],
            }),
        ]
    if host.name in SERVERS:
        exec = STORE + "/t3 serve --host 127.0.0.1 --port 3773 " + home + "/Developer"
        out += [
            file("~/.t3/userdata/settings.json", mode = "patch", owns = dict(pulse, **DEVICES) if mac else pulse),
            agent("t3code", exec, env = {"PATH": PATH, "SHELL": BREW + "/fish"}, WorkingDirectory = home) if mac else service(
                "t3code",
                exec = exec,
                user = True,
                restart = "always",
                after = ["network"],
                description = "T3 Code server",
                env = {"PATH": BIN + ":" + STORE + ":" + home + "/.bun/bin:/usr/bin:/bin", "SHELL": "/usr/bin/fish"},
                systemd = {"RestartSec": 5, "WorkingDirectory": home, "unit": {"ConditionPathExists": STORE + "/t3"}},
            ),
            serve("t3code-serve", 8773, "http://127.0.0.1:3773"),
        ]
    return out + agents(host.name)
