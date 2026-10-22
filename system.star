# The e1504g's openSUSE Tumbleweed root: the packages, vendor repos, system files and services the
# NixOS root has, by Tumbleweed's own package names. Tools Tumbleweed does not carry come from
# their upstream releases through the fspec store (/opt/fspec/current/bin).

ROOTFS = "e1504g/rootfs/"
PKG_BIN = "/opt/fspec/current/bin"

DESKTOP = [
    "hyprland", "uwsm", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "greetd", "sway",
    "swayidle", "wl-clipboard", "grim", "slurp", "wf-recorder", "brightnessctl", "ddcutil", "wlsunset",
    "cava", "playerctl", "mpv", "qrencode", "wtype", "tesseract-ocr", "tesseract-ocr-traineddata-eng",
    "xdg-utils", "evolution-data-server", "geoclue2", "libgtk-4-1", "libadwaita-1-0", "python313-gobject",
    "hyprlock", "hypridle", "hyprpicker", "ghostty", "adwaita-icon-theme", "libhidapi-hidraw0",
    "python313-evdev", "python313-FontTools", "python313-Pillow", "python313-streamdeck", "xrdb",
    "gnome-keyring", "gvfs", "tumbler", "nautilus", "qt6ct", "qt5ct", "dconf", "glib2-tools",
    "adwaita-fonts", "google-noto-sans-symbols2-fonts", "google-noto-coloremoji-fonts",
    "google-noto-sans-cjk-fonts", "liberation-fonts", "easyeffects", "pipewire-tools", "wvkbd",
    "dualsensectl", "flatpak",
    # The mimeapps.list targets; Apostrophe comes from Flathub.
    "papers", "loupe", "gnome-text-editor", "celluloid",
    # Messages: video thumbnails through ffmpeg, notifications, its Vulkan renderer and media playback.
    "ffmpeg-8", "libnotify4", "libvulkan1", "gstreamer-plugins-good", "gstreamer-plugins-bad",
    "gstreamer-plugins-libav",
    # What the fspec-installed librepods, kopuz, formalmusic and terminal-browser (Electron) load.
    "libQt6Core6", "libQt6DBus6", "libQt6Bluetooth6", "libpulse0", "libwebkit2gtk-4_1-0", "libgtk-3-0",
    "libsoup-3_0-0", "glib-networking", "libasound2", "xdotool", "libayatana-appindicator3-1", "libopus0",
    "libgbm1", "libxkbfile1", "libgtksourceview-5-0", "mozilla-nss", "libatk-bridge-2_0-0", "libcups2",
    "libXcomposite1", "libXdamage1", "libXrandr2", "libsecret-1-0", "libpipewire-0_3-0", "libxshmfence1",
]

SYSTEM = [
    "tailscale", "syncthing", "docker", "tuned", "tuned-ppd", "fish", "sshfs", "usbmuxd",
    "imobiledevice-tools", "ifuse", "smartmontools", "pam_ssh_agent_auth",
    # The wheel, audio, video and input groups the user joins.
    "system-group-wheel", "system-group-hardware",
    # fish's fish_command_not_found runs openSUSE's command-not-found, which cnf ships.
    "cnf",
    # A remote `fspec apply` unpacks the shipped spec with tar, which the base pattern lacks.
    "tar",
    # From the vendor repos below.
    "1password", "1password-cli", "nordvpn",
]

CLI = [
    "neovim", "ripgrep", "fd", "bat", "btop", "zoxide", "fzf", "git", "git-lfs", "gh", "jq", "tmux",
    "direnv", "just", "fastfetch", "lsd", "lazygit", "yazi", "mosh", "wget", "ImageMagick", "chafa",
    "lua54", "bun",
    # nvim: npm-sourced language servers run on node and install with npm; nvim-treesitter compiles
    # its parsers with gcc; snacks converts PDFs with ghostscript; rust-analyzer reads rust-src.
    "nodejs24", "npm24", "gcc", "ghostscript", "rust-src", "taplo",
]

