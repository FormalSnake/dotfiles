load("//lib/launchd.star", "BIN", "poll")

def serve(name, port, target):
    """Reasserts a tailscale serve handler every 5 minutes, since a dev session's own `tailscale
    serve` replaces it."""
    def module(host):
        if host.platform.is_darwin:
            return poll(name, BIN + "/tailscale serve --bg --https=%d %s" % (port, target), 300, env = {})
        return timer(name, exec = "/usr/bin/tailscale serve --bg --https=%d %s" % (port, target), schedule = "*/5 * * * *", user = True)
    return module
