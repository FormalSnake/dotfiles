{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kyan.macosVm;
  stateDir = "${config.users.users.kyandesutter.home}/.local/share/macos-vm";

  # 10.9 predates Apple Secure Boot, APFS and every kext a modern hackintosh
  # needs: isa-applesmc gives the guest a real AppleSMC, e1000-82545em matches
  # the in-box AppleIntel8254XEthernet driver and usb-audio matches
  # AppleUSBAudio, so this EFI carries zero kexts. Everything set below is
  # either an OVMF-specific booter quirk (copied from OSX-KVM's known-good
  # config) or a legacy-macOS console quirk.
  ocConfig = pkgs.writeText "oc-config.py" ''
    import plistlib, sys

    src, dst, product, resolution, boot_args = sys.argv[1:6]
    d = plistlib.load(open(src, "rb"))


    def falsify(section):
        for k, v in section.items():
            if isinstance(v, bool):
                section[k] = False


    # No kexts, no ACPI patching, no extra boot entries: a VM needs none of it,
    # and Sample.plist ships enabled example entries that would halt the boot.
    d["ACPI"]["Add"] = d["ACPI"]["Delete"] = d["ACPI"]["Patch"] = []
    d["Kernel"]["Add"] = d["Kernel"]["Block"] = d["Kernel"]["Patch"] = []
    d["Misc"]["Entries"] = d["Misc"]["Tools"] = []
    d["UEFI"]["ReservedMemory"] = []
    d["DeviceProperties"]["Add"] = {}
    d["DeviceProperties"]["Delete"] = {}

    falsify(d["Booter"]["Quirks"])
    d["Booter"]["Quirks"].update(
        AvoidRuntimeDefrag=True,
        EnableWriteUnprotector=True,
    )

    falsify(d["Kernel"]["Quirks"])
    d["Kernel"]["Quirks"].update(
        ForceSecureBootScheme=True,
        ProvideCurrentCpuInfo=True,
    )

    d["Misc"]["Boot"].update(PickerMode="Builtin", ShowPicker=True, Timeout=3)
    d["Misc"]["Security"].update(
        AllowSetDefault=True,
        # The default model is j137, which refuses anything older than 10.13.2.
        SecureBootModel="Disabled",
        ScanPolicy=0,
        Vault="Optional",
    )

    d["PlatformInfo"].update(
        Automatic=True, UpdateSMBIOS=True, UpdateSMBIOSMode="Create"
    )
    # The OS X installer gates on board-id, so the SMBIOS has to name a Mac that
    # shipped with 10.9; OpenCore derives the board-id from the model name.
    # Serials are deliberate placeholders: no iServices, which Mavericks has
    # lost anyway.
    d["PlatformInfo"]["Generic"].update(
        MLB="M0000000000000001",
        ROM=b"\x11\x22\x33\x44\x55\x66",
        SpoofVendor=True,
        SystemProductName=product,
        SystemSerialNumber="W00000000001",
        SystemUUID="00000000-0000-0000-0000-000000000000",
    )

    # OVMF has no Apple filesystem driver, so OpenHfsPlus.efi is what lets the
    # firmware see an HFS+ volume at all. OpenPartitionDxe.efi adds the Apple
    # Partition Map on top of OVMF's GPT/MBR-only driver, for a guest disk
    # partitioned that way.
    d["UEFI"]["Drivers"] = [
        {
            "Arguments": "",
            "Comment": p,
            "Enabled": True,
            "LoadEarly": False,
            "Path": p,
        }
        for p in ("OpenRuntime.efi", "OpenHfsPlus.efi", "OpenPartitionDxe.efi")
    ]
    d["UEFI"]["APFS"].update(MinDate=-1, MinVersion=-1)
    d["UEFI"]["Input"]["KeySupport"] = True
    d["UEFI"]["Output"].update(
        ProvideConsoleGop=True, Resolution=resolution, TextRenderer="BuiltinGraphics"
    )
    # Pre-10.10 boot.efi mixes text into graphics mode and emits tabs the
    # builtin renderer cannot place.
    d["UEFI"]["Quirks"].update(
        IgnoreTextInGraphics=True,
        ReplaceTabWithSpace=True,
        RequestBootVarRouting=True,
        SanitiseClearScreen=True,
    )

    d["NVRAM"]["Add"]["7C436110-AB2A-4BBB-A880-FE41995C9F82"]["boot-args"] = boot_args

    plistlib.dump(d, open(dst, "wb"))
  '';

  opencore = pkgs.fetchzip {
    url = "https://github.com/acidanthera/OpenCorePkg/releases/download/1.0.7/OpenCore-1.0.7-RELEASE.zip";
    hash = "sha256-qLr+wrE+geX+37WH2YUgxyCJXmfJcuUvejuLpaxFEco=";
    stripRoot = false;
  };

  # A raw FAT32 ESP holding OpenCore. Handed to QEMU with snapshot=on, so the
  # store path stays read-only and OpenCore's NVRAM writes land in OVMF_VARS.
  opencoreEsp =
    pkgs.runCommand "macos-vm-opencore-esp"
      {
        nativeBuildInputs = with pkgs; [
          dosfstools
          mtools
          python3
        ];
      }
      ''
        mkdir -p esp/EFI
        cp -r ${opencore}/X64/EFI/BOOT ${opencore}/X64/EFI/OC esp/EFI/
        chmod -R u+w esp

        python3 ${ocConfig} ${opencore}/Docs/Sample.plist esp/EFI/OC/config.plist \
          ${
            lib.escapeShellArgs [
              cfg.systemProductName
              cfg.resolution
              cfg.bootArgs
            ]
          }

        for driver in OpenRuntime.efi OpenHfsPlus.efi OpenPartitionDxe.efi; do
          test -f "esp/EFI/OC/Drivers/$driver"
        done

        truncate -s 64M $out
        # Fixed volume id: mkfs.vfat would otherwise stamp the build time.
        mkfs.vfat -F 32 -i cafe1e57 -n OPENCORE $out
        mcopy -s -i $out esp/EFI ::/
      '';

  # Port of the download half of https://mavericksforever.com/get.sh (by
  # Wowfunhappy): the osrecovery handshake needs the board serial, board id and
  # ROM of a Mavericks-era Mac to mint an asset token.
  recoveryHandshake = pkgs.writeText "osrecovery-token.py" ''
    import hashlib, os, urllib.request

    BOARD_SERIAL = "C0243070168G3M91F"
    BOARD_ID = "Mac-3CBD00234E554E41"
    ROM = bytes.fromhex("003EE1E6AC14")

    session = urllib.request.urlopen("http://osrecovery.apple.com/")
    server_id = session.headers["Set-Cookie"].split("session=")[1].split(";")[0].strip('"')

    client_id = os.urandom(8).hex().upper()
    key = (
        hashlib.sha256(
            bytes.fromhex(client_id)
            + bytes.fromhex(server_id.split("~")[1])
            + ROM
            + hashlib.sha256((BOARD_SERIAL + BOARD_ID).encode()).digest()
            + b"\xcc" * 10
        )
        .hexdigest()
        .upper()
    )

    payload = urllib.request.urlopen(
        urllib.request.Request(
            "http://osrecovery.apple.com/InstallationPayload/OSInstaller",
            data=f"cid={client_id}\nsn={BOARD_SERIAL}\nbid={BOARD_ID}\nk={key}".encode(),
            headers={"Content-Type": "text/plain", "Cookie": f"session={server_id}"},
            method="POST",
        )
    ).read().decode()

    fields = dict(
        line.split(": ", 1) for line in payload.splitlines() if ": " in line
    )
    print(fields["AU"])
    print(fields["AT"])
  '';

  # Both DMGs are optical-media images: an Apple Partition Map with 2048-byte
  # blocks wrapping one HFS+ volume. Nothing in the boot path reads that layout
  # (no UEFI partition driver parses a 2048-byte-block map on a 512-byte disk,
  # and XNU then finds no IOMedia to match boot-uuid against), so the volume is
  # located once here and re-wrapped in a GPT below.
  apmGeometry = pkgs.writeText "apm-geometry.py" ''
    import struct, sys

    with open(sys.argv[1], "rb") as f:
        sig, block_size = struct.unpack(">HH", f.read(4))
        assert sig == 0x4552, "not an Apple Partition Map"

        index = 1
        while True:
            f.seek(block_size * index)
            entry = f.read(136)
            assert entry[:2] == b"PM", "partition map entry %d missing" % index
            count, start, size = struct.unpack(">III", entry[4:16])
            kind = entry[48:80].split(b"\0")[0].decode()
            if kind == "Apple_HFS":
                print(start * block_size, size * block_size)
                break
            assert index < count, "no Apple_HFS partition"
            index += 1
  '';

  # The GUI installer on this media is the App Store *downloader* stub: it asks
  # for an Apple ID because it wants to fetch an installer we already have. This
  # drives the payload directly instead, and works around two things that only
  # bite when booting the raw BaseSystem volume rather than createinstallmedia
  # media: the migration step needs "Recovered Items" to already exist, and the
  # boot volume owns the /Volumes/OS X Base System name that BaseSystem.dmg
  # needs when the installer mounts it for BaseSystemResources.pkg.
  guestInstaller = pkgs.writeText "install-mavericks" ''
    #!/bin/sh
    set -e

    target="''${1:-/Volumes/Mavericks}"
    if [ ! -d "$target" ]; then
      echo "usage: $0 /Volumes/<target volume>" >&2
      echo "erase one first, e.g.: diskutil eraseVolume JHFS+ Mavericks disk3s2" >&2
      exit 1
    fi

    mkdir -p "$target/Recovered Items/System/Library/Caches"
    rm -f "/Volumes/OS X Base System"
    hdiutil attach "/Volumes/OS X Install ESD/BaseSystem.dmg" -readonly -noverify

    installer -verbose -pkg /System/Installation/Packages/OSInstall.mpkg -target "$target"
    echo "Done. Reboot and pick $target in the OpenCore picker."
  '';

  fetchInstaller = pkgs.writeShellApplication {
    name = "macos-vm-fetch";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gptfdisk
      python3
      qemu_kvm
    ];
    text = ''
      state=${lib.escapeShellArg stateDir}
      mkdir -p "$state"
      cd "$state"

      esd_sha256=c861fd59e82bf777496809a0d2a9b58f66691ee56738031f55874a3fe1d7c3ff

      if [ ! -f InstallESD.dmg ]; then
        mapfile -t asset < <(python3 ${recoveryHandshake})
        echo "Downloading ''${asset[0]}"
        curl -f --progress-bar "''${asset[0]}" -H "Cookie: AssetToken=''${asset[1]}" \
          -o InstallESD.dmg.part
        # Apple serves the asset over plain HTTP, so this checksum is the only
        # integrity check there is.
        if [ "$(sha256sum InstallESD.dmg.part | cut -d' ' -f1)" != "$esd_sha256" ]; then
          rm -f InstallESD.dmg.part
          echo "InstallESD.dmg checksum mismatch" >&2
          exit 1
        fi
        mv InstallESD.dmg.part InstallESD.dmg
      fi

      # InstallESD.dmg is directly bootable: the volume carries boot.efi,
      # mach_kernel and Packages, so the VM needs the raw HFS+ image and not a
      # createinstallmedia clone (which would need a Mac to build).
      # esd.img carries the install payload (Packages), and BaseSystem.dmg
      # nested inside it is the only bootable half: 10.9's InstallESD volume has
      # no boot.efi of its own.
      if [ ! -f esd.img ]; then
        echo "Converting InstallESD.dmg to a raw disk"
        qemu-img convert -p -f dmg -O raw InstallESD.dmg esd.img.part
        mv esd.img.part esd.img
      fi
      if [ ! -f esd.geometry ]; then
        python3 ${apmGeometry} esd.img > esd.geometry
      fi

      if [ ! -f basesystem.img ]; then
        mnt=$(mktemp -d)
        # HFS+ needs a kernel mount either way, and the symlinks below have to
        # be written as root to keep root:wheel ownership.
        trap 'sudo -n umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true' EXIT

        read -r esd_offset esd_size < esd.geometry
        sudo -n mount -o "ro,loop,offset=$esd_offset,sizelimit=$esd_size" -t hfsplus esd.img "$mnt"
        cp "$mnt/BaseSystem.dmg" BaseSystem.dmg
        sudo -n umount "$mnt"

        echo "Converting BaseSystem.dmg to a raw disk"
        qemu-img convert -p -f dmg -O raw BaseSystem.dmg basesystem.img.part
        mv basesystem.img.part basesystem.img
        rm -f BaseSystem.dmg
        python3 ${apmGeometry} basesystem.img > basesystem.geometry

        # BaseSystem ships /System/Installation/Packages as a symlink to
        # PackagesLink, which only exists on Apple's own install media. Pointing
        # it (and the two BaseSystem files the installer expects beside it) at
        # the mounted ESD volume is the whole merge that createinstallmedia does
        # by copying 5GB around.
        read -r bs_offset bs_size < basesystem.geometry
        sudo -n mount -o "rw,loop,offset=$bs_offset,sizelimit=$bs_size" -t hfsplus basesystem.img "$mnt"
        for payload in Packages BaseSystem.dmg BaseSystem.chunklist; do
          sudo -n rm -rf "$mnt/System/Installation/$payload"
          sudo -n ln -s "/Volumes/OS X Install ESD/$payload" "$mnt/System/Installation/$payload"
        done
        sudo -n install -m 0755 ${guestInstaller} "$mnt/install-mavericks"
        sudo -n umount "$mnt"
        rmdir "$mnt"
        trap - EXIT
      fi

      # Re-wrap each volume in a GPT, in place: the HFS+ volume already starts at
      # LBA 64, which leaves room for the primary GPT, and only the trailing
      # backup header needs the file to grow. Both consumers understand GPT --
      # OVMF finds boot.efi through OpenHfsPlus, and XNU's
      # IOGUIDPartitionScheme publishes the IOMedia the kernel roots from.
      for image in basesystem esd; do
        if [ -f "$image.gpt" ]; then
          continue
        fi
        read -r offset size < "$image.geometry"
        first=$((offset / 512))
        last=$((first + size / 512 - 1))
        truncate -s $(((last + 2048) * 512)) "$image.img"
        sgdisk --zap-all "$image.img" > /dev/null
        sgdisk --set-alignment=1 --new="1:$first:$last" --typecode=1:AF00 \
          --change-name="1:$image" "$image.img" > /dev/null
        touch "$image.gpt"
      done

      echo "Installer ready: $state/basesystem.img + $state/esd.img"
    '';
  };

  launcher = pkgs.writeShellApplication {
    name = "macos-vm";
    runtimeInputs = with pkgs; [
      coreutils
      qemu_kvm
      util-linux
    ];
    text = ''
      state=${lib.escapeShellArg stateDir}
      mkdir -p "$state"

      # OVMF's variable store has to be writable; OpenCore persists its boot
      # selection there.
      if [ ! -f "$state/OVMF_VARS.fd" ]; then
        install -m 0644 ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd "$state/OVMF_VARS.fd"
      fi
      if [ ! -f "$state/disk.img" ]; then
        qemu-img create -f raw "$state/disk.img" ${cfg.diskSize}
      fi

      # shellcheck disable=SC2054  # QEMU flags carry their own commas
      args=(
        -enable-kvm
        -machine q35
        -m ${toString cfg.memory}
        # Penryn keeps macOS on legacy power management instead of XCPM, which is
        # the CPU model old macOS argues with least. Arrow Lake has every
        # feature listed, so `check` is a real assertion here.
        -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check
        -smp ${toString cfg.cores},cores=${toString cfg.cores},sockets=1
        -device isa-applesmc,osk=${lib.escapeShellArg cfg.osk}
        -smbios type=2
        -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd
        -drive if=pflash,format=raw,file="$state/OVMF_VARS.fd"

        # 10.9 has no virtio drivers, so everything hangs off AHCI, USB or e1000.
        -device ich9-ahci,id=sata
        -drive id=oc,if=none,snapshot=on,format=raw,file=${opencoreEsp}
        -device ide-hd,bus=sata.0,drive=oc
        -drive id=hdd,if=none,format=raw,cache=none,aio=io_uring,discard=unmap,file="$state/disk.img"
        -device ide-hd,bus=sata.1,drive=hdd

        # Input hangs off UHCI, not XHCI: 10.9's AppleUSBXHCI only matches real
        # Intel/NEC controllers, so on qemu-xhci the entire USB bus stays dead
        # (no keyboard, no pointer). AppleUSBUHCI matches the ICH9 function.
        # usb-mouse, not usb-tablet: 10.9 ignores the tablet's absolute HID
        # report descriptor (keyboard on the same bus works, the pointer never
        # moves), so the pointer is relative and needs Ctrl+Alt+G to capture.
        -device ich9-usb-uhci1,id=uhci
        -device usb-kbd,bus=uhci.0
        -device usb-mouse,bus=uhci.0
        # Audio sits on the same UHCI bus: QEMU's usb-audio is a full-speed
        # device, so EHCI refuses it. Stereo 48kHz fits in 12Mbps, and 10.9
        # drives it with in-box AppleUSBAudio.
        -audiodev pipewire,id=snd
        -device usb-audio,bus=uhci.0,audiodev=snd

        -netdev user,id=net0
        -device e1000-82545em,netdev=net0,mac=52:54:00:c9:18:27

        -device vmware-svga
        # Deliberately windowed and ungrabbed: QEMU's own -full-screen turns on
        # an input grab that swallows its own Ctrl+Alt+Q accelerator, which
        # leaves no way out. Hyprland's fullscreen binding does the same job
        # without touching the keyboard. Ctrl+Alt+G grabs on demand.
        # zoom-to-fit scales the guest framebuffer into the window instead of
        # cropping it. The guest resolution is fixed at boot and macOS offers no
        # other mode, so without this a window smaller than `resolution` hides
        # the bottom of the screen.
        #
        # The menubar stays visible on purpose: QEMU hangs Ctrl+Alt+G (grab) and
        # Ctrl+Alt+Q (quit) off its menu items, so show-menubar=off silently
        # kills both accelerators and leaves no way to capture the pointer or
        # close the window.
        -display "''${MACOS_VM_DISPLAY:-gtk,zoom-to-fit=on}"
        -monitor "unix:$state/monitor.sock,server,nowait"
      )

      # The installer is two volumes: basesystem boots, esd carries Packages.
      if [ -f "$state/basesystem.gpt" ] && [ -f "$state/esd.gpt" ]; then
        # shellcheck disable=SC2054
        args+=(
          -drive id=bs,if=none,format=raw,file="$state/basesystem.img"
          -device ide-hd,bus=sata.2,drive=bs
          -drive id=esd,if=none,format=raw,file="$state/esd.img"
          -device ide-hd,bus=sata.3,drive=esd
        )
      fi

      # Pin to the P-cores. Mavericks has no idea what an E-core is, and with no
      # guest graphics driver the framebuffer is composited on the CPU, so a
      # vCPU landing on a 4.7GHz E-core shows up as UI stutter.
      exec taskset -c ${cfg.cpuset} qemu-system-x86_64 "''${args[@]}" "$@"
    '';
  };
  # Launched from the app grid it comes up fullscreen on its own workspace,
  # which is most of what "not living in a window" means here.
  desktopItem = pkgs.makeDesktopItem {
    name = "macos-vm";
    desktopName = "macOS Mavericks";
    comment = "OS X 10.9 guest (QEMU/KVM)";
    exec = lib.getExe launcher;
    icon = "computer";
    terminal = false;
    categories = [ "System" ];
    startupWMClass = "qemu-system-x86_64";
  };