PACKAGES = DESKTOP + SYSTEM + CLI

def _rootfs(path, dest = None, perms = None):
    return file(dest or "/" + path, src = ROOTFS + path, perms = perms)

# zypper reads these before the packages install; both vendors document the same baseurl for
# openSUSE (1Password's `zypper addrepo`, Nord's install.sh).
def _repos():
    return [
        file("/etc/zypp/repos.d/1password.repo", content = """[1password]
name=1Password
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
"""),
        file("/etc/zypp/repos.d/nordvpn.repo", content = """[nordvpn]
name=NordVPN
baseurl=https://repo.nordvpn.com/yum/nordvpn/centos/$basearch
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://repo.nordvpn.com/gpg/nordvpn_public.asc
"""),
    ]

def _files():
    return [
        _rootfs("etc/ssh/authorized_keys.d/kyandesutter"),
        _rootfs("etc/ssh/sshd_config.d/10-fspec.conf"),
        _rootfs("etc/sudoers.d/10-fspec", perms = "0440"),
        _rootfs("etc/sysctl.d/90-fspec.conf"),
        _rootfs("etc/systemd/zram-generator.conf"),
        _rootfs("etc/tuned/ppd.conf"),
        _rootfs("etc/udev/rules.d/90-e1504g.rules"),
        _rootfs("usr/lib/modules-load.d/uinput.conf", "/etc/modules-load.d/uinput.conf"),
        _rootfs("usr/lib/sysusers.d/uinput.conf", "/etc/sysusers.d/uinput.conf"),
        _rootfs("usr/lib/tuned/profiles/throughput-performance-quiet-fan/tuned.conf", "/etc/tuned/profiles/throughput-performance-quiet-fan/tuned.conf"),
        file("/etc/udev/rules.d/70-kyan-devices.rules", content = """# dualsense-pad drives a virtual pointer; the session user writes the lightbar LEDs.
KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
ACTION=="add", SUBSYSTEM=="leds", DRIVERS=="playstation", RUN+="/usr/local/libexec/dualsense-led-perms /sys%p"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
"""),
        _rootfs("usr/libexec/dualsense-led-perms", "/usr/local/libexec/dualsense-led-perms", perms = "0755"),
        _rootfs("usr/libexec/power-cap", "/usr/local/libexec/power-cap", perms = "0755"),
        # systemd-suspend only runs hooks from this directory. RAPL limits do not reliably survive suspend.
        file("/usr/lib/systemd/system-sleep/power-cap", perms = "0755", content = """#!/bin/sh
[ "$1" = post ] && systemctl try-restart fspec-power-cap.service
exit 0
"""),
        # The NixOS root passed these as kernel arguments (modprobe.blacklist=...).
        file("/etc/modprobe.d/90-e1504g.conf", content = "blacklist ucsi_acpi\nblacklist intel_ish_ipc\n"),
        # Tumbleweed's /usr/lib/pam.d/sudo with pam_ssh_agent_auth first, as on the NixOS root.
        file("/etc/pam.d/sudo", content = """#%PAM-1.0
auth     sufficient     pam_ssh_agent_auth.so file=/etc/ssh/authorized_keys.d/%u
auth     include        common-auth
account  include        common-account
password include        common-password
session  optional       pam_keyinit.so revoke
session  include        common-session-nonlogin
"""),
    ] + _formalshell_files()

