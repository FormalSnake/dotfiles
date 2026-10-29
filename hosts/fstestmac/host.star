load("//lib/paths.star", "LIBEXEC", "TUMBLEWEED")
load("//lib/tree.star", "tree")
load("//lib/units.star", "oneshot")
load("//modules/linux/store.star", "FORMALSHELL")

# FormalShell's night rig: a Tumbleweed guest on the macbook (hosts/fstestmac/lima.yaml, started
# by FormalShell's dev/mac-vm.sh), for building and smoking the shell while the g815 is off. Slot
# users as on the g815 (hosts/g815/rig.star), but each Hyprland runs on a vkms card of its own
# instead of nesting: the guest has no GPU, so there is no render node to nest with. No real
# system daemons either: dev/smoke.sh reads /etc/formalshell-rig/kind and gives every run a
# private system bus, as on the g815, refusing the legs that need fstestvm or the g815.

SLOTS = 4
SLOT_USERS = ["fstest%d" % n for n in range(SLOTS)]
SLOT_UID = 1001
KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJi88WllIdjMaW5UJYbT7+NRYzSCrnKKYjGR7wL4n4io macbook"

PACKAGES = [
    "kernel-default", "!kernel-default-base",
    "tar", "oras", "shadow", "sudo", "openssh-server", "git-core", "curl", "podman",
    "hyprland", "hyprland-guiutils", "foot", "grim", "slurp", "wtype", "wl-clipboard",
    "wf-recorder", "wlsunset", "brightnessctl", "ddcutil", "libnotify-tools", "dbus-1-daemon",
    "pipewire", "pipewire-pulseaudio", "wireplumber", "pulseaudio-utils", "pipewire-tools",
    "mpv", "mpv-mpris", "ffmpeg-8", "cava", "qrencode", "ImageMagick", "tesseract-ocr",
    "tesseract-ocr-traineddata-eng", "python313", "python313-gobject", "python313-evdev",
    "evolution-data-server", "jq", "just", "rsync", "strace", "socat", "xdg-utils",
    "jetbrains-mono-fonts", "google-noto-coloremoji-fonts", "adwaita-icon-theme", "fontconfig",
    # What dev.star's cargo build links and runs.
    "pkgconfig(libpipewire-0.3)", "pkgconfig(libspa-0.2)", "pkgconfig(wayland-client)",
    "pkgconfig(xkbcommon)", "pkgconfig(fontconfig)", "pkgconfig(pam)", "pkgconfig(pam_misc)", "clang",
]

# Tumbleweed carries wlrctl for x86_64 only.
WLRCTL = pkg(
    "wlrctl",
    source = git(
        "https://git.sr.ht/~brocellous/wlrctl",
        rev = "afe60da062ea315b92f2a9857e50b77e0b3a4b7e",
        image = TUMBLEWEED,
        deps = ["meson", "ninja", "gcc", "pkgconf", "pkgconfig(wayland-client)", "pkgconfig(wayland-protocols)", "pkgconfig(xkbcommon)", "wayland-devel"],
    ),
    # char is unsigned on aarch64, so its `str[i] < 0` ASCII check trips -Werror=type-limits.
    build_flags = ["-Dwerror=false"],
)

ROOTFS = tree(["hosts/fstestmac/rootfs/"]) + [
    file("/etc/ssh/sshd_config.d/10-fspec.conf", src = "modules/linux/rootfs/etc/ssh/sshd_config.d/10-fspec.conf"),
    file("/etc/pam.d/formalshell-lock", src = "modules/linux/rootfs/etc/pam.d/formalshell-lock"),
    file("/etc/profile.d/fspec-store.sh", src = "modules/linux/rootfs/etc/profile.d/fspec-store.sh"),
    # A null sink, since the guest has no sound card and the legs play through the default one.
    file("/etc/pipewire/pipewire.conf.d/10-virtual-sink.conf", src = "hosts/fstestvm/rootfs/etc/pipewire/pipewire.conf.d/10-virtual-sink.conf"),
    file(LIBEXEC + "/formalshell-rig-passwords", src = "hosts/g815/rootfs/usr/local/libexec/formalshell-rig-passwords", perms = "0755"),
]

def _fstestmac(h):
    return [FORMALSHELL, WLRCTL] + ROOTFS + [
        oneshot("formalshell-rig-passwords", LIBEXEC + "/formalshell-rig-passwords", "Set the FormalShell rig users' lock-screen password"),
        oneshot("formalshell-rig-vkms", LIBEXEC + "/formalshell-rig-vkms", "One vkms card per FormalShell rig slot"),
        service("sshd"),
    ] + [
        f
        for u in SLOT_USERS
        for f in [
            file("/var/lib/systemd/linger/" + u, content = ""),
            file("/etc/ssh/authorized_keys.d/" + u, content = KEY + "\n"),
        ]
    ]

fstestmac = host(
    name = "fstestmac",
    platform = "aarch64-linux",
    system = tumbleweed(packages = PACKAGES),
    users = [user("kyan", uid = 1000, shell = "bash", groups = ["video"])] + [
        user(u, uid = SLOT_UID + n, shell = "bash", groups = ["video"])
        for n, u in enumerate(SLOT_USERS)
    ],
    modules = [_fstestmac],
)
