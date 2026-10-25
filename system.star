# Kyan's Linux hosts, the e1504g and the g815, on openSUSE Tumbleweed: the packages, vendor repos,
# system files and services their NixOS roots have, by Tumbleweed's own package names. What only
# one host has is gated on h.name here; the g815's NVIDIA, ASUS, gaming and Windows pieces live in
# g815.star. Tools no Tumbleweed repo carries come from upstream releases or source builds through
# the fspec store (/opt/fspec/current/bin).

# Root files both hosts share, under the e1504g's name since it was ported first.
ROOTFS = "e1504g/rootfs/"
PKG_BIN = "/opt/fspec/current/bin"
LIBEXEC = "/usr/local/libexec"
# git() builds that link system libraries run in the target's own distro, so the sonames match.
TUMBLEWEED = "registry.opensuse.org/opensuse/tumbleweed"

NIL_BUILD = """set -e
rustup -q default stable
cargo build --release --locked --manifest-path "$FSPEC_SRC/Cargo.toml" --target-dir "$FSPEC_SRC/target" -p nil
install -Dm755 "$FSPEC_SRC/target/release/nil" "$FSPEC_OUT/bin/nil"
"""
STEAMED = "Steamed-14e8a1c0db188870ab3ac2059dbf941fad9c3065"

DESKTOP = [
    "hyprland", "uwsm", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "greetd", "sway",
    "swayidle", "wl-clipboard", "grim", "slurp", "wf-recorder", "brightnessctl", "ddcutil", "wlsunset",
    "cava", "playerctl", "mpv", "qrencode", "wtype", "tesseract-ocr", "tesseract-ocr-traineddata-eng",
    "xdg-utils", "evolution-data-server", "geoclue2", "libgtk-4-1", "libadwaita-1-0", "python313-gobject",
    "hyprlock", "hypridle", "hyprpicker", "ghostty", "adwaita-icon-theme", "libhidapi-hidraw0",
    "python313-evdev", "python313-FontTools", "python313-Pillow", "python313-streamdeck", "xrdb",
    "gnome-keyring", "gnome-keyring-pam", "hyprland-guiutils", "apparmor-abstractions", "gvfs", "tumbler", "nautilus", "qt6ct", "qt5ct", "dconf", "gsettings-backend-dconf", "glib2-tools",
    "adwaita-fonts", "google-noto-sans-symbols2-fonts", "google-noto-coloremoji-fonts",
    "google-noto-sans-cjk-fonts", "liberation-fonts", "easyeffects", "pipewire-tools", "wvkbd",
    "dualsensectl", "flatpak",
    # The mimeapps.list targets; Apostrophe comes from Flathub.
    "papers", "loupe", "gnome-text-editor", "celluloid",
    # Messages: video thumbnails through ffmpeg, notifications, its Vulkan renderer and media playback.
    "ffmpeg-8", "libnotify4", "libvulkan1", "gstreamer-plugins-good", "gstreamer-plugins-bad",
    "gstreamer-plugins-libav",
    # What the fspec-installed librepods, kopuz, formalmusic and the Electron apps load.
    "libQt6Core6", "libQt6DBus6", "libQt6Bluetooth6", "libpulse0", "libwebkit2gtk-4_1-0", "libgtk-3-0",
    "libsoup-3_0-0", "glib-networking", "libasound2", "xdotool", "libayatana-appindicator3-1", "libopus0",
    "libgbm1", "libxkbfile1", "libgtksourceview-5-0", "mozilla-nss", "libatk-bridge-2_0-0", "libcups2",
    "libXcomposite1", "libXdamage1", "libXrandr2", "libsecret-1-0", "secret-tool", "libpipewire-0_3-0", "libxshmfence1",
    # mixins/desktop/kde: Plasma next to Hyprland, kscreen-doctor for kwin-outputs, kwriteconfig6.
    "patterns-kde-kde_plasma", "kscreen6", "kf6-kconfig",
    # ancs4linux's runtime, and the libraries the ananicy-cpp build links.
    "python313-dasbus", "python313-typer", "libfmt12", "libspdlog1_17", "libpcre2-8-0",
]

SYSTEM = [
    # The minimal base ships power-profiles-daemon and busybox-gzip, which conflict with tuned-ppd
    # and with the gzip fish needs.
    "tailscale", "syncthing", "docker", "tuned", "tuned-ppd", "!power-profiles-daemon", "fish", "!busybox-gzip", "sshfs", "usbmuxd",
    "imobiledevice-tools", "ifuse", "smartmontools", "pam_ssh_agent_auth",
    # The rest of ~/.config/nix's core and hardware mixins: the Intel DSPs' audio firmware
    # (no sinks without it), BlueZ, chrony, fwupd, and the es_ES and en_GB locales.
    "sof-firmware", "bluez", "chrony", "fwupd", "glibc-locale",
    # The wheel, audio, video and input groups the user joins.
    "system-group-wheel", "system-group-hardware",
    # fish's fish_command_not_found runs openSUSE's command-not-found, which cnf ships.
    "cnf",
    # A remote `fspec apply` unpacks the shipped spec with tar, which the base pattern lacks; the
    # store pulls CI-built git(...) packages from ghcr.io with oras.
    "tar", "oras",
    # useradd and usermod, which the base pattern leaves out.
    "shadow",
    # Video decode (Chromium dlopens libva), IRQ spreading, mDNS printer discovery, network and USB
    # diagnostics, DDC/CI buses for ddcutil, the GNOME online-accounts panel, and the userspace OOM guard.
    # ideviceinstaller has no Tumbleweed package.
    "intel-media-driver", "libva-utils", "irqbalance", "avahi", "nss-mdns", "cups-filters-cups-browsed",
    "traceroute", "mtr", "usbutils", "alsa-utils", "i2c-tools", "gnome-control-center", "earlyoom",
    # mixins/tuning/scx.nix, NixOS's firewall, and the boot chime's generator.
    "scx", "firewalld", "python313",
]

