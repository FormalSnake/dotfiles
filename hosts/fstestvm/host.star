load("//lib/paths.star", "STORE")
load("//lib/tree.star", "tree")
load("//lib/units.star", "oneshot")
load("//modules/boot/boot.star", "FORMALOS", "formalos_boot")
load("//modules/linux/store.star", "FORMALSHELL")

# FormalShell's VM rig: two Tumbleweed guests on the g815 (`fspec vm start fstestvm0`), one per
# slot, carrying what its old nix/testvm.nix did: the real system daemons the `leg_<n>_vm_only`
# smoke legs and the daemon-backed `just check`s drive (NetworkManager on two hostapd radios over
# mac80211_hwsim, BlueZ, UPower, polkit, logind, PAM, pipewire), and a headless sway parent that
# dev/smoke.sh nests Hyprland in on the vkms software KMS card. Beside that, the real hosts' boot
# on the VM's own display, which `fspec vm record --boot` films: Limine, the FormalOS splash, the
# FormalShell greeter and a desktop. docs/fstestvm.md is the hand-off.

KEYS = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJi88WllIdjMaW5UJYbT7+NRYzSCrnKKYjGR7wL4n4io macbook",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxYo1mVlFzYfDSiHH4nWXYs+ZFz29vYlkRkWxQKxMFv kyandesutter@g815",
]
VM_USER = "kyan"
# Made at boot, beside the config: SELinux keeps hostapd out of /var/lib.
EAP = "/etc/fstestvm/eap"

PACKAGES = [
    # The cloud image boots kernel-default-base, which has no mac80211_hwsim or vkms.
    "kernel-default", "!kernel-default-base", "v4l2loopback-kmp-default",
    # What a remote apply and git(...) packages need on the host.
    "tar", "oras", "shadow", "sudo", "system-group-wheel", "openssh-server", "git-core", "curl",
    "NetworkManager", "wpa_supplicant", "hostapd", "dnsmasq", "iw", "iproute2", "openssl",
    "bluez", "upower", "power-profiles-daemon", "polkit", "geoclue2",
    "pipewire", "pipewire-pulseaudio", "wireplumber", "pulseaudio-utils", "pipewire-tools",
    "seatd", "greetd", "sway", "hyprland", "foot", "grim", "slurp", "wtype", "wl-clipboard", "wlrctl",
    "wf-recorder", "wlsunset", "brightnessctl", "ddcutil", "libnotify-tools", "dbus-1-daemon",
    "mpv", "mpv-mpris", "ffmpeg-8", "cava", "qrencode", "ImageMagick", "tesseract-ocr",
    "tesseract-ocr-traineddata-eng", "python313", "python313-gobject", "python313-evdev",
    "evolution-data-server", "podman", "jq", "just", "rsync", "strace", "socat", "v4l-utils", "xdg-utils",
    "jetbrains-mono-fonts", "google-noto-coloremoji-fonts", "adwaita-icon-theme", "fontconfig",
]

# dev/smoke.d/lock.sh and dev/smoke-greeter.sh type "formalshell-test", the password the old
# testvm gave its user; the g815 rig sets the same hash on its slot users.
PASSWORD = "$y$j9T$1XwN0Yw8RLnm7uMn0EnlA.$n5Tr3VdWxFwtInsHUysZeSLhJxCkEvOF6NT5bAK2TR6"

ROOTFS = tree(["hosts/fstestvm/rootfs/"], perms = {
    "/etc/sudoers.d/90-fstestvm": "0440",
    "/etc/fstestvm/eap-users": "0600",
})

# fspec names each unit fspec-<name>, which is what their dependencies on each other name. A $ in
# an ExecStart is systemd's variable expansion, hence the $$ in the password hash.
def _services():
    return [
        oneshot(
            "fstestvm-eap-cert",
            "/bin/sh -c 'test -s " + EAP + "/server.pem || { mkdir -p " + EAP + " && openssl req -x509 -newkey rsa:2048 -nodes -keyout " + EAP + "/server.key -out " + EAP + "/server.pem -days 3650 -subj /CN=formaltest-eap; }'",
            "Make the FORMALTEST-EAP network's self-signed certificate",
        ),
    ] + [
        service(
            "fstestvm-hostapd-" + w,
            exec = "/usr/sbin/hostapd /etc/fstestvm/hostapd-" + w + ".conf",
            restart = "on_failure",
            description = "hostapd on the hwsim radio " + w,
            systemd = {"unit": {
                "BindsTo": "sys-subsystem-net-devices-" + w + ".device",
                "After": ["sys-subsystem-net-devices-" + w + ".device", "fspec-fstestvm-eap-cert.service"],
                "Wants": "fspec-fstestvm-eap-cert.service",
            }},
        )
        for w in ["wlan1", "wlan2"]
    ] + [
        # The address survives hostapd's own interface setup only once hostapd is up.
        oneshot(
            "fstestvm-ap-addrs",
            "/bin/sh -c 'ip addr replace 10.90.1.1/24 dev wlan1 && ip addr replace 10.90.2.1/24 dev wlan2'",
            "Static addresses on the hwsim AP interfaces",
            unit = {"After": ["fspec-fstestvm-hostapd-wlan1.service", "fspec-fstestvm-hostapd-wlan2.service"], "Requires": ["fspec-fstestvm-hostapd-wlan1.service", "fspec-fstestvm-hostapd-wlan2.service"]},
        ),
        service(
            "fstestvm-dhcp",
            exec = "/usr/sbin/dnsmasq -k --conf-file=/etc/fstestvm/dnsmasq.conf",
            restart = "on_failure",
            description = "DHCP on the hwsim AP interfaces",
            systemd = {"unit": {"After": "fspec-fstestvm-ap-addrs.service", "Requires": "fspec-fstestvm-ap-addrs.service"}},
        ),
        oneshot("fstestvm-password", "/usr/sbin/usermod -p '" + PASSWORD.replace("$", "$$") + "' " + VM_USER, "Set the rig user's lock-screen password"),
        service("sshd"),
        service("NetworkManager"),
        service("bluetooth"),
        service("upower"),
        service("power-profiles-daemon"),
        # Tumbleweed's seatd ships no unit and no seat group; libseat goes through logind.
        service("greetd", display_manager = True),
    ]

def _fstestvm(h):
    return [FORMALSHELL] + ROOTFS + _services() + [
        file("/etc/ssh/ssh_known_hosts", src = "rootfs/etc/ssh/ssh_known_hosts", perms = "0644"),
        # The lingering manager runs the headless parent dev/smoke.sh nests in.
        file("/etc/systemd/user/default.target.wants/fstestvm-parent.service", mode = "link", target = "/etc/systemd/user/fstestvm-parent.service"),
    ] + formalos_boot(
        # The real hosts' boot without the chime: the VM has no sound card, and the chime waits
        # for one before the greeter may start.
        dict(FORMALOS, chime = None),
    )

fstestvm = [
    host(
        name = "fstestvm%d" % n,
        platform = "x86_64-linux",
        # e1504g's and the g815's quiet boot, so the splash is all that shows.
        system = tumbleweed(packages = PACKAGES, kernel_args = ["quiet", "splash", "loglevel=3", "udev.log_level=3"]),
        users = [user(VM_USER, uid = 1000, shell = "bash", groups = ["wheel", "video", "render", "input", "audio"])],
        builders = [builder("g815")],
        vm = vm("g815", port = 2222 + n, cpus = 6, memory_gib = 8, disk_gib = 40, authorized_keys = KEYS),
        modules = [_fstestvm],
    )
    for n in [0, 1]
]
