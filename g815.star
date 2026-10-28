load("//boot.star", "limine_entry")
load("//system.star", "FIREWALL_TCP", "FIREWALL_UDP", "GREETER_SESSIONS", "LIBEXEC", "PKG_BIN", "firewall_zone")

# The g815's own layer on top of system.star and home.star: the RTX 5070 and the ASUS MUX, asusd,
# the gaming stack, the Windows install it dual-boots and runs as a guest, and the tuning for a
# machine that stays on the charger and never sleeps (systems/g815 and the mixins only it enables).

ROOTFS = "g815/rootfs/"
HOME = "/home/kyandesutter"
TUMBLEWEED = "registry.opensuse.org/opensuse/tumbleweed"

# Windows C:, the Games partition and the USB SSD's Steam library (systems/g815/windows-dualboot.nix).
WIN_UUID = "D0409F99409F84BE"
NTFS_OPTIONS = "rw,uid=1000,gid=100,umask=022,windows_names,noatime,nofail"

PACKAGES = [
    # mixins/gaming: Steam (non-oss), gamemode, gamescope, MangoHud, Heroic for the Epic library.
    "steam", "gamemode", "gamescope", "mangohud", "heroic-games-launcher", "protontricks",
    # mixins/gaming/waylandcraft.nix: Prism Launcher on Java 21 under cage.
    "prismlauncher", "java-21-openjdk", "xwayland-satellite", "cage",
    # windows-vm.nix and windows-dualboot.nix.
    "qemu-x86", "qemu-ovmf-x86_64", "swtpm", "mtools", "socat", "ntfs-3g", "hivex", "xxd", "efibootmgr",
    # macos-vm: qemu-img and the dmg reader for macos-vm-fetch, the GTK window and PipeWire audio
    # the launcher asks for, mkfs.vfat for the OpenCore ESP and sgdisk for the installer disks.
    "qemu-tools", "qemu-block-dmg", "qemu-ui-gtk", "qemu-audio-pipewire", "dosfstools", "gptfdisk",
    # NetworkManager's Wi-Fi backend here, and per-link DNS so tailscaled owns only *.ts.net.
    "iwd", "systemd-resolved",
    # UxPlay's runtime: Avahi's dns_sd and the H.264/AAC decoders it plays through.
    "libdns_sd", "gstreamer-plugins-ugly",
]

# windows-dualboot.nix's limine extraEntries. Windows shares the ESP, so boot():/ finds it.
WINDOWS_BOOT = limine_entry("Windows 11", "Chainload the Windows Boot Manager", "boot():///EFI/Microsoft/Boot/bootmgfw.efi")

def _rootfs(path, dest = None, perms = None):
    return file(dest or "/" + path, src = ROOTFS + path, perms = perms)

def _libexec(name):
    return _rootfs("usr/libexec/" + name, LIBEXEC + "/" + name, perms = "0755")

def _mount(where, uuid, extra = "", unit = ""):
    return file("/etc/systemd/system/%s.mount" % where.removeprefix("/").replace("/", "-"), content = """[Unit]
Description=NTFS volume at %s
%s
[Mount]
What=/dev/disk/by-uuid/%s
Where=%s
Type=ntfs3
Options=%s%s

[Install]
WantedBy=local-fs.target
""" % (where, unit, uuid, where, NTFS_OPTIONS, extra))

