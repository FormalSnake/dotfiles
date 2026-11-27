load("//lib/paths.star", "LIBEXEC", "USER")
load("//modules/boot/boot.star", "QUIET_ARGS", "boot")
load("//modules/fastfetch/fastfetch.star", "fastfetch")
load("//modules/fspec.star", "fspec")
load("//modules/apps.star", "apps")
load("//modules/my_apps.star", "my_apps")
load("//modules/home/home.star", "home")
load("//modules/linux/base.star", "GROUPS", "swapfile")
load("//modules/linux/linux.star", "linux")
load("//modules/linux/packages.star", "KDE_PACKAGES", "PACKAGES")
load("//modules/linux/secrets.star", "linux_secrets")
load("//modules/sync.star", "sync_items")
load("//modules/tools.star", "tools")

SERVICES = [
    service("systemd-oomd"),
    service(
        "power-cap",
        exec = LIBEXEC + "/power-cap",
        restart = "always",
        description = "Per-profile RAPL package power caps (quiet fans)",
        systemd = {
            "RestartSec": 2,
            # A restarted tuned-ppd comes up in its default profile without a PropertiesChanged signal.
            "unit": {"After": "tuned-ppd.service", "Wants": "tuned-ppd.service", "PartOf": "tuned-ppd.service"},
        },
    ),
]

# What NativeDesktop's dev.star asks the system for, so nd and lynk build here while g815 is away.
ND_BUILD_PACKAGES = [
    "clang", "wayland-devel", "weston", "rsync", "pkgconfig(wayland-client)", "pkgconfig(xkbcommon)",
    "pkgconfig(vulkan)", "pkgconfig(x11)", "pkgconfig(xcb)", "pkgconfig(xcursor)", "pkgconfig(xi)",
    "pkgconfig(xrandr)", "pkgconfig(xkbfile)", "pkgconfig(fontconfig)", "pkgconfig(freetype2)",
    "pkgconfig(alsa)", "pkgconfig(openssl)", "pkgconfig(gbm)", "pkgconfig(egl)", "pkgconfig(glib-2.0)",
    "pkgconfig(nss)", "pkgconfig(nspr)", "pkgconfig(atk)", "pkgconfig(atk-bridge-2.0)", "pkgconfig(libdrm)",
    "pkgconfig(expat)", "pkgconfig(gtk+-3.0)", "pkgconfig(pango)", "pkgconfig(cairo)", "pkgconfig(dbus-1)",
    "pkgconfig(atspi-2)", "pkgconfig(cups)", "pkgconfig(gl)", "pkgconfig(libudev)", "pkgconfig(libsystemd)",
    "pkgconfig(xcomposite)", "pkgconfig(xdamage)", "pkgconfig(xext)", "pkgconfig(xfixes)",
    "pkgconfig(xshmfence)", "pkgconfig(gstreamer-1.0)", "pkgconfig(gstreamer-plugins-base-1.0)",
    "pkgconfig(gstreamer-plugins-bad-1.0)",
]

e1504g = host(
    name = "e1504g",
    platform = "x86_64-linux",
    system = tumbleweed(
        # foot, strace and dbus-1-daemon: FormalShell's nested smoke run
        # (dev/smoke.sh with a g815 build in FS_RESULT), what reads the
        # shell's numbers on this machine's own GPU. perf: wm/dev/hostbench.sh
        # there, the frame costs of formalwm and the shell nested in the session.
        # labwc: the headless parent nd's test Hyprland nests in, for Lynk's
        # low-end benchmark (scripts/linux-gate bench e1504g).
        packages = PACKAGES + KDE_PACKAGES + ["systemd-experimental", "foot", "strace", "dbus-1-daemon", "perf", "labwc"] + ND_BUILD_PACKAGES,
        # The initrd loads both blacklisted modules before /etc/modprobe.d applies.
        kernel_args = [
            "mitigations=off", "intel_iommu=on", "module_blacklist=ucsi_acpi,intel_ish_ipc",
        ] + QUIET_ARGS,
    ),
    users = [user(USER, uid = 1000, shell = "fish", groups = GROUPS)],
    # Builds what CI has not on the g815, over the tailnet, then the LAN.
    builders = [builder("g815", routes = ["g815", "192.168.86.95"])],
    modules = [
        linux("e1504g", session = "formalwm-uwsm"),
        SERVICES,
        swapfile(),
        linux_secrets("e1504g"),
        sync_items(),
        home(),
        tools,
        my_apps,
        apps,
        fspec,
        fastfetch,
        boot(),
    ],
)