CLI = [
    "neovim", "ripgrep", "fd", "bat", "btop", "zoxide", "fzf", "git", "git-lfs", "gh", "jq", "tmux",
    "direnv", "just", "fastfetch", "lsd", "lazygit", "yazi", "mosh", "wget", "ImageMagick", "chafa",
    "lua54", "bun", "python313-uv",
    # nvim: npm-sourced language servers run on node and install with npm; nvim-treesitter compiles
    # its parsers with tree-sitter and gcc; snacks converts PDFs with ghostscript; rust-analyzer reads
    # rust-src; astro-ls takes its TypeScript SDK from typescript.
    "nodejs24", "npm24", "gcc", "tree-sitter", "ghostscript", "rust-src", "taplo", "gopls",
    "lua-language-server", "typescript",
]

PACKAGES = DESKTOP + SYSTEM + CLI

# mixins/tuning/oomd.nix is the e1504g's only; Tumbleweed ships systemd-oomd here.
E1504G_PACKAGES = ["systemd-experimental"]

ANCS4LINUX_BUILD = """set -e
python3.13 -m pip install --no-deps --no-build-isolation --target "$FSPEC_OUT/lib" "$FSPEC_SRC"
mkdir -p "$FSPEC_OUT/bin"
for m in observer advertising ctl desktop_integration; do
  c="$FSPEC_OUT/bin/ancs4linux-$(echo $m | tr _ -)"
  cat > "$c" <<EOF
#!/bin/sh
PYTHONPATH="\\$(dirname "\\$(readlink -f "\\$0")")/../lib" exec /usr/bin/python3.13 -c 'from ancs4linux.$m.main import app; app()' "\\$@"
EOF
  chmod 755 "$c"
done
"""

def _rootfs(path, dest = None, perms = None):
    return file(dest or "/" + path, src = ROOTFS + path, perms = perms)

def _libexec(name):
    return _rootfs("usr/libexec/" + name, LIBEXEC + "/" + name, perms = "0755")

def _ini(sections):
    out = []
    for name, keys in sections:
        out.append("[%s]" % name)
        out += ["%s=%s" % kv for kv in keys]
        out.append("")
    return "\n".join(out)

# Both vendors document these baseurls for openSUSE (1Password's `zypper addrepo`, Nord's
# install.sh). fspec imports each key only when its fingerprint matches.
def _repos():
    return [
        repo(
            "1password",
            url = "https://downloads.1password.com/linux/rpm/stable/x86_64",
            key = "https://downloads.1password.com/linux/keys/1password.asc",
            fingerprint = "3FEF9748469ADBE15DA7CA80AC2D62742012EA22",
        ),
        repo(
            "nordvpn",
            url = "https://repo.nordvpn.com/yum/nordvpn/centos/x86_64",
            key = "https://repo.nordvpn.com/gpg/nordvpn_public.asc",
            fingerprint = "BC5480EFEC5C081CE5BCFBE26B219E535C964CA1",
        ),
    ]

# NixOS's firewall: the ports mixins open (sshd, syncthing, LocalSend, UxPlay's fixed set, mDNS),
# with the tailnet trusted. g815.star adds Steam's and NordVPN's.
FIREWALL_TCP = [22, 7000, 7001, 7100, 22000, 53317]
FIREWALL_UDP = [5353, 6000, 6001, 7011, 22000, 53317]

def firewall_zone(tcp, udp, udp_ranges = []):
    ports = ["  <port protocol=\"tcp\" port=\"%d\"/>" % p for p in tcp]
    ports += ["  <port protocol=\"udp\" port=\"%d\"/>" % p for p in udp]
    ports += ["  <port protocol=\"udp\" port=\"%s\"/>" % r for r in udp_ranges]
    return file("/etc/firewalld/zones/public.xml", content = """<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Public</short>
""" + "\n".join(ports) + """
</zone>
""")

def _firewall(h):
    out = [
        file("/etc/firewalld/zones/trusted.xml", content = """<?xml version="1.0" encoding="utf-8"?>
<zone target="ACCEPT">
  <short>Trusted</short>
  <interface name="tailscale0"/>
</zone>
"""),
    ]
    if h.name != "g815":
        out.append(firewall_zone(FIREWALL_TCP, FIREWALL_UDP))
    return out