def _nvidia():
    return [
        # NVIDIA's own zypper repo; G07 is the newest series it carries (595), the closest to
        # NixOS's nvidiaPackages.latest. The meta package pulls the signed open kernel module.
        repo(
            "nvidia",
            url = "https://download.nvidia.com/opensuse/tumbleweed",
            key = "https://download.nvidia.com/opensuse/tumbleweed/repodata/repomd.xml.key",
            fingerprint = "2FB03195DECD49492BD1C17AB1D0D788DB27FD5A",
        ),
        pkg("nvidia-open-driver-G07-signed-kmp-meta", source = zypper(repo = "nvidia")),
        pkg("nvidia-video-G07", source = zypper(repo = "nvidia")),
        pkg("nvidia-gl-G07", source = zypper(repo = "nvidia")),
        # Steam's 32-bit games.
        pkg("nvidia-gl-G07-32bit", source = zypper(repo = "nvidia")),
        # nvidia-smi and nvidia-powerd (hardware.nvidia.dynamicBoost).
        pkg("nvidia-compute-utils-G07", source = zypper(repo = "nvidia"), services = [service("nvidia-powerd")]),
        pkg("nvidia-settings", source = zypper(repo = "nvidia")),
        # mixins/hardware/nvidia.nix: PowerMizer pinned to max, VRAM saved across suspend into
        # /var/tmp, fbdev on, nouveau out of the way; and kvm's MSR tolerance for the guests.
        file("/etc/modprobe.d/90-g815.conf", content = """blacklist nouveau
blacklist nova_core
blacklist nvidiafb
softdep nvidia post: nvidia-uvm
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerDefaultAC=0x1; PowerMizerDefault=0x1" NVreg_TemporaryFilePath=/var/tmp NVreg_UseKernelSuspendNotifiers=1
options nvidia-drm fbdev=1 modeset=1
options kvm ignore_msrs=1 report_ignored_msrs=0
options iwlwifi power_save=0
options iwlmld power_scheme=1
options cfg80211 ieee80211_regdom=ES
"""),
        file("/etc/modules-load.d/nvidia-uvm.conf", content = "nvidia_uvm\n"),
        # nvidia.nix's shader cache and mixins/gaming's frame caps, for every session.
        file("/etc/environment.d/90-g815.conf", content = """__GL_SHADER_DISK_CACHE_SIZE=10737418240
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
DXVK_FRAME_RATE=138
VKD3D_FRAME_RATE=138
STEAM_EXTRA_COMPAT_TOOLS_PATHS=/usr/local/share/steam/compatibilitytools.d
"""),
        # The ASUS MUX routes the internal panel through the dGPU (0 = dGPU, 1 = Optimus). The
        # firmware keeps it and applies a change at the next boot; Windows boots the same way.
        _libexec("gpu-mux-dgpu"),
        service(
            "gpu-mux-dgpu",
            exec = LIBEXEC + "/gpu-mux-dgpu",
            description = "Route the internal panel through the dGPU (ASUS MUX)",
            systemd = {"Type": "oneshot", "unit": {"After": "fspec-asusd.service", "ConditionPathExists": "/sys/devices/platform/asus-nb-wmi/gpu_mux_mode"}},
        ),
    ]

def _asus():
    return [
        # asusctl has no Tumbleweed package; its release ships Arch's build, whose binaries need only
        # glibc and libudev. The unit is upstream's with the store path.
        # Its udev rule wants asusd.service by that name, so it stays out.
        pkg(
            "asusctl",
            version = "6.5.0",
            source = github("OpenGamingCollective/asusctl", asset = "asusctl-*-x86_64.pkg.tar.zst"),
            bins = ["asusd", "asusctl"],
            etc = {"dbus-1/system.d/asusd.conf": "usr/share/dbus-1/system.d/asusd.conf"},
        ),
        # asusd reads its keyboard table from here; this one carries the g815's board.
        _rootfs("usr/share/asusd/aura_support.ron"),
        service(
            "asusd",
            exec = PKG_BIN + "/asusd",
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
                "unit": {"After": ["nvidia-powerd.service", "systemd-udevd.service"], "StartLimitIntervalSec": 500, "StartLimitBurst": 5, "ConditionPathExists": PKG_BIN + "/asusd"},
            },
        ),
        # mixins/hardware/asus.nix: the Aura accent, the 80% charge limit, no sleep pulse.
        _libexec("asus-aura"),
        service(
            "asus-aura",
            exec = LIBEXEC + "/asus-aura",
            description = "Aura keyboard accent seed + 80% charge limit",
            systemd = {"Type": "oneshot", "RemainAfterExit": True, "unit": {"After": "fspec-asusd.service", "Requires": "fspec-asusd.service"}},
        ),
    ]

