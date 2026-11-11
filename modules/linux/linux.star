load("//lib/paths.star", "KDE_HOSTS")
load("//modules/linux/base.star", "FILES", "REPOS", "SERVICES", "firewall", "rootfs")
load("//modules/linux/sessions.star", "sessions")
load("//modules/linux/store.star", "KDE_STORE", "SHOJI", "STORE")
load("//modules/storage-gc/storage-gc.star", "storage_gc")

def linux(host, gaming = False, ports = None, low_free_gb = None, session = "hyprland-uwsm"):
    """The system layer both Tumbleweed hosts share, plus hosts/<host>/rootfs. `session` is what
    the host logs into at boot and what the greeter offers first."""
    return (
        REPOS + rootfs(host) + FILES + STORE + SHOJI + (KDE_STORE if host in KDE_HOSTS else []) + SERVICES +
        sessions(gaming, session) +
        [ports or firewall(), storage_gc(low_free_gb)]
    )