def _files(h):
    return [
        _rootfs("etc/ssh/authorized_keys.d/kyandesutter"),
        _rootfs("etc/ssh/sshd_config.d/10-fspec.conf"),
        _rootfs("etc/sudoers.d/10-fspec", perms = "0440"),
        # NixOS's programs.ssh.knownHosts had github; the hosts' keys stop the builder's first ssh
        # from failing host key verification.
        file("/etc/ssh/ssh_known_hosts", src = "ssh_known_hosts", perms = "0644"),
        _rootfs("usr/lib/modules-load.d/uinput.conf", "/etc/modules-load.d/uinput.conf"),
        _rootfs("usr/lib/sysusers.d/uinput.conf", "/etc/sysusers.d/uinput.conf"),
        # ddcutil's udev rule hands /dev/i2c-* to this group, which Tumbleweed does not create; its
        # buses need i2c-dev, which NixOS loaded through hardware.i2c.
        file("/etc/sysusers.d/i2c.conf", content = "g i2c - -\n"),
        file("/etc/modules-load.d/i2c-dev.conf", content = "i2c-dev\n"),
        file("/etc/udev/rules.d/70-kyan-devices.rules", content = """# dualsense-pad drives a virtual pointer; the session user writes the lightbar LEDs.
KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
ACTION=="add", SUBSYSTEM=="leds", DRIVERS=="playstation", RUN+="/usr/local/libexec/dualsense-led-perms /sys%p"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
# brightnessctl without root, as NixOS's hardware.brillo-style rule had it.
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/usr/bin/chgrp video /sys%p/brightness", RUN+="/usr/bin/chmod g+w /sys%p/brightness"
"""),
        _libexec("dualsense-led-perms"),
        # mixins/tuning/systemd-tuning.nix: cap how long a wedged unit can hold up boot or reboot.
        file("/etc/systemd/system.conf.d/10-kyan-timeouts.conf", content = "[Manager]\nDefaultTimeoutStopSec=5s\nDefaultTimeoutStartSec=15s\n"),
        file("/etc/systemd/user.conf.d/10-kyan-timeouts.conf", content = "[Manager]\nDefaultTimeoutStopSec=5s\nDefaultTimeoutStartSec=15s\n"),
        # mixins/core/boot.nix: the journal and coredumps otherwise grow to a share of /var.
        file("/etc/systemd/journald.conf.d/10-kyan.conf", content = "[Journal]\nSystemMaxUse=500M\n"),
        file("/etc/systemd/coredump.conf.d/10-kyan.conf", content = "[Coredump]\nMaxUse=256M\n"),
        # The sysctls of mixins/core/boot.nix both hosts share, and the ones NixOS sets by default
        # that Tumbleweed does not. The swap tuning differs per host (90-fspec.conf, 91-g815.conf).
        file("/etc/sysctl.d/90-kyan.conf", content = """vm.vfs_cache_pressure = 50
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 67108864
vm.dirty_writeback_centisecs = 1500
vm.max_map_count = 1048576
kernel.nmi_watchdog = 0
kernel.printk = 3
kernel.kptr_restrict = 1
fs.file-max = 2097152
fs.inotify.max_user_instances = 524288
fs.inotify.max_user_watches = 524288
net.core.default_qdisc = cake
net.core.netdev_max_backlog = 4096
net.ipv4.tcp_congestion_control = bbr
net.ipv4.ping_group_range = 0 2147483647
net.ipv6.conf.default.use_tempaddr = 2
"""),
        # THP defrag and HWP dynamic boost from mixins/core/boot.nix.
        file("/etc/tmpfiles.d/90-kyan-tuning.conf", content = "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise\nw! /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost - - - - 1\n"),
        file("/etc/udev/rules.d/60-kyan-ioschedulers.rules", content = """ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
"""),
        # mixins/hardware/mouse.nix: MX Master 3S back/forward to F13/F14, gesture button to Super.
        file("/etc/udev/hwdb.d/70-mx-master.hwdb", content = "evdev:input:b0005v046DpB034*\n KEYBOARD_KEY_90004=f13\n KEYBOARD_KEY_90005=f14\n KEYBOARD_KEY_90006=leftmeta\n"),
        # mixins/core/boot.nix earlyoom.
        file("/etc/sysconfig/earlyoom", content = "EARLYOOM_ARGS=\"-n -m 10 -s 70 --avoid '^(Hyprland|hyprland|\\.dms-wrapped|dms|\\.quickshell-wra|quickshell|qs|polkit-kde-aut|sshd|systemd)$'\"\n"),
        # mixins/core/locale.nix: en_US with British time and Spanish units, the es console keymap
        # and the Canary Islands' zone (NixOS's tzupdate only moved it when travelling).
        file("/etc/locale.conf", content = "LANG=en_US.UTF-8\nLC_TIME=en_GB.UTF-8\nLC_MONETARY=es_ES.UTF-8\nLC_PAPER=es_ES.UTF-8\nLC_MEASUREMENT=es_ES.UTF-8\n"),
        file("/etc/vconsole.conf", content = "KEYMAP=es\n"),
        file("/etc/localtime", mode = "link", src = "/usr/share/zoneinfo/Atlantic/Canary"),
        # mixins/hardware/bluetooth.nix: powered on at boot, experimental features (battery levels),
        # and HID devices that are not bonded over classic Bluetooth, like the DualSense over BLE.
        file("/etc/bluetooth/main.conf", content = "[General]\nExperimental = true\nFastConnectable = true\n\n[Policy]\nAutoEnable = true\n"),
        file("/etc/bluetooth/input.conf", content = "[General]\nClassicBondedOnly = false\n"),
        # NixOS's xdg.portal.config.hyprland: gnome-keyring's Secret portal is gated UseIn=gnome.
        file("/etc/xdg-desktop-portal/hyprland-portals.conf", content = "[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.Secret=gnome-keyring\n"),
        # Tumbleweed's vendor greetd stack plus pam_gnome_keyring, which unlocks the login
        # keyring with the login password as NixOS's services.gnome.gnome-keyring does.
        file("/etc/pam.d/greetd", content = """#%PAM-1.0
auth     requisite      pam_nologin.so
auth     include        common-auth
auth     optional       pam_gnome_keyring.so
account  include        common-account
password include        common-password
session  required       pam_loginuid.so
session  optional       pam_keyinit.so force revoke
session  include        common-session
session  optional       pam_gnome_keyring.so auto_start
"""),
        # Tumbleweed's /usr/lib/pam.d/sudo with pam_ssh_agent_auth first, as on the NixOS root.
        file("/etc/pam.d/sudo", content = """#%PAM-1.0
auth     sufficient     pam_ssh_agent_auth.so file=/etc/ssh/authorized_keys.d/%u
auth     include        common-auth
account  include        common-account
password include        common-password
session  optional       pam_keyinit.so revoke
session  include        common-session-nonlogin
"""),
        # users.users.kyandesutter.linger: the user manager (t3code, the timers) runs without a login.
        file("/var/lib/systemd/linger/kyandesutter", content = ""),
        # mixins/tuning/scx.nix: scx_bpfland (scx_lavd busy-loops a core on Arrow Lake-HX).
        file("/etc/default/scx", content = "SCX_SCHEDULER=scx_bpfland\nSCX_FLAGS=\n"),
        # ananicy-cpp reads its config and rules only from /etc/ananicy.d. The target appears when the
        # ananicy-rules pkg installs, later in the same apply.
        file("/etc/ananicy.d", mode = "link", target = "/usr/local/share/ananicy-rules/cachyos"),
        # mixins/hardware/usbflux.nix: usbmuxd over TCP 5000 for Xcode on the macbook, tailnet only
        # (the firewall trusts tailscale0 and leaves 5000 closed elsewhere).
        file("/etc/systemd/system/usbflux-export.socket", content = "[Unit]\nDescription=usbmuxd TCP export for remote Xcode\n\n[Socket]\nListenStream=5000\n\n[Install]\nWantedBy=sockets.target\n"),
        file("/etc/systemd/system/usbflux-export.service", content = """[Unit]
Description=Bridge the usbflux TCP port to usbmuxd's unix socket
Requires=usbmuxd.service
After=usbmuxd.service

[Service]
ExecStart=/usr/lib/systemd/systemd-socket-proxyd /run/usbmuxd
User=usbmux
Group=usbmux
PrivateDevices=true
ProtectHome=true
NoNewPrivileges=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
"""),
        # FormalShell's NixOS module: D-Bus access to ancs4linux for its group, and the greeter's
        # copy of the desktop's wallpaper, theme and avatar.
        file("/etc/sysusers.d/ancs4linux.conf", content = "g ancs4linux - -\n"),
        file("/etc/dbus-1/system.d/ancs4linux.conf", content = """<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="root">
    <allow own="ancs4linux.Observer"/>
    <allow send_destination="ancs4linux.Observer"/>
    <allow receive_sender="ancs4linux.Observer"/>
    <allow own="ancs4linux.Advertising"/>
    <allow send_destination="ancs4linux.Advertising"/>
    <allow receive_sender="ancs4linux.Advertising"/>
  </policy>
  <policy group="ancs4linux">
    <allow send_destination="ancs4linux.Observer"/>
    <allow receive_sender="ancs4linux.Observer"/>
    <allow send_destination="ancs4linux.Advertising"/>
    <allow receive_sender="ancs4linux.Advertising"/>
  </policy>
</busconfig>
"""),
        _libexec("formalshell-greeter-mirror"),
        _libexec("formalshell-power-poll"),
        file("/etc/systemd/system/formalshell-greeter-mirror.path", content = "[Path]\nPathChanged=/home/kyandesutter/.local/state/formalshell/state.json\nPathChanged=/home/kyandesutter/.local/state/formalshell/theme.json\nPathChanged=/home/kyandesutter/.face\n\n[Install]\nWantedBy=multi-user.target\n"),
        file("/etc/systemd/system/formalshell-greeter-mirror.service", content = "[Unit]\nDescription=Copy kyandesutter's FormalShell wallpaper and theme to the greeter\nAfter=systemd-tmpfiles-setup.service\n\n[Service]\nType=oneshot\nExecStart=" + LIBEXEC + "/formalshell-greeter-mirror\n"),
        # mixins/core/storage-gc.nix, the script ~/.config/nix/scripts/storage-gc.sh at its rev.
        _libexec("storage-gc"),
        _libexec("nordvpn-settings"),
        _libexec("tailscale-nordvpn-routing"),
    ] + _firewall(h) + _kde(h) + _formalshell_files(h)