# What `formalshell install --yes` writes on a distro with common-auth, greetd and sway
# (crates/formalshell-rs/src/install.rs at the pinned rev), with the greeter from the fspec store.
def _formalshell_files():
    return [
        file("/etc/pam.d/formalshell-lock", content = "#%PAM-1.0\n@include common-auth\n@include common-account\n"),
        file("/etc/tmpfiles.d/formalshell-greeter.conf", content = "d /run/formalshell-greeter 0700 greeter greeter -\nd /var/lib/formalshell-greeter 0700 greeter greeter -\n"),
        file("/etc/greetd/config.toml", content = '[terminal]\nvt = 1\n\n[default_session]\ncommand = "/etc/greetd/formalshell-session.sh"\nuser = "greeter"\n'),
        file("/etc/greetd/formalshell-session.sh", perms = "0755", content = """#!/bin/sh
# Written by `formalshell install`; `formalshell update` rewrites it.
export XDG_RUNTIME_DIR=/run/formalshell-greeter
export HOME=/var/lib/formalshell-greeter
export XDG_SESSION_TYPE=wayland
printf 'output * bg #000000 solid_color\\n' > "$HOME/sway.conf"
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
    ]

# The image's build stages, as store packages at the versions the NixOS root runs.
def _pkgs():
    return [
        # v0.2.0 is the newest release; NixOS runs e8a800d, which has no release tarball.
        pkg("formalshell", version = "0.2.0", source = github("FormalSnake/FormalShell", asset = "formalshell-*-linux.tar.gz")),
        pkg("herdr", version = "0.9.3", source = github("ogulcancelik/herdr", asset = "herdr-linux-*")),
        # helium-wrapper sets LD_LIBRARY_PATH to its own directory, so `helium` is the wrapper.
        pkg("helium", version = "0.19.4.1", source = github("imputnet/helium-linux", asset = "helium-*_linux.tar.xz"), links = {"helium": "helium-wrapper"}),
        pkg("matugen", version = "4.2.0", source = github("InioX/matugen", asset = "matugen-*-x86_64.tar.gz")),
        pkg("uv", version = "0.13.0", source = aqua("astral-sh/uv")),
        pkg("meshtop", source = git("https://github.com/FormalSnake/meshtop", rev = "ca70d10d27e8fc1a0f0afc5c7d691887cb2c4020")),
        pkg("wl-clip-persist", source = git("https://github.com/Linus789/wl-clip-persist", rev = "v0.5.0")),
        pkg("wl-gammarelay-rs", source = git("https://github.com/MaxVerevkin/wl-gammarelay-rs", rev = "v1.0.1")),
        # omarchy-pods 1.0.2 (the commit its annotated tag points at) with the three patches the nix
        # build carries; the daemon lives in daemon/.
        pkg(
            "librepods",
            source = git("https://github.com/thisisgm/omarchy-pods", rev = "307c5a6d2109f088d8e6a558c933ebe4f6b1db01"),
            patches = glob("patches/librepods-*.patch"),
            build = ["sh", "-c", "cmake -S \"$FSPEC_SRC/daemon\" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=\"$FSPEC_OUT\" && cmake --build build -j && cmake --install build"],
        ),
        # nvim's nil (tag 2026-07-23) and gopls publish no Linux binaries.
        pkg("nil", source = git("https://github.com/oxalica/nil", rev = "dbbb5c24f9215476992aa1bd305f8e5398e89654"), bins = ["nil"]),
        pkg("gopls", source = git("https://github.com/golang/tools", rev = "gopls/v0.23.0"), build = ["sh", "-c", "cd \"$FSPEC_SRC/gopls\" && GOBIN=\"$FSPEC_OUT/bin\" go install -trimpath ."]),
    ]

def _services():
    return [
        service("tailscaled"),
        service("sshd"),
        service("greetd"),
        service("tuned"),
        service("tuned-ppd"),
        service("docker.socket"),
        service("syncthing@kyandesutter"),
        # The rpm's postinstall enables these three.
        service("nordvpnd.socket"),
        service("nordvpnd"),
        service("nordvpnd-killswitch"),
        service(
            "power-cap",
            exec = "/usr/local/libexec/power-cap",
            restart = "always",
            description = "Per-profile RAPL package power caps (quiet fans)",
            systemd = {
                "RestartSec": 2,
                # A restarted tuned-ppd comes up in its default profile without a PropertiesChanged signal.
                "unit": {"After": "tuned-ppd.service", "Wants": "tuned-ppd.service", "PartOf": "tuned-ppd.service"},
            },
        ),
    ]

def system(h = None):
    return _repos() + _files() + _pkgs() + _services()
