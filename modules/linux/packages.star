load("//modules/tools.star", "cli")

# Tumbleweed packages both Linux hosts install, beside modules/tools.star's. A `!name` removes one.

# binutils: Hyprland runs `nm` on itself to find the functions a plugin hooks (hyprexpo).
DESKTOP = [
    "hyprland", "binutils", "uwsm", "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "greetd", "sway", "swaybg",
    "swayidle", "wl-clipboard", "grim", "slurp", "wf-recorder", "brightnessctl", "ddcutil", "wlsunset",
    "cava", "playerctl", "mpv", "qrencode", "wtype", "tesseract-ocr", "tesseract-ocr-traineddata-eng",
    "xdg-utils", "evolution-data-server", "geoclue2", "libgtk-4-1", "libadwaita-1-0", "python313-gobject",
    "hyprlock", "hypridle", "hyprpicker", "ghostty", "adwaita-icon-theme", "libhidapi-hidraw0",
    "python313-evdev", "python313-FontTools", "python313-Pillow", "xrdb", "gnome-keyring",
    "gnome-keyring-pam", "hyprland-guiutils", "apparmor-abstractions", "gvfs", "tumbler", "nautilus",
    "qt6ct", "qt5ct", "dconf", "gsettings-backend-dconf", "glib2-tools", "adwaita-fonts",
    "google-noto-sans-symbols2-fonts", "google-noto-coloremoji-fonts", "google-noto-sans-cjk-fonts",
    "liberation-fonts", "easyeffects", "pipewire-tools", "wvkbd", "dualsensectl", "flatpak",
    "papers", "loupe", "gnome-text-editor", "celluloid",
    "patterns-kde-kde_plasma", "kscreen6", "kf6-kconfig",
]

# What the store's apps load at runtime: Messages, librepods, kopuz, formalmusic, the Electron
# apps, ancs4linux and ananicy-cpp.
RUNTIME = [
    "ffmpeg-8", "libnotify4", "libvulkan1", "gstreamer-plugins-good", "gstreamer-plugins-bad",
    "gstreamer-plugins-libav", "libQt6Core6", "libQt6DBus6", "libQt6Bluetooth6", "libpulse0",
    "libwebkit2gtk-4_1-0", "libgtk-3-0", "libsoup-3_0-0", "glib-networking", "libasound2", "xdotool",
    "libayatana-appindicator3-1", "libopus0", "libgbm1", "libxkbfile1", "libgtksourceview-5-0",
    "mozilla-nss", "libatk-bridge-2_0-0", "libcups2", "libXcomposite1", "libXdamage1", "libXrandr2",
    "libsecret-1-0", "secret-tool", "libpipewire-0_3-0", "libxshmfence1", "python313-dasbus",
    "python313-typer", "libfmt12", "libspdlog1_17", "libpcre2-8-0", "libbpf1", "libelf1",
]

SYSTEM = [
    # The minimal base ships these two, which conflict with tuned-ppd and with fish's gzip.
    "!power-profiles-daemon", "!busybox-gzip",
    "syncthing", "docker", "tuned", "tuned-ppd", "sshfs", "usbmuxd",
    "imobiledevice-tools", "ifuse", "smartmontools", "pam_ssh_agent_auth", "sof-firmware", "bluez",
    "chrony", "fwupd", "glibc-locale", "system-group-wheel", "system-group-hardware", "cnf",
    # A remote apply unpacks the spec with tar.
    "tar", "shadow",
    "intel-media-driver", "libva-utils", "irqbalance", "avahi", "nss-mdns", "cups-filters-cups-browsed",
    "traceroute", "mtr", "usbutils", "alsa-utils", "i2c-tools", "gnome-control-center", "earlyoom",
    "scx", "firewalld", "python313",
]

CLI = [
    "gcc", "tree-sitter", "make", "pkgconf",
    # Not the distro's rust-src: it pulls in a toolchain that conflicts with rustup.
    "rustup",
]

PACKAGES = DESKTOP + RUNTIME + SYSTEM + CLI + cli("linux")
