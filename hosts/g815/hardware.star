load("//lib/paths.star", "LIBEXEC", "STORE")
load("//lib/units.star", "oneshot")

def nvidia(name, **kw):
    return pkg(name, source = zypper(repo = "nvidia"), **kw)

# NVIDIA's own repo; G07 is the newest series it carries. The meta package pulls the signed open
# kernel module.
NVIDIA = [
    repo(
        "nvidia",
        url = "https://download.nvidia.com/opensuse/tumbleweed",
        key = "https://download.nvidia.com/opensuse/tumbleweed/repodata/repomd.xml.key",
        fingerprint = "2FB03195DECD49492BD1C17AB1D0D788DB27FD5A",
    ),
    nvidia("nvidia-open-driver-G07-signed-kmp-meta"),
    nvidia("nvidia-video-G07"),
    nvidia("nvidia-gl-G07"),
    nvidia("nvidia-gl-G07-32bit"),
    nvidia("nvidia-compute-utils-G07", services = [service("nvidia-powerd")]),
    nvidia("nvidia-settings"),
    # The ASUS MUX routes the internal panel through the dGPU; the firmware applies it next boot.
    oneshot(
        "gpu-mux-dgpu",
        LIBEXEC + "/gpu-mux-dgpu",
        "Route the internal panel through the dGPU (ASUS MUX)",
        remain = False,
        unit = {"After": "fspec-asusd.service", "ConditionPathExists": "/sys/devices/platform/asus-nb-wmi/gpu_mux_mode"},
    ),
]

ASUS = [
    # No Tumbleweed package; the release's Arch build needs only glibc and libudev. Its udev rule
    # wants asusd.service by that name, so the unit below carries the store path instead.
    pkg(
        "asusctl",
        version = "6.5.0",
        source = github("OpenGamingCollective/asusctl", asset = "asusctl-*-x86_64.pkg.tar.zst"),
        bins = ["asusd", "asusctl"],
        etc = {"dbus-1/system.d/asusd.conf": "usr/share/dbus-1/system.d/asusd.conf"},
    ),
    service(
        "asusd",
        exec = STORE + "/asusd",
        restart = "on_failure",
        description = "ASUS Notebook Control",
        env = {"IS_SERVICE": "1"},
        systemd = {
            "Type": "dbus",
            "BusName": "xyz.ljones.Asusd",
            "ExecStartPre": "/usr/bin/sleep 1",
            "RestartSec": 1,
            "TimeoutSec": 10,
            "ConfigurationDirectory": "asusd",
            "unit": {"After": ["nvidia-powerd.service", "systemd-udevd.service"], "StartLimitIntervalSec": 500, "StartLimitBurst": 5, "ConditionPathExists": STORE + "/asusd"},
        },
    ),
    oneshot(
        "asus-aura",
        LIBEXEC + "/asus-aura",
        "Aura keyboard accent seed + 80% charge limit",
        unit = {"After": "fspec-asusd.service", "Requires": "fspec-asusd.service"},
    ),
]

# Driven remotely: a deactivated Wi-Fi once left it off the tailnet for 50 minutes.
NETWORK = [
    service("systemd-resolved"),
    file("/etc/resolv.conf", mode = "link", target = "/run/systemd/resolve/stub-resolv.conf"),
    timer("wifi-reconnect", exec = LIBEXEC + "/wifi-reconnect", schedule = "*/2 * * * *"),
]

HARDWARE = NVIDIA + ASUS + NETWORK