def _gaming():
    return [
        pkg("proton-ge", version = "GE-Proton11-7", source = github("GloriousEggroll/proton-ge-custom", asset = "GE-Proton*-x86_64.tar.gz"), share = {"steam/compatibilitytools.d/GE-Proton11-7": "GE-Proton11-7"}),
        # mixins/gaming/minecraft.nix: the Modrinth App, its release AppImage. Its WebKit draws
        # nothing with the DMA-BUF renderer on NVIDIA.
        # FormalShell's AirPlay receiver (services.formalshell.airplay) runs uxplay, nixpkgs' v1.73.7,
        # which neither Tumbleweed nor a release ships for Linux.
        pkg(
            "uxplay",
            source = git("https://github.com/FDH2/UxPlay", rev = "df67c212a433cf6dda3676dd40c097900d24e645", image = TUMBLEWEED, deps = ["cmake", "make", "gcc-c++", "pkgconf", "libopenssl-devel", "libplist-2_0-devel", "gstreamer-devel", "gstreamer-plugins-base-devel", "avahi-compat-mDNSResponder-devel"]),
            bins = ["uxplay"],
        ),
        # mixins/gaming/epic-games-launcher.nix: Epic's Linux preview replaces the AppImage it ran
        # from to update, so the store copy only seeds a writable one in the home on first launch.
        pkg("epic-games-launcher-appimage", source = url("https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/0.95.2%2Bgfa9ad49/Linux/EpicGamesLauncher-x86_64.AppImage")),
        file("/usr/local/bin/epic-games-launcher", perms = "0755", content = """#!/bin/sh
set -e
dir="${XDG_DATA_HOME:-$HOME/.local/share}/epic-games-launcher"
img="$dir/EpicGamesLauncher-x86_64.AppImage"
if [ ! -e "$img" ]; then
	mkdir -p "$dir"
	install -m 755 """ + PKG_BIN + """/epic-games-launcher-appimage "$img"
fi
export WEBKIT_DISABLE_DMABUF_RENDERER=1
exec "$img" "$@"
"""),
        file("~/.local/share/applications/epic-games-launcher.desktop", content = """[Desktop Entry]
Type=Application
Name=Epic Games Launcher
Exec=/usr/local/bin/epic-games-launcher %U
Terminal=false
Categories=Game;
"""),
        pkg("modrinth-app", version = "0.21.6", source = github("modrinth/code", asset = "Modrinth.App_*_amd64.AppImage")),
        file("~/.local/share/applications/modrinth-app.desktop", content = """[Desktop Entry]
Type=Application
Name=Modrinth App
Exec=env WEBKIT_DISABLE_DMABUF_RENDERER=1 """ + PKG_BIN + """/modrinth-app
Icon=ModrinthApp
Categories=Game;
"""),
        # mixins/gaming/roblox.nix: Sober with the MangoHud layer and its FPS counter.
        pkg("sober", source = flatpak("org.vinegarhq.Sober")),
        pkg("mangohud-vulkan-layer", source = flatpak("org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/25.08")),
        file("~/.local/share/flatpak/overrides/org.vinegarhq.Sober", content = "[Environment]\nMANGOHUD=1\nMANGOHUD_CONFIG=fps_only,font_size=32,position=top-right\n"),
        # mixins/gaming/waylandcraft.nix: a login session that is only Minecraft.
        _libexec("waylandcraft-session"),
        file(GREETER_SESSIONS + "/waylandcraft.desktop", content = "[Desktop Entry]\nName=Waylandcraft\nComment=Minecraft as the desktop, hosted by cage\nExec=" + LIBEXEC + "/waylandcraft-session\nType=Application\n"),
        # The KDE session is the gaming desktop: Steam opens with it.
        service(
            "steam",
            exec = "/usr/bin/steam",
            user = True,
            description = "Steam",
            systemd = {
                "unit": {"ConditionEnvironment": "XDG_CURRENT_DESKTOP=KDE", "PartOf": "graphical-session.target", "After": "graphical-session.target", "RefuseManualStart": True, "RefuseManualStop": True},
                "install": {"WantedBy": "graphical-session.target"},
            },
        ),
    ]

