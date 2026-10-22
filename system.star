# The e1504g's openSUSE Tumbleweed root: the packages, vendor repos, system files and services the
# NixOS root has, by Tumbleweed's own package names. Tools Tumbleweed does not carry come from
# their upstream releases through the fspec store (/opt/fspec/current/bin).

ROOTFS = "e1504g/rootfs/"
PKG_BIN = "/opt/fspec/current/bin"
# git() builds that link system libraries run in the target's own distro, so the sonames match.
TUMBLEWEED = "registry.opensuse.org/opensuse/tumbleweed"

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
    "libXcomposite1", "libXdamage1", "libXrandr2", "libsecret-1-0", "libpipewire-0_3-0", "libxshmfence1",
]

SYSTEM = [
    # The minimal base ships power-profiles-daemon and busybox-gzip, which conflict with tuned-ppd
    # and with the gzip fish needs.
    "tailscale", "syncthing", "docker", "tuned", "tuned-ppd", "!power-profiles-daemon", "fish", "!busybox-gzip", "sshfs", "usbmuxd",
    "imobiledevice-tools", "ifuse", "smartmontools", "pam_ssh_agent_auth",
    # The rest of ~/.config/nix's core and hardware mixins: the Tiger Lake DSP's audio firmware
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
        # blacklist alone does not stop a modalias or explicit load, so each module also gets an install stub.
        file("/etc/modprobe.d/90-e1504g.conf", content = "blacklist ucsi_acpi\ninstall ucsi_acpi /bin/false\nblacklist intel_ish_ipc\ninstall intel_ish_ipc /bin/false\n"),
        # mixins/core/boot.nix and plymouth: mitigations off, VT-d on, quiet boot. fspec-esp-sync
        # copies this line into each Tumbleweed entry.
        file("/etc/kernel/cmdline", content = "root=UUID=1a10e345-3d66-4bde-9f6b-55d43e6f7e0d rootflags=subvol=@tumbleweed,noatime,compress=zstd:1 rw panic=10 rd.shell=0 rd.emergency=reboot mitigations=off intel_iommu=on quiet udev.log_level=3\n"),
        # mixins/tuning/systemd-tuning.nix: cap how long a wedged unit can hold up boot or reboot.
        file("/etc/systemd/system.conf.d/10-kyan-timeouts.conf", content = "[Manager]\nDefaultTimeoutStopSec=5s\nDefaultTimeoutStartSec=15s\n"),
        file("/etc/systemd/user.conf.d/10-kyan-timeouts.conf", content = "[Manager]\nDefaultTimeoutStopSec=5s\nDefaultTimeoutStartSec=15s\n"),
        # mixins/core/boot.nix: the journal and coredumps otherwise grow to a share of /var.
        file("/etc/systemd/journald.conf.d/10-kyan.conf", content = "[Journal]\nSystemMaxUse=500M\n"),
        file("/etc/systemd/coredump.conf.d/10-kyan.conf", content = "[Coredump]\nMaxUse=256M\n"),
        # The sysctls of mixins/core/boot.nix that 90-fspec.conf does not already carry.
        file("/etc/sysctl.d/90-kyan.conf", content = "vm.dirty_writeback_centisecs = 1500\nnet.core.netdev_max_backlog = 4096\n"),
        # THP defrag and HWP dynamic boost from mixins/core/boot.nix.
        file("/etc/tmpfiles.d/90-kyan-tuning.conf", content = "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise\nw! /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost - - - - 1\n"),
        file("/etc/udev/rules.d/60-kyan-ioschedulers.rules", content = """ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
"""),
        # NixOS's 16 GB swapfile in @swap (NOCOW), behind zram: priority 1 under zram's 5.
        file("/etc/systemd/system/swap.mount", content = "[Unit]\nDescription=The @swap subvolume\n\n[Mount]\nWhat=UUID=1a10e345-3d66-4bde-9f6b-55d43e6f7e0d\nWhere=/swap\nType=btrfs\nOptions=subvol=@swap,noatime\n\n[Install]\nWantedBy=local-fs.target\n"),
        file("/etc/systemd/system/swap-swapfile.swap", content = "[Unit]\nDescription=Swapfile in @swap\nRequires=swap.mount\nAfter=swap.mount\n\n[Swap]\nWhat=/swap/swapfile\nPriority=1\n\n[Install]\nWantedBy=swap.target\n"),
        # mixins/hardware/mouse.nix: MX Master 3S back/forward to F13/F14, gesture button to Super.
        file("/etc/udev/hwdb.d/70-mx-master.hwdb", content = "evdev:input:b0005v046DpB034*\n KEYBOARD_KEY_90004=f13\n KEYBOARD_KEY_90005=f14\n KEYBOARD_KEY_90006=leftmeta\n"),
        # mixins/core/networking.nix: Google DNS for every connection, over what DHCP hands out.
        file("/etc/NetworkManager/conf.d/90-kyan-dns.conf", content = "[global-dns-domain-*]\nservers=8.8.8.8,8.8.4.4\n"),
        # mixins/core/boot.nix earlyoom.
        file("/etc/sysconfig/earlyoom", content = "EARLYOOM_ARGS=\"-n -m 10 -s 70 --avoid '^(Hyprland|hyprland|\\.dms-wrapped|dms|\\.quickshell-wra|quickshell|qs|polkit-kde-aut|sshd|systemd)$'\"\n"),
        # Tumbleweed's /usr/lib/pam.d/sudo with pam_ssh_agent_auth first, as on the NixOS root.
        # Tumbleweed's vendor greetd stack plus pam_gnome_keyring, which unlocks the login
        # keyring with the login password as NixOS's services.gnome.gnome-keyring does.
        # mixins/core/locale.nix: en_US with British time and Spanish units, the es console keymap
        # and the Canary Islands' zone (NixOS's tzupdate only moved it when travelling).
        file("/etc/locale.conf", content = "LANG=en_US.UTF-8\nLC_TIME=en_GB.UTF-8\nLC_MONETARY=es_ES.UTF-8\nLC_PAPER=es_ES.UTF-8\nLC_MEASUREMENT=es_ES.UTF-8\n"),
        file("/etc/vconsole.conf", content = "KEYMAP=es\n"),
        file("/etc/localtime", mode = "link", src = "/usr/share/zoneinfo/Atlantic/Canary"),
        # mixins/hardware/bluetooth.nix: powered on at boot, experimental features (battery levels),
        # and HID devices that are not bonded over classic Bluetooth, like the DualSense over BLE.
        file("/etc/bluetooth/main.conf", content = "[General]\nExperimental = true\nFastConnectable = true\n\n[Policy]\nAutoEnable = true\n"),
        file("/etc/bluetooth/input.conf", content = "[General]\nClassicBondedOnly = false\n"),
        # NixOS wrote loader.conf until its root went; Tumbleweed's entries are the ones to boot,
        # ahead of the one-shot installer entry that sorts before them.
        file("/boot/efi/loader/loader.conf", content = "timeout 4\nconsole-mode keep\npreferred tumbleweed-*\n"),
        # NixOS's xdg.portal.config.hyprland: gnome-keyring's Secret portal is gated UseIn=gnome.
        file("/etc/xdg-desktop-portal/hyprland-portals.conf", content = "[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.Secret=gnome-keyring\n"),
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
        file("/etc/pam.d/sudo", content = """#%PAM-1.0
auth     sufficient     pam_ssh_agent_auth.so file=/etc/ssh/authorized_keys.d/%u
auth     include        common-auth
account  include        common-account
password include        common-password
session  optional       pam_keyinit.so revoke
session  include        common-session-nonlogin
"""),
    ] + _formalshell_files()

