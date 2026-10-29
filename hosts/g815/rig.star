load("//lib/paths.star", "LIBEXEC", "TUMBLEWEED")
load("//lib/units.star", "oneshot")
load("//modules/home/kde.star", "hide_app")

# FormalShell's smoke rig runs as throwaway users, one per slot, each with a headless labwc its
# Hyprland nests in (etc/systemd/user/formalshell-rig-*.service, kept to their group).
RIG_USERS = ["fstest0", "fstest1"]
RIG_KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJi88WllIdjMaW5UJYbT7+NRYzSCrnKKYjGR7wL4n4io macbook"

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
    oneshot("formalshell-rig-passwords", LIBEXEC + "/formalshell-rig-passwords", "Set the FormalShell rig users' lock-screen password"),
    file("/etc/systemd/user/default.target.wants/formalshell-rig-parent.service", mode = "link", target = "/etc/systemd/user/formalshell-rig-parent.service"),
] + [
    f
    for u in RIG_USERS
    for f in [
        file("/var/lib/systemd/linger/" + u, content = ""),
        file("/etc/ssh/authorized_keys.d/" + u, content = RIG_KEY + "\n"),
    ]
] + [hide_app(id) for id in ["foot", "footclient", "foot-server"]]

def rig_users():
    return [user(u, groups = ["fstest", "render", "video"]) for u in RIG_USERS]