def _windows():
    compatdata = HOME + "/.local/share/Steam/steamapps/compatdata"
    libs = ["/mnt/windows/Program Files (x86)/Steam", "/mnt/games/SteamLibrary", "/mnt/steamlib/SteamLibrary"]
    return [
        _mount("/mnt/windows", WIN_UUID, unit = "Requires=clear-ntfs-dirty.service\nAfter=clear-ntfs-dirty.service\nConditionPathExists=!/run/windows-vm.running\n"),
        _mount("/mnt/games", "017BFE6375CF515B", unit = "ConditionPathExists=!/run/windows-vm.running\n"),
        # The USB SSD mounts on first access, so boot never waits on it.
        _mount("/mnt/steamlib", "7ED4F163D4F11E59", extra = ",x-systemd.device-timeout=5s"),
        file("/etc/systemd/system/mnt-steamlib.automount", content = "[Unit]\nDescription=Automount the USB SSD's Steam library\n\n[Automount]\nWhere=/mnt/steamlib\n\n[Install]\nWantedBy=local-fs.target\n"),
        service("mnt-windows.mount"),
        service("mnt-games.mount"),
        service("mnt-steamlib.automount"),
        # ntfs3 refuses a volume with its dirty flag set; this clears a stale one, only after
        # ntfsfix's read-only pass agrees the volume is consistent, ahead of every mount.
        _libexec("clear-ntfs-dirty"),
        file("/etc/systemd/system/clear-ntfs-dirty.service", content = """[Unit]
Description=Clear a stale NTFS dirty flag on the Windows volume
DefaultDependencies=false
Before=mnt-windows.mount shutdown.target
Conflicts=shutdown.target
After=dev-disk-by\\x2duuid-""" + WIN_UUID + """.device

[Service]
Type=oneshot
ExecStart=""" + LIBEXEC + """/clear-ntfs-dirty
"""),
        # Windows' Bluetooth link keys into BlueZ before bluetoothd starts, for devices BlueZ holds
        # no key for, so one pairing serves both systems.
        _libexec("windows-bluetooth-keys"),
        service(
            "windows-bluetooth-keys",
            exec = LIBEXEC + "/windows-bluetooth-keys",
            description = "Copy Windows Bluetooth link keys into BlueZ",
            systemd = {"Type": "oneshot", "unit": {"Before": "bluetooth.service", "After": "mnt-windows.mount", "ConditionPathIsMountPoint": "/mnt/windows"}, "install": {"WantedBy": "bluetooth.service"}},
        ),
        # Proton prefixes need names windows_names refuses, so each library's compatdata is the
        # Linux one (Valve's "Using a NTFS disk with Linux and Windows").
        file("/etc/tmpfiles.d/90-g815-compatdata.conf", content = "d %s 0755 kyandesutter users -\n" % compatdata + "".join(['L "%s/steamapps/compatdata" - - - - %s\n' % (l, compatdata) for l in libs])),
        _rootfs("usr/libexec/link-minecraft-to-windows", "/usr/local/bin/link-minecraft-to-windows", perms = "0755"),
        # The shell's "Windows" session button: a one-shot UEFI BootNext, passwordless for the
        # active local wheel session.
        _libexec("reboot-to-windows"),
        file("/etc/systemd/system/reboot-to-windows.service", content = "[Unit]\nDescription=One-shot reboot into Windows via UEFI BootNext\n\n[Service]\nType=oneshot\nExecStart=" + LIBEXEC + "/reboot-to-windows\n"),
        file("/etc/polkit-1/rules.d/50-reboot-to-windows.rules", content = """polkit.addRule(function(action, subject) {
  if (action.id == "org.freedesktop.systemd1.manage-units" &&
      action.lookup("unit") == "reboot-to-windows.service" &&
      subject.local && subject.active && subject.isInGroup("wheel")) {
    return polkit.Result.YES;
  }
});
"""),
        # Windows reads the RTC as local time.
        file("/etc/adjtime", content = "0.0 0 0.0\n0\nLOCAL\n"),
        # windows-vm.nix: the same Windows install as a KVM guest over a throwaway overlay, with the
        # host's mounts of its volumes stopped while it runs.
        _libexec("windows-vm"),
        _libexec("windows-vm-prep"),
        file("/etc/systemd/system/windows-vm.service", content = """[Unit]
Description=Bare-metal Windows 11 as a KVM guest over a throwaway overlay
After=mnt-windows.mount mnt-games.mount
RequiresMountsFor=/mnt/steamlib/windows-vm

[Service]
ExecStartPre=/usr/bin/touch /run/windows-vm.running
ExecStartPre=/usr/bin/systemctl stop mnt-windows.mount mnt-games.mount
ExecStart=""" + LIBEXEC + """/windows-vm
ExecStopPost=/usr/bin/rm -f /run/windows-vm.running /mnt/steamlib/windows-vm/overlay.qcow2
ExecStopPost=-/usr/bin/systemctl start --no-block mnt-windows.mount mnt-games.mount
KillSignal=SIGINT
KillMode=mixed
TimeoutStopSec=30
"""),
        file("/etc/systemd/system/windows-vm-prep.service", content = """[Unit]
Description=Prepare a fresh Windows guest overlay
After=windows-vm.service
BindsTo=windows-vm.service

[Service]
Type=oneshot
User=kyandesutter
Environment=SSH_AUTH_SOCK=/run/user/1000/gcr/ssh
ExecStart=""" + LIBEXEC + """/windows-vm-prep

[Install]
WantedBy=windows-vm.service
"""),
        service("windows-vm-prep"),
    ]