# The e1504g's own hardware: its disk, swap, power caps and quirks.
def _e1504g_files():
    return [
        _rootfs("etc/sysctl.d/90-fspec.conf"),
        _rootfs("etc/systemd/zram-generator.conf"),
        _rootfs("etc/tuned/ppd.conf"),
        _rootfs("etc/udev/rules.d/90-e1504g.rules"),
        _rootfs("usr/lib/tuned/profiles/throughput-performance-quiet-fan/tuned.conf", "/etc/tuned/profiles/throughput-performance-quiet-fan/tuned.conf"),
        _libexec("power-cap"),
        # systemd-suspend only runs hooks from this directory. RAPL limits do not reliably survive suspend.
        file("/usr/lib/systemd/system-sleep/power-cap", perms = "0755", content = """#!/bin/sh
[ "$1" = post ] && systemctl try-restart fspec-power-cap.service
exit 0
"""),
        # The NixOS root passed these as kernel arguments (modprobe.blacklist=...).
        # The initrd loads both before this file applies; module_blacklist= on the cmdline covers that.
        file("/etc/modprobe.d/90-e1504g.conf", content = "blacklist ucsi_acpi\ninstall ucsi_acpi /bin/false\nblacklist intel_ish_ipc\ninstall intel_ish_ipc /bin/false\n"),
        # NixOS's 16 GB swapfile in @swap (NOCOW), behind zram: priority 1 under zram's 5.
        file("/etc/systemd/system/swap.mount", content = "[Unit]\nDescription=The @swap subvolume\n\n[Mount]\nWhat=UUID=1a10e345-3d66-4bde-9f6b-55d43e6f7e0d\nWhere=/swap\nType=btrfs\nOptions=subvol=@swap,noatime\n\n[Install]\nWantedBy=local-fs.target\n"),
        file("/etc/systemd/system/swap-swapfile.swap", content = "[Unit]\nDescription=Swapfile in @swap\nRequires=swap.mount\nAfter=swap.mount\n\n[Swap]\nWhat=/swap/swapfile\nPriority=1\n\n[Install]\nWantedBy=swap.target\n"),
        # mixins/core/networking.nix: Google DNS for every connection, over what DHCP hands out.
        # The g815 runs systemd-resolved instead (g815.star).
        file("/etc/NetworkManager/conf.d/90-kyan-dns.conf", content = "[global-dns-domain-*]\nservers=8.8.8.8,8.8.4.4\n"),
        # nixos-hardware's asus-battery with chargeUpto = 100.
        file("/etc/tmpfiles.d/90-e1504g-battery.conf", content = "w /sys/class/power_supply/BAT?/charge_control_end_threshold - - - - 100\n"),
        # mixins/tuning/oomd.nix: Fedora's desktop policy.
        file("/etc/systemd/oomd.conf.d/10-kyan.conf", content = "[OOM]\nDefaultMemoryPressureDurationSec=20s\n"),
        file("/etc/systemd/system/-.slice.d/10-oomd.conf", content = "[Slice]\nManagedOOMSwap=kill\n"),
        file("/etc/systemd/user/app.slice.d/10-oomd.conf", content = "[Slice]\nManagedOOMMemoryPressure=kill\nManagedOOMMemoryPressureLimit=50%\n"),
    ]

