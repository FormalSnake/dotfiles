load("//modules/linux/base.star", "FILES", "REPOS", "SERVICES", "firewall", "rootfs")
load("//modules/linux/sessions.star", "sessions")
load("//modules/linux/store.star", "KDE_STORE", "STORE")
load("//modules/storage-gc/storage-gc.star", "storage_gc")

def linux(host, gaming = False, ports = None, low_free_gb = None):
    """The system layer both Tumbleweed hosts share, plus hosts/<host>/rootfs."""
    return (
        REPOS + rootfs(host) + FILES + STORE + (KDE_STORE if host != "g815" else []) + SERVICES +
        sessions(gaming) +
        [ports or firewall(), storage_gc(low_free_gb)]
    )