def _macos_vm():
    return [
        # mixins/services/macos-vm.nix: the OS X 10.9 guest. OpenCore is upstream's release zip;
        # macos-vm renders its config.plist from Sample.plist and builds the ESP on first start,
        # under ~/.local/share/macos-vm. macos-vm-fetch pulls the installer from Apple.
        pkg("opencore", version = "1.0.7", source = github("acidanthera/OpenCorePkg", asset = "OpenCore-*-RELEASE.zip"), share = {"macos-vm/opencore": "."}),
        _libexec("macos-vm"),
        _libexec("macos-vm-fetch"),
        _libexec("macos-vm-oc-config"),
        _libexec("macos-vm-osrecovery"),
        _libexec("macos-vm-apm-geometry"),
        _libexec("macos-vm-install-mavericks"),
        file("/usr/local/bin/macos-vm", mode = "link", target = LIBEXEC + "/macos-vm"),
        file("/usr/local/bin/macos-vm-fetch", mode = "link", target = LIBEXEC + "/macos-vm-fetch"),
        # Launched from the app grid it comes up fullscreen on its own workspace, which is most of
        # what "not living in a window" means here.
        file("~/.local/share/applications/macos-vm.desktop", content = """[Desktop Entry]
Type=Application
Name=macOS Mavericks
Comment=OS X 10.9 guest (QEMU/KVM)
Exec=/usr/local/bin/macos-vm
Icon=computer
Terminal=false
Categories=System;
StartupWMClass=qemu-system-x86_64
"""),
    ]