# The host keyboard, which the greeter's sway carries so the password prompt matches the session
# (home/.config/hypr/hyprland.lua sets the same layout).
KEYBOARD = {"layout": "es", "options": "caps:escape"}

# The greeter offers only this session, so a pick remembered from Tumbleweed's plain
# hyprland.desktop (bare Hyprland, no graphical-session.target, no user units) cannot win.
# The entry is NixOS's programs.hyprland.withUWSM one.
GREETER_SESSIONS = "/etc/formalshell-greeter/wayland-sessions"
# A greeter without the session picker starts greeter.sessionCommand instead.
UWSM_HYPRLAND = "/usr/bin/uwsm start -e -D Hyprland hyprland.desktop"

# What `formalshell install --yes` writes on a distro with common-auth, greetd and sway
# (crates/formalshell-rs/src/install.rs at the pinned rev), with the greeter from the fspec store,
# plus the keyboard in sway's input block and the uwsm session.
def _formalshell_files():
    return [
        file("/etc/pam.d/formalshell-lock", content = "#%PAM-1.0\n@include common-auth\n@include common-account\n"),
        file("/etc/tmpfiles.d/formalshell-greeter.conf", content = "d /run/formalshell-greeter 0700 greeter greeter -\nd /var/lib/formalshell-greeter 0700 greeter greeter -\n"),
        file("/etc/greetd/config.toml", content = '[terminal]\nvt = 1\n\n[default_session]\ncommand = "/etc/greetd/formalshell-session.sh"\nuser = "greeter"\n'),
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

# The image's build stages, as store packages at the versions the NixOS root runs.
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
        # FormalShell's gtk template sets gtk-theme to adw-gtk3-dark; without it GTK3 apps are light.
        pkg("adw-gtk3", version = "6.5", source = github("lassekongo83/adw-gtk3", asset = "adw-gtk3v*.tar.xz"), share = {"themes/adw-gtk3": "adw-gtk3", "themes/adw-gtk3-dark": "adw-gtk3-dark"}),
        pkg("geist-mono-nerd-font", version = "3.4.0", source = github("ryanoasis/nerd-fonts", asset = "GeistMono.tar.xz"), share = {"fonts/GeistMonoNerdFont": "."}),
        # The rev ~/.config/nix's flake.lock pins, so both roots run the same shell. dev/tarball.sh
        # is upstream's release build: it installs its own deps on bookworm, whose glibc it targets.
        pkg(
            "formalshell",
            source = git("https://github.com/FormalSnake/FormalShell", rev = "e8a800d3da54f586f187a328916785ff691f8759", image = "docker.io/library/debian:bookworm"),
            build = ["sh", "-c", "WORK=\"$FSPEC_OUT.work\" bash \"$FSPEC_SRC/dev/tarball.sh\" \"$FSPEC_OUT.tar\" && tar -xzf \"$FSPEC_OUT.tar\"/formalshell-*-linux.tar.gz -C \"$FSPEC_OUT\" && rm -rf \"$FSPEC_OUT.work\" \"$FSPEC_OUT.tar\""],
        ),
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
            source = git(
                "https://github.com/thisisgm/omarchy-pods",
                rev = "307c5a6d2109f088d8e6a558c933ebe4f6b1db01",
                image = TUMBLEWEED,
                deps = ["cmake", "make", "gcc-c++", "pkgconf", "qt6-base-devel", "qt6-declarative-devel", "qt6-quickcontrols2-devel", "qt6-connectivity-devel", "qt6-tools-devel", "qt6-linguist-devel", "libopenssl-devel", "libpulse-devel"],
            ),
            patches = glob("patches/librepods-*.patch"),
            build = ["sh", "-c", "cmake -S \"$FSPEC_SRC/daemon\" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=\"$FSPEC_OUT\" && cmake --build build -j && cmake --install build"],
        ),
        # nvim's nil (tag 2026-07-23) and gopls publish no Linux binaries.
        # nil's build script asks nix for its builtins.
        pkg("nil", source = git("https://github.com/oxalica/nil", rev = "dbbb5c24f9215476992aa1bd305f8e5398e89654", image = TUMBLEWEED, deps = ["cargo", "gcc", "nix"]), bins = ["nil"]),
        pkg("gopls", source = git("https://github.com/golang/tools", rev = "gopls/v0.23.0"), build = ["sh", "-c", "cd \"$FSPEC_SRC/gopls\" && GOBIN=\"$FSPEC_OUT/bin\" go install -trimpath ."]),
    ]

def _services():
    return [
        service("tailscaled"),
        service("sshd"),
        service("bluetooth"),
        service("chronyd"),
        service("irqbalance"),
        service("avahi-daemon"),
        service("cups-browsed"),
        service("earlyoom"),
        service("swap.mount"),
        service("swap-swapfile.swap"),
        service("hwdb", exec = "/usr/bin/systemd-hwdb update", description = "Compile /etc/udev/hwdb.d", systemd = {"Type": "oneshot", "RemainAfterExit": True}),
        # Tumbleweed boots to multi-user.target, under which greetd never starts.
        service("greetd", display_manager = True),
        service("tuned"),
        service("tuned-ppd"),
        service("docker.socket"),
        service("syncthing@kyandesutter"),
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