# mixins/desktop/kde: Plasma as a second session, with switches between it and Hyprland that log
# straight into the other one. On a gaming host it is the gaming desktop.
def _kde(h):
    gaming = h.name == "g815"
    sessions = {"plasma": "Gaming Mode" if gaming else "Switch to Plasma", "hyprland-uwsm": "Switch to Hyprland"}
    icons = {"plasma": "steam" if gaming else "kde", "hyprland-uwsm": "hyprland"}
    units = ", ".join(['"session-switch@%s.service"' % s for s in sessions])
    out = [
        _libexec("session-switch-run"),
        _libexec("session-switch-login"),
        _rootfs("usr/libexec/session-switch", "/usr/local/bin/session-switch", perms = "0755"),
        file("/etc/systemd/system/session-switch@.service", content = "[Unit]\nDescription=Log into the %i session\n\n[Service]\nType=oneshot\nExecStart=" + LIBEXEC + "/session-switch-run %i\n"),
        file("/etc/tmpfiles.d/session-switch.conf", content = "d /run/session-switch 0755 root root -\nf /run/session-switch/greetd.run 0644 root root -\n"),
        file("/etc/polkit-1/rules.d/50-session-switch.rules", content = """polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.systemd1.manage-units" &&
      subject.user == "kyandesutter" &&
      [""" + units + """].indexOf(action.lookup("unit")) >= 0 &&
      action.lookup("verb") == "start") {
    return polkit.Result.YES;
  }
});
"""),
        file(GREETER_SESSIONS + "/plasma.desktop", content = """[Desktop Entry]
Name=Plasma (Wayland)
Comment=Plasma by KDE
Exec=/usr/bin/startplasma-wayland
TryExec=/usr/bin/startplasma-wayland
DesktopNames=KDE
Type=Application
"""),
        file("/usr/local/share/wallpapers/steam-classic.png", src = ROOTFS + "usr/local/share/wallpapers/steam-classic.png"),
    ]
    for s, label in sessions.items():
        out.append(file("/usr/local/share/applications/session-switch-%s.desktop" % s, content = """[Desktop Entry]
Type=Application
Name=%s
Exec=/usr/local/bin/session-switch %s
Icon=%s
Categories=System;
""" % (label, s, icons[s])))
    return out

# The host keyboard, which the greeter's sway carries so the password prompt matches the session
# (home/.config/hypr/hyprland.lua sets the same layout).
KEYBOARD = {"layout": "es", "options": "caps:escape"}