def _host():
    return [
        # systems/g815: swap tuning for a browser, three Electron apps and a JVM heap that come
        # straight back from zram; kswapd ahead of games; a hung kernel reboots instead of
        # sitting frozen; forwarding for the tailnet and docker.
        file("/etc/sysctl.d/91-g815.conf", content = """vm.swappiness = 100
vm.page-cluster = 1
vm.watermark_scale_factor = 125
kernel.panic = 10
kernel.panic_on_oops = 1
kernel.softlockup_panic = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
"""),
        # zram at half of the 32 GB, as mixins/core/boot.nix gives this host.
        file("/etc/systemd/zram-generator.conf", content = "[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\nswap-priority = 5\n"),
        # Always on the barrel charger: performance, no battery variant.
        file("/etc/tuned/ppd.conf", content = "[main]\ndefault=performance\nbattery_detection=false\nsysfs_acpi_monitor=false\n\n[profiles]\npower-saver=powersave\nbalanced=balanced\nperformance=throughput-performance\n\n[battery]\nbalanced=balanced-battery\n"),
        # It runs unattended test rigs and the nvidia driver does not survive a resume here: no
        # sleep, the lid does nothing, a dead battery powers off, and the iTCO watchdog reboots a
        # hard lockup.
        file("/etc/systemd/sleep.conf.d/10-g815.conf", content = "[Sleep]\nAllowSuspend=no\nAllowHibernation=no\nAllowHybridSleep=no\nAllowSuspendThenHibernate=no\n"),
        file("/etc/systemd/logind.conf.d/10-g815.conf", content = "[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\n"),
        file("/etc/systemd/system.conf.d/10-g815-watchdog.conf", content = "[Manager]\nRuntimeWatchdogSec=60s\n"),
        file("/etc/UPower/UPower.conf.d/10-g815.conf", content = "[UPower]\nCriticalPowerAction=PowerOff\n"),
        # Intel BE200: iwd, no power save (latency spikes), and resolved for per-link DNS with
        # Google's servers globally, so tailscale0's routing domain still takes *.ts.net first.
        file("/etc/NetworkManager/conf.d/90-g815.conf", content = "[device]\nwifi.backend=iwd\n\n[connection]\nwifi.powersave=2\n\n[main]\ndns=systemd-resolved\n"),
        file("/etc/systemd/resolved.conf.d/10-kyan.conf", content = "[Resolve]\nDNS=8.8.8.8 8.8.4.4\n"),
        service("systemd-resolved"),
        file("/etc/resolv.conf", mode = "link", target = "/run/systemd/resolve/stub-resolv.conf"),
        # This machine is driven remotely; a deliberate-looking deactivation once left it off the
        # tailnet for 50 minutes.
        _libexec("wifi-reconnect"),
        timer("wifi-reconnect", exec = LIBEXEC + "/wifi-reconnect", schedule = "*/2 * * * *"),
        # Output priorities: CMF Headphone Pro and AirPods (A2DP) over HDMI over the speakers.
        file("/etc/wireplumber/wireplumber.conf.d/51-output-priorities.conf", content = {
            "monitor.bluez.rules": [
                {"matches": [{"node.name": "~bluez_output.2C_BE_EE_65_A0_21.*"}], "actions": {"update-props": {"priority.session": 2000, "priority.driver": 2000}}},
                {"matches": [{"device.name": "bluez_card.14_14_7D_E7_8C_E3"}], "actions": {"update-props": {"device.profile": "a2dp-sink", "bluez5.auto-connect": ["a2dp_sink"]}}},
                {"matches": [{"node.name": "~bluez_output.14_14_7D_E7_8C_E3.*"}], "actions": {"update-props": {"priority.session": 2000, "priority.driver": 2000}}},
            ],
            "monitor.alsa.rules": [
                {"matches": [{"node.name": "~alsa_output.pci-0000_02_00.1.*"}], "actions": {"update-props": {"priority.session": 1500, "priority.driver": 1500}}},
                {"matches": [{"node.name": "~alsa_output.pci-0000_80_1f.3.*"}], "actions": {"update-props": {"priority.session": 1000, "priority.driver": 1000}}},
            ],
        }, format = "json"),
        # NixOS's firewall here also opens Steam's Remote Play and local transfers, and NordVPN's
        # OpenVPN and meshnet ports.
        firewall_zone(FIREWALL_TCP + [443, 27036, 27037, 27040], FIREWALL_UDP + [1194, 10400, 10401, 27036], udp_ranges = ["27031-27035"]),
    ]

# mixins/dev/godot.nix, gated on the NVIDIA dGPU: Godot's .NET editor, the SDK its C# template
# targets (net8.0), and the MCP server Claude Code drives it through.
GODOT = PKG_BIN + "/godot4-mono"

def _godot():
    return [
        pkg("godot-mono", version = "4.7.2-stable", source = github("godotengine/godot-builds", asset = "Godot_v*-stable_mono_linux_x86_64.zip"), links = {
            "godot4-mono": "Godot_v4.7.2-stable_mono_linux_x86_64/Godot_v4.7.2-stable_mono_linux.x86_64",
        }),
        pkg("dotnet-sdk-8", source = url("https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.425/dotnet-sdk-8.0.425-linux-x64.tar.gz"), links = {"dotnet": "dotnet"}),
        pkg("godot-mcp", version = "0.1.1", source = npm("@coding-solo/godot-mcp")),
        file("~/.claude.json", mode = "patch", owns = {
            "mcpServers.godot": {"command": PKG_BIN + "/godot-mcp", "env": {"GODOT_PATH": GODOT}},
        }),
    ]

def g815(h):
    return _nvidia() + _asus() + _gaming() + _windows() + _macos_vm() + _godot() + _host()
