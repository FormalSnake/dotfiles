load("//lib/paths.star", "home_of")

# The relay Herdr's viewer mod streams a browser and the simulator from, on every host.
def herdr_view(host):
    mac = host.platform.is_darwin
    home = home_of(host)
    script = home + "/.local/share/herdr-view/herdr-view.ts"
    bun = "/opt/homebrew/bin/bun" if mac else "/usr/bin/bun"
    path = ":".join([home + "/.local/bin", "/opt/fspec/current/bin"] + (["/opt/homebrew/bin"] if mac else []) + ["/usr/bin", "/bin", "/usr/sbin", "/sbin"])
    log = home + ("/Library/Logs/herdr-view.log" if mac else "/.cache/herdr-view/relay.log")
    return [
        file("~/.local/share/herdr-view/herdr-view.ts", src = "modules/herdr_view/herdr-view.ts"),
        service(
            "herdr-view",
            exec = bun + " " + script,
            user = True,
            restart = "always",
            after = ["network"],
            env = {"PATH": path, "HOME": home},
            **({"launchd": {"StandardOutPath": log, "StandardErrorPath": log, "ThrottleInterval": 5}} if mac else {"systemd": {"RestartSec": 5}})
        ),
    ]
