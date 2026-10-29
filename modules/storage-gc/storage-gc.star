load("//lib/launchd.star", "BIN", "HOME", "LOGS", "PATH")
load("//lib/paths.star", "LIBEXEC")

SCRIPT = "modules/storage-gc/storage-gc"

def storage_gc(low_free_gb = None):
    """Prunes build output and agent worktrees: hourly on Linux, since a day of agent builds can
    eat 35 GB, and daily on the macbook. `low_free_gb` is where Chromium's storage-pressure bubble
    starts on a small root."""
    def module(host):
        if host.platform.is_darwin:
            return [
                file("~/.local/bin/storage-gc.sh", src = SCRIPT),
                # The log holds one run.
                timer(
                    "storage-gc",
                    exec = "/bin/sh -c '/bin/bash %s/storage-gc.sh --apply --prune-worktrees > %s/storage-gc.log 2>&1'" % (BIN, LOGS),
                    schedule = "0 12 * * *",
                    user = True,
                    env = {"PATH": PATH + ":" + HOME + "/.cargo/bin", "HOME": HOME},
                ),
            ]
        return [
            file(LIBEXEC + "/storage-gc", src = SCRIPT),
            timer(
                "storage-gc",
                exec = LIBEXEC + "/storage-gc --apply --prune-worktrees",
                schedule = "0 * * * *",
                user = True,
                env = {"LOW_FREE_GB": str(low_free_gb)} if low_free_gb else {},
            ),
        ]
    return module
