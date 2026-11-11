load("//lib/paths.star", "LIBEXEC", "TUMBLEWEED")
load("//lib/units.star", "oneshot")
load("//modules/home/kde.star", "hide_app")

# FormalShell's smoke rig runs as throwaway users, one per slot, each with a headless labwc its
# Hyprland nests in (etc/systemd/user/formalshell-rig-*.service, kept to their group). A running
# slot holds about 550 MB and one to two cores, so eight leave the desktop most of the machine.
# The uids are pinned for the slice drop-ins below; dev/remote.sh's FS_G815_SLOTS matches the count.
RIG_USERS = ["fstest%d" % n for n in range(8)]
RIG_UID = 1001
# The mac and g815 itself both start rig runs (dev/remote.sh).
RIG_KEYS = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJi88WllIdjMaW5UJYbT7+NRYzSCrnKKYjGR7wL4n4io macbook",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxYo1mVlFzYfDSiHH4nWXYs+ZFz29vYlkRkWxQKxMFv kyandesutter@g815",
]

# The rig's legs drive foot windows; the desktop terminal is Ghostty, so foot stays out of the launcher.
RIG = [
    # aquamarine 0.15.1 never flushes its first xdg_toplevel commit, so under labwc the nested
    # Hyprland gets no monitor (hyprwm/aquamarine#415). Drop once Tumbleweed ships a release with
    # the fix. Only the rig's Hyprland loads it, through libexec/formalshell-rig/Hyprland, which
    # dev/remote.sh puts first on a slot user's PATH.
    pkg(
        "aquamarine-rig",
        source = git(
            "https://github.com/hyprwm/aquamarine",
            rev = "f31c47a1b9d300847d8fc3108ad959448103dfc1",
            image = TUMBLEWEED,
            deps = [
                "cmake", "make", "gcc-c++", "pkgconf", "hyprwayland-scanner", "pkgconfig(libseat)",
                "pkgconfig(libinput)", "pkgconfig(wayland-client)", "pkgconfig(wayland-protocols)",
                "pkgconfig(hyprutils)", "pkgconfig(pixman-1)", "pkgconfig(libdrm)", "pkgconfig(gbm)",
                "pkgconfig(libudev)", "pkgconfig(libdisplay-info)", "pkgconfig(hwdata)", "pkgconfig(egl)",
                "pkgconfig(glesv2)", "Mesa-libGLESv3-devel", "pkgconfig(gl)",
            ],
        ),
        patches = ["patches/aquamarine-wayland-configure.patch"],
        build_flags = ["-DCMAKE_INSTALL_LIBDIR=lib"],
        share = {"formalshell-rig/aquamarine": "lib"},
    ),
    # Each slot user installs its own rustup toolchain and cargo registry, the same 1.8G eight
    # times over, beside the desktop user's own. duperemove (DEV_PACKAGES) shares their identical extents on btrfs and leaves
    # every file where and whose it is, so a slot's toolchain bump or registry fetch works as before.
    timer(
        "formalshell-rig-dedupe",
        exec = "/usr/bin/duperemove -dr -q --hashfile=/var/cache/formalshell-rig-dedupe.hash " +
               " ".join(["/home/%s/%s" % (u, d) for u in RIG_USERS + ["kyandesutter"] for d in [".rustup", ".cargo/registry"]]),
        schedule = "20 */4 * * *",
    ),
    # Every slot builds its own formalshell and atoll target/, 5 to 13 GB each, and the user
    # storage-gc only scans the desktop user's home. A slot target idle a day goes.
    timer(
        "storage-gc-rig",
        exec = LIBEXEC + "/storage-gc --apply",
        schedule = "40 * * * *",
        env = {"ROOTS": " ".join(["/home/" + u for u in RIG_USERS]), "TARGET_AGE_DAYS": "1", "HOME": "/root"},
    ),
    # The slots' rootless podman keeps every exited build container and pulled base image;
    # podman-prune-user only reaches the desktop user's.
    file(LIBEXEC + "/podman-prune-rig", perms = "0755", content = "\n".join([
        "#!/bin/sh",
        "cd /",
        "for u in %s; do" % " ".join(RIG_USERS),
        "  runuser -u \"$u\" -- env XDG_RUNTIME_DIR=/run/user/$(id -u \"$u\") \\",
        "    sh -c 'podman container prune -f --filter until=24h && podman image prune -af --filter until=72h'",
        "done",
        "",
    ])),
    timer("podman-prune-rig", exec = LIBEXEC + "/podman-prune-rig", schedule = "20 0 * * *"),
    # sched_ext ignores CPUWeight, so while a game runs the slots' builds would take every core.
    # gamemode raises gaming.target and the slots keep four E-cores until it drops.
    oneshot(
        "formalshell-rig-yield",
        LIBEXEC + "/formalshell-rig-yield 20-23",
        "Hold the FormalShell rig slots to four E-cores while a game runs",
        unit = {"PartOf": "gaming.target"},
        install = {"WantedBy": "gaming.target"},
        ExecStop = LIBEXEC + "/formalshell-rig-yield",
    ),
    oneshot("formalshell-rig-passwords", LIBEXEC + "/formalshell-rig-passwords", "Set the FormalShell rig users' lock-screen password"),
    # The fstestvm slots boot the same system; KSM shares the pages they hold alike.
    oneshot("ksm", "/bin/sh -c 'echo 1 > /sys/kernel/mm/ksm/run'", "Merge the identical pages of the fstestvm guests"),
    file("/etc/systemd/user/default.target.wants/formalshell-rig-parent.service", mode = "link", target = "/etc/systemd/user/formalshell-rig-parent.service"),
] + [
    f
    for u in RIG_USERS
    for f in [
        file("/var/lib/systemd/linger/" + u, content = ""),
        file("/etc/ssh/authorized_keys.d/" + u, content = "\n".join(RIG_KEYS) + "\n"),
    ]
] + [
    # A slot's builds and sessions yield to the desktop when the two compete; idle, nothing changes.
    file("/etc/systemd/system/user-%d.slice.d/50-formalshell-rig.conf" % (RIG_UID + n), content = "[Slice]\nCPUWeight=20\nIOWeight=20\n")
    for n in range(len(RIG_USERS))
] + [hide_app(id) for id in ["foot", "footclient", "foot-server"]]

def rig_users():
    return [user(u, uid = RIG_UID + n, groups = ["fstest", "render", "video"]) for n, u in enumerate(RIG_USERS)]
