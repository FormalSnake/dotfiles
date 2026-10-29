load("//lib/paths.star", "LIBEXEC", "USER")
load("//modules/boot/boot.star", "boot")
load("//modules/fastfetch/fastfetch.star", "fastfetch")
load("//modules/home/home.star", "home")
load("//modules/linux/base.star", "GROUPS", "swapfile")
load("//modules/linux/linux.star", "linux")
load("//modules/linux/packages.star", "PACKAGES")
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

e1504g = host(
    name = "e1504g",
    platform = "x86_64-linux",
    system = tumbleweed(
        packages = PACKAGES + ["systemd-experimental"],
        # The initrd loads both blacklisted modules before /etc/modprobe.d applies.
        kernel_args = [
            "mitigations=off", "intel_iommu=on", "quiet", "splash", "udev.log_level=3",
            "module_blacklist=ucsi_acpi,intel_ish_ipc",
        ],
    ),
    users = [user(USER, uid = 1000, shell = "fish", groups = GROUPS)],
    # Builds what CI has not on the g815, over the tailnet, then the LAN.
    builders = [builder("g815", routes = ["g815", "192.168.86.95"])],
    modules = [
        linux("e1504g"),
        SERVICES,
        swapfile(),
        linux_secrets("e1504g"),
        sync_items(),
        home(),
        tools,
        fastfetch,
        boot(),
    ],
)
