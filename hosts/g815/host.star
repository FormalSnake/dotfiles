load("//lib/paths.star", "USER")
load("//modules/boot/boot.star", "boot")
load("//modules/fastfetch/fastfetch.star", "fastfetch")
load("//modules/home/home.star", "home")
load("//modules/linux/base.star", "GROUPS", "firewall", "swapfile")
load("//modules/linux/linux.star", "linux")
load("//modules/linux/packages.star", "PACKAGES")
load("//modules/linux/secrets.star", "linux_secrets")
load("//modules/sync.star", "sync_items")
load("//modules/tools.star", "tools")
load("//hosts/g815/gaming.star", "GAMING")
load("//hosts/g815/hardware.star", "HARDWARE")
load("//hosts/g815/rig.star", "RIG", "rig_users")
load("//hosts/g815/windows.star", "VMS", "WINDOWS", "WINDOWS_BOOT")

# The compiler, tester and GPU host: always on the charger, never asleep, dual-booting Windows.

GAMING_PACKAGES = [
    "steam", "gamemode", "gamescope", "mangohud", "heroic-games-launcher", "protontricks",
    "gamescope-session-steam", "steam-devices", "prismlauncher", "java-21-openjdk",
    "xwayland-satellite", "cage",
    # UxPlay's runtime.
    "libdns_sd", "gstreamer-plugins-ugly",
]

VM_PACKAGES = [
    "qemu-x86", "qemu-ovmf-x86_64", "swtpm", "mtools", "socat", "ntfs-3g", "hivex", "xxd", "efibootmgr",
    "qemu-tools", "qemu-block-dmg", "qemu-ui-gtk", "qemu-audio-pipewire", "dosfstools", "gptfdisk",
    "libvirt-daemon-qemu", "virt-manager", "system-group-libvirt",
    # fspec try's virtio-gpu with GL.
    "qemu-ui-opengl", "qemu-hw-display-virtio-vga", "qemu-hw-display-virtio-gpu-pci",
]

# What FormalShell's smoke rig and its dev.star ask the system for.
DEV_PACKAGES = [
    "labwc", "foot", "rsync", "mpv-mpris", "libnotify-tools", "pulseaudio-utils", "wlrctl", "strace",
    "hostapd", "dbus-1-daemon", "pkgconfig(libpipewire-0.3)", "pkgconfig(libspa-0.2)",
    "pkgconfig(wayland-client)", "pkgconfig(xkbcommon)", "pkgconfig(fontconfig)", "pkgconfig(pam)",
    "pkgconfig(pam_misc)", "clang",
]

# Steam Remote Play and transfers, NordVPN's OpenVPN and meshnet.
PORTS = firewall(
    tcp = [443, 27036, 27037, 27040],
    udp = [1194, 10400, 10401, 27036],
    udp_ranges = ["27031-27035"],
)

g815 = host(
    name = "g815",
    platform = "x86_64-linux",
    system = tumbleweed(
        packages = PACKAGES + GAMING_PACKAGES + VM_PACKAGES + DEV_PACKAGES + ["systemd-resolved"],
        kernel_args = [
            "nvidia-drm.modeset=1", "acpi_backlight=native", "cfg80211.ieee80211_regdom=ES",
            "mitigations=off", "quiet", "splash", "loglevel=3", "udev.log_level=3",
        ],
    ),
    users = [user(USER, uid = 1000, shell = "fish", groups = GROUPS + ["gamemode", "libvirt"])] + rig_users(),
    modules = [
        # The 256 GB root counts as low under 45 GB.
        linux("g815", gaming = True, ports = PORTS, low_free_gb = 45),
        HARDWARE,
        GAMING,
        WINDOWS,
        VMS,
        RIG,
        swapfile(),
        linux_secrets("g815"),
        sync_items(),
        home(),
        tools,
        fastfetch,
        boot(entries = [WINDOWS_BOOT]),
    ],
)
