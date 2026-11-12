load("//lib/paths.star", "HOME")
load("//lib/units.star", "gui")

# The g815's folder on the macbook's external SSD, over sshfs. The 256 GB root is shared with
# Windows, so archives and anything else read rarely go here. The g815 reaches the macbook over
# wifi at about 10 MB/s: nothing a build or an app reads live belongs on it.

MOUNT = HOME + "/.drive"

# The root's own overflow: an 80 GB btrfs image on the USB SSD's exFAT partition, which builds
# as fast as the NVMe. It holds only fspec's build dirs, which rebuild from nothing: without the
# SSD the mounts fail and the builds land in the directories underneath, on the root.
OVERFLOW = [service(u) for u in ["mnt-overflow.mount", "home-kyandesutter-.cache-fspec-build.mount", "root-.cache-fspec-build.mount"]]

DRIVE = OVERFLOW + [
    gui(
        "drive-mount",
        "/usr/bin/sshfs -f -o reconnect -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o idmap=user macbook:drive/g815 " + MOUNT,
        "SSHFS mount of the g815's folder on the macbook's external SSD at ~/.drive",
        restart = "on_failure",
        unit = {"After": ["graphical-session.target", "fspec-1password.service"], "Wants": "fspec-1password.service", "StartLimitIntervalSec": 0},
        RestartSec = 30,
        ExecStartPre = [
            "-/usr/bin/fusermount3 -uz " + MOUNT,
            "/usr/bin/mkdir -p " + MOUNT,
            "/usr/bin/ssh -o ConnectTimeout=10 macbook mkdir -p drive/g815",
        ],
        ExecStopPost = "-/usr/bin/fusermount3 -uz " + MOUNT,
    ),
]