# The greeter offers only these sessions, so a pick remembered from Tumbleweed's plain
# hyprland.desktop (bare Hyprland, no graphical-session.target, no user units) cannot win.
# The entry is NixOS's programs.hyprland.withUWSM one.
GREETER_SESSIONS = "/etc/formalshell-greeter/wayland-sessions"
# A greeter without the session picker starts greeter.sessionCommand instead.
UWSM_HYPRLAND = "/usr/bin/uwsm start -e -D Hyprland hyprland.desktop"

# What `formalshell install --yes` writes on a distro with common-auth, greetd and sway
# (crates/formalshell-rs/src/install.rs at the pinned rev), with the greeter from the fspec store,
# plus the keyboard in sway's input block and the uwsm session.
def _formalshell_files(h):
    return [
        file("/etc/pam.d/formalshell-lock", content = "#%PAM-1.0\n@include common-auth\n@include common-account\n"),
        file("/etc/tmpfiles.d/formalshell-greeter.conf", content = "d /run/formalshell-greeter 0700 greeter greeter -\nd /var/lib/formalshell-greeter 0700 greeter greeter -\n"),
        # The runfile and initial_session are mixins/desktop/kde's session switch.
        file("/etc/greetd/config.toml", content = '[terminal]\nvt = 1\n\n[general]\nrunfile = "/run/session-switch/greetd.run"\n\n[default_session]\ncommand = "/etc/greetd/formalshell-session.sh"\nuser = "greeter"\n\n[initial_session]\ncommand = "' + LIBEXEC + '/session-switch-login"\nuser = "kyandesutter"\n'),
        file("/etc/greetd/formalshell-session.sh", perms = "0755", content = """#!/bin/sh
# Written by `formalshell install`; `formalshell update` rewrites it.
export XDG_RUNTIME_DIR=/run/formalshell-greeter
export HOME=/var/lib/formalshell-greeter
# pam_env's xdg.conf derives these from the greeter account's passwd home, /var/lib/greetd, so
# the greeter would read its settings.json from there.
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME
export XDG_SESSION_TYPE=wayland
printf 'output * bg #000000 solid_color\\ninput type:keyboard {\\n  xkb_layout """ + KEYBOARD["layout"] + """\\n  xkb_options """ + KEYBOARD["options"] + """\\n}\\n' > "$HOME/sway.conf"
sway --config "$HOME/sway.conf" &
compositor=$!
for _ in $(seq 100); do
  socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -print -quit 2>/dev/null)
  [ -n "$socket" ] && break
  sleep 0.1
done
export WAYLAND_DISPLAY=$(basename "$socket")
""" + PKG_BIN + """/formalshell-greeter
kill "$compositor" 2>/dev/null
wait "$compositor" 2>/dev/null
"""),
        file(GREETER_SESSIONS + "/hyprland-uwsm.desktop", content = """[Desktop Entry]
Name=Hyprland (uwsm-managed)
Comment=An intelligent dynamic tiling Wayland compositor
Exec=""" + UWSM_HYPRLAND + """
TryExec=/usr/bin/uwsm
DesktopNames=Hyprland
Type=Application
"""),
        file("/var/lib/formalshell-greeter/.config/formalshell/settings.json", content = {"greeter": {"sessionDirs": [GREETER_SESSIONS], "sessionCommand": [UWSM_HYPRLAND]}}),
    ]