in
{
  options.kyan.macosVm = {
    enable = lib.mkEnableOption "the Mavericks (macOS 10.9) QEMU/KVM guest";

    memory = lib.mkOption {
      type = lib.types.int;
      default = 8192;
      description = "Guest RAM in MiB.";
    };

    cores = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Guest core count. Must fit inside `cpuset`.";
    };

    cpuset = lib.mkOption {
      type = lib.types.str;
      default = "0-7";
      description = "Host CPUs the guest is pinned to (P-cores on Arrow Lake-HX).";
    };

    diskSize = lib.mkOption {
      type = lib.types.str;
      default = "64G";
      description = "Size of the sparse raw system disk, created on first launch.";
    };

    resolution = lib.mkOption {
      type = lib.types.str;
      default = "Max";
      description = ''
        Framebuffer mode OpenCore sets before handing off. There is no guest
        graphics driver, so this is fixed for the session and macOS offers no
        other resolution. Higher costs real UI smoothness: every pixel is
        composited on the CPU.
      '';
    };

    systemProductName = lib.mkOption {
      type = lib.types.str;
      default = "iMac14,2";
      description = "SMBIOS model. Must be a Mac that shipped with 10.9.";
    };

    bootArgs = lib.mkOption {
      type = lib.types.str;
      default = "-v";
      description = ''
        Kernel boot-args. Verbose by default: on a driverless framebuffer a
        panic is otherwise a black screen with nothing to read.
      '';
    };

    osk = lib.mkOption {
      type = lib.types.str;
      default = "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc";
      description = ''
        Apple SMC unlock key handed to isa-applesmc. macOS reads it during boot
        and halts without it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # macOS pokes MSRs KVM does not implement; without this the guest panics
    # early in the kernel.
    boot.extraModprobeConfig = "options kvm ignore_msrs=1 report_ignored_msrs=0";

    environment.systemPackages = [
      launcher
      fetchInstaller
      desktopItem
    ];
  };
}
