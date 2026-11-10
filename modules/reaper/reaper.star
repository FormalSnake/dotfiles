load("//lib/launchd.star", "BIN", "PATH", "poll")

def reaper(host):
    """The macbook's memory guard. Linux hosts have systemd-oomd."""
    if not host.platform.is_darwin:
        return []
    return [
        file("~/.local/bin/reaper.sh", src = "modules/reaper/reaper", perms = "0755"),
        poll("reaper", "/bin/bash " + BIN + "/reaper.sh", 60),
    ]