# What no Tumbleweed repo carries: vendor repos, upstream releases, and source builds where upstream
# publishes no Linux binary.
def _pkgs():
    return [
        # The CLI's %post runs groupadd, so it installs after shadow, in the packages phase.
        pkg("1password", source = zypper(repo = "1password")),
        pkg("1password-cli", source = zypper(repo = "1password")),
        # From Nord's repo, which a filtering network can block; then it and its units wait for
        # the next apply. The rpm's postinstall enables the three units.
        pkg(
            "nordvpn",
            source = zypper(repo = "nordvpn"),
            services = [service("nordvpnd.socket"), service("nordvpnd"), service("nordvpnd-killswitch")],
        ),
        # Data-only: the cursor theme and the font streamdeck-keys draws with.
        pkg("bibata", version = "2.0.7", source = github("ful1e5/Bibata_Cursor", asset = "Bibata-Modern-Classic.tar.xz"), share = {"icons/Bibata-Modern-Classic": "Bibata-Modern-Classic"}),
        # session.nix's icon theme, nixpkgs' tag 2026-08-10. No release ships the built tree; the
        # installer only copies, links and builds the icon caches. Colloid-Dark inherits Colloid.
        pkg(
            "colloid-icon-theme",
            source = git("https://github.com/vinceliuice/Colloid-icon-theme", rev = "e3a8f89fac888af715233f8f8ef0a5b1e350f0dd", image = TUMBLEWEED, deps = ["bash", "sed", "findutils", "gtk3-tools"]),
            build = ["sh", "-c", "cd \"$FSPEC_SRC\" && mkdir -p \"$FSPEC_OUT/icons\" && bash ./install.sh -d \"$FSPEC_OUT/icons\" -s default -t default"],
            share = {"icons/Colloid": "icons/Colloid", "icons/Colloid-Light": "icons/Colloid-Light", "icons/Colloid-Dark": "icons/Colloid-Dark"},
        ),
        # FormalShell's gtk template sets gtk-theme to adw-gtk3-dark; without it GTK3 apps are light.
        pkg("adw-gtk3", version = "6.5", source = github("lassekongo83/adw-gtk3", asset = "adw-gtk3v*.tar.xz"), share = {"themes/adw-gtk3": "adw-gtk3", "themes/adw-gtk3-dark": "adw-gtk3-dark"}),
        pkg("geist-mono-nerd-font", version = "3.4.0", source = github("ryanoasis/nerd-fonts", asset = "GeistMono.tar.xz"), share = {"fonts/GeistMonoNerdFont": "."}),
        # The rev ~/.config/nix's flake.lock pins, so both roots run the same shell. dev/tarball.sh
        # is upstream's release build: it installs its own deps on bookworm, whose glibc it targets.
        pkg(
            "formalshell",
            source = git("https://github.com/FormalSnake/FormalShell", rev = "34a0139d7c6a5e453c52485df2298fe55cc74a87", image = "docker.io/library/debian:bookworm"),
            build = ["sh", "-c", "WORK=\"$FSPEC_OUT.work\" bash \"$FSPEC_SRC/dev/tarball.sh\" \"$FSPEC_OUT.tar\" && tar -xzf \"$FSPEC_OUT.tar\"/formalshell-*-linux.tar.gz -C \"$FSPEC_OUT\" && rm -rf \"$FSPEC_OUT.work\" \"$FSPEC_OUT.tar\""],
        ),
        pkg("herdr", version = "0.9.3", source = github("ogulcancelik/herdr", asset = "herdr-linux-*")),
        # helium-wrapper sets LD_LIBRARY_PATH to its own directory, so `helium` is the wrapper.
        pkg("helium", version = "0.19.4.1", source = github("imputnet/helium-linux", asset = "helium-*_linux.tar.xz"), links = {"helium": "helium-wrapper"}),
        pkg("matugen", version = "4.2.0", source = github("InioX/matugen", asset = "matugen-*-x86_64.tar.gz")),
        pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "ca70d10d27e8fc1a0f0afc5c7d691887cb2c4020")),
        pkg("wl-clip-persist", source = git("https://github.com/Linus789/wl-clip-persist", rev = "v0.5.0")),
        pkg("wl-gammarelay-rs", source = git("https://github.com/MaxVerevkin/wl-gammarelay-rs", rev = "v1.0.1")),
        # omarchy-pods 1.0.2 (the commit its annotated tag points at) with the three patches the nix
        # build carries; the daemon lives in daemon/.
        pkg(
            "librepods",
            source = git(
                "https://github.com/thisisgm/omarchy-pods",
                rev = "307c5a6d2109f088d8e6a558c933ebe4f6b1db01",
                image = TUMBLEWEED,
                deps = ["cmake", "make", "gcc-c++", "pkgconf", "qt6-base-devel", "qt6-declarative-devel", "qt6-quickcontrols2-devel", "qt6-connectivity-devel", "qt6-tools-devel", "qt6-linguist-devel", "libopenssl-devel", "libpulse-devel"],
            ),
            patches = glob("patches/librepods-*.patch"),
            build = ["sh", "-c", "cmake -S \"$FSPEC_SRC/daemon\" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=\"$FSPEC_OUT\" && cmake --build build -j && cmake --install build"],
        ),
        # nvim's nil (tag 2026-07-23) publishes no Linux binaries; its build script asks nix for its
        # builtins. Tumbleweed's nix 2.35.3 segfaults in a container, even on --version, so this
        # builds on Debian, whose cargo is older than nil's rust-version 1.89.
        pkg("nil", source = git("https://github.com/oxalica/nil", rev = "dbbb5c24f9215476992aa1bd305f8e5398e89654", image = "docker.io/library/debian:trixie", deps = ["rustup", "ca-certificates", "gcc", "libc6-dev", "nix-bin"]), build = ["sh", "-c", NIL_BUILD], bins = ["nil"]),
        # FormalShell's iPhone panel: ancs4linux at the rev and patches FormalShell's nix/ancs4linux.nix
        # builds, on Tumbleweed's python and its dasbus, gobject and typer.
        pkg(
            "ancs4linux",
            source = git("https://github.com/pzmarzly/ancs4linux", rev = "138451721ff10d3c8634b32656ae3d38a99b9163", image = TUMBLEWEED, deps = ["python313-pip", "python313-hatchling"]),
            patches = ["patches/ancs4linux-0-metadata.patch", "patches/ancs4linux-authorize.patch"],
            build = ["sh", "-c", ANCS4LINUX_BUILD],
        ),
        # ananicy-cpp with CachyOS's rules, as services.ananicy has them; neither is packaged.
        # Past v1.2.0: that tag misses the headers glibc 2.42 no longer pulls in.
        pkg(
            "ananicy-cpp",
            source = git("https://gitlab.com/ananicy-cpp/ananicy-cpp", rev = "3554447c1ca495478bd00e002078847dfd2205d6", image = TUMBLEWEED, deps = ["cmake", "make", "gcc-c++", "pkgconf", "fmt-devel", "spdlog-devel", "nlohmann_json-devel", "systemd-devel", "pcre2-devel"]),
            build_flags = ["-DENABLE_SYSTEMD=ON", "-DENABLE_REGEX_SUPPORT=ON", "-DUSE_EXTERNAL_FMTLIB=ON", "-DUSE_EXTERNAL_JSON=ON", "-DUSE_EXTERNAL_SPDLOG=ON", "-DVERSION=1.2.0"],
            bins = ["ananicy-cpp"],
        ),
        pkg("ananicy-rules", source = url("https://github.com/CachyOS/ananicy-rules/archive/03ef03fbf7e834385377432ccecaedd32e3414bb.tar.gz"), share = {"ananicy-rules/cachyos": "ananicy-rules-03ef03fbf7e834385377432ccecaedd32e3414bb"}),
        # The Plasma theme kde.nix applies on first login, and its font.
        pkg(
            "steamed",
            source = url("https://github.com/gaspar-of-time/Steamed/archive/14e8a1c0db188870ab3ac2059dbf941fad9c3065.tar.gz"),
            share = {
                "color-schemes/Steamed.colors": STEAMED + "/color-schemes/Steamed.colors",
                "aurorae/themes/Steamed": STEAMED + "/aurorae/themes/Steamed",
                "plasma/desktoptheme/Steamed": STEAMED + "/plasma/desktoptheme/Steamed",
                "plasma/look-and-feel/Steamed": STEAMED + "/plasma/look-and-feel/Steamed",
                "fonts/Steamed": STEAMED + "/fonts",
            },
        ),
    ]

