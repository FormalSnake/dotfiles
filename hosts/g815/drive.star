load("//lib/paths.star", "HOME")
load("//lib/units.star", "gui")

# The g815's share of the macbook's external SSD, over sshfs. The 256 GB root is shared with
# Windows, so what is read rarely and can take a network round trip lives there instead.

MOUNT = HOME + "/.drive"

# Made on the macbook before each mount, so it exists only while mounted: a move into it fails
# on an unmounted drive instead of filling the directory under the mount point.
COLD = MOUNT + "/cold"

ON_DRIVE = {".cache/huggingface": "huggingface"}

DRIVE = [
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
            "/usr/bin/ssh -o ConnectTimeout=10 macbook mkdir -p drive/g815/cold",
        ],
        ExecStopPost = "-/usr/bin/fusermount3 -uz " + MOUNT,
    ),
] + [file("~/" + p, mode = "link", target = COLD + "/" + sub, move = True) for p, sub in ON_DRIVE.items()]
