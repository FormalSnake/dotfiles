load("//lib/paths.star", "LIBEXEC")
load("//lib/units.star", "oneshot")
load("//modules/boot/boot.star", "limine_entry")

# Windows shares the ESP, so boot():/ finds it.
WINDOWS_BOOT = limine_entry("Windows 11", "Chainload the Windows Boot Manager", "boot():///EFI/Microsoft/Boot/bootmgfw.efi")

# The NTFS volumes, the Bluetooth keys both systems share, and the same install as a KVM guest.
WINDOWS = [service(u) for u in ["mnt-windows.mount", "mnt-games.mount", "mnt-steamlib.automount", "windows-vm-prep"]] + [
    # Before bluetoothd, for the devices BlueZ holds no key for, so one pairing serves both.
    oneshot(
        "windows-bluetooth-keys",
        LIBEXEC + "/windows-bluetooth-keys",
        "Copy Windows Bluetooth link keys into BlueZ",
        remain = False,
        unit = {"Before": "bluetooth.service", "After": "mnt-windows.mount", "ConditionPathIsMountPoint": "/mnt/windows"},
        install = {"WantedBy": "bluetooth.service"},
    ),
]

# The OS X 10.9 guest. macos-vm builds OpenCore's ESP on first start under ~/.local/share/macos-vm.
VMS = [
    pkg("opencore", version = "1.0.7", source = github("acidanthera/OpenCorePkg", asset = "OpenCore-*-RELEASE.zip"), share = {"macos-vm/opencore": "."}),
    file("/usr/local/bin/macos-vm", mode = "link", target = LIBEXEC + "/macos-vm"),
    file("/usr/local/bin/macos-vm-fetch", mode = "link", target = LIBEXEC + "/macos-vm-fetch"),
    service("virtqemud"),
    service("virtnetworkd.socket"),
    service("virtstoraged.socket"),
]