def _services(h):
    return [
        service("tailscaled"),
        service("sshd"),
        service("bluetooth"),
        service("chronyd"),
        service("irqbalance"),
        service("avahi-daemon"),
        service("cups-browsed"),
        service("earlyoom"),
        service("firewalld"),
        service("scx"),
        service("usbflux-export.socket"),
        service("formalshell-greeter-mirror.path"),
        service("hwdb", exec = "/usr/bin/systemd-hwdb update", description = "Compile /etc/udev/hwdb.d", systemd = {"Type": "oneshot", "RemainAfterExit": True}),
        # Tumbleweed boots to multi-user.target, under which greetd never starts.
        service("greetd", display_manager = True),
        service("tuned"),
        service("tuned-ppd"),
        service("docker.socket"),
        service("syncthing@kyandesutter"),
        service(
            "formalshell-power-poll",
            exec = LIBEXEC + "/formalshell-power-poll",
            restart = "on_failure",
            description = "FormalShell USB-C and CPU power readings for the Power panel",
            systemd = {"RuntimeDirectory": "formalshell", "RuntimeDirectoryMode": "0755"},
        ),
        service(
            "ancs4linux-observer",
            exec = PKG_BIN + "/ancs4linux-observer",
            description = "ancs4linux Observer daemon (ANCS notifications over BLE)",
            systemd = {"Type": "dbus", "BusName": "ancs4linux.Observer", "unit": {"Requires": "bluetooth.service", "After": "bluetooth.service", "ConditionPathExists": PKG_BIN + "/ancs4linux-observer"}},
        ),
        service(
            "ancs4linux-advertising",
            exec = PKG_BIN + "/ancs4linux-advertising",
            description = "ancs4linux Advertising daemon (BLE pairing)",
            systemd = {"Type": "dbus", "BusName": "ancs4linux.Advertising", "unit": {"Requires": "bluetooth.service", "After": "bluetooth.service", "ConditionPathExists": PKG_BIN + "/ancs4linux-advertising"}},
        ),
        # ananicy-cpp's own unit, with its store path.
        service(
            "ananicy-cpp",
            exec = PKG_BIN + "/ananicy-cpp start",
            restart = "always",
            description = "Ananicy-Cpp - ANother Auto NICe daemon in C++",
            systemd = {
                "ExecReload": PKG_BIN + "/ananicy-cpp --reload",
                "Nice": -5,
                "SuccessExitStatus": 143,
                "OOMScoreAdjust": -999,
                "RestartSec": 10,
                "MemoryHigh": "16M",
                "MemoryMax": "64M",
                "unit": {"After": "local-fs.target", "ConditionPathExists": PKG_BIN + "/ananicy-cpp"},
            },
        ),
        service(
            "nordvpn-settings",
            exec = LIBEXEC + "/nordvpn-settings",
            description = "Enforce declarative NordVPN settings (allowlist, LAN discovery)",
            systemd = {"Type": "oneshot", "RemainAfterExit": True, "Group": "nordvpn", "Environment": "HOME=/root", "unit": {"After": "nordvpnd.service", "Requires": "nordvpnd.service"}},
        ),
        service(
            "tailscale-nordvpn-routing",
            exec = LIBEXEC + "/tailscale-nordvpn-routing",
            description = "Route Tailscale's marked underlay through the NordVPN tunnel",
            systemd = {"Type": "oneshot", "RemainAfterExit": True, "unit": {"After": ["nordvpnd.service", "tailscaled.service"], "Wants": "tailscaled.service"}},
        ),
        # virtualisation.docker.autoPrune.
        timer("docker-prune", exec = "/usr/bin/docker system prune -f --all --filter until=72h", schedule = "0 0 * * *"),
        # nix.gc's daily run, for fspec's own generations and store.
        timer("fspec-gc", exec = "/usr/local/bin/fspec gc --older-than 14d", schedule = "30 0 * * *"),
        timer("storage-gc", exec = LIBEXEC + "/storage-gc --apply --prune-worktrees", schedule = "0 12 * * *", user = True),
    ]

def _e1504g_services():
    return [
        service("swap.mount"),
        service("swap-swapfile.swap"),
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

def system(h):
    out = _repos() + _files(h) + _pkgs() + _services(h)
    if h.name == "e1504g":
        out += _e1504g_files() + _e1504g_services()
    return out
