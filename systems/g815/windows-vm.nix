{ pkgs, lib, ... }:
let
  # The bare-metal Windows 11 install, booted as a KVM guest without ever
  # writing to it. QEMU opens the whole NVMe disk read-only as the backing file
  # of a qcow2 overlay on ext4, so every guest write lands in the overlay. The
  # overlay is recreated on each start: bare-metal Windows (and the host's own
  # ntfs3 mount) change the disk under it between sessions, and an overlay over
  # a changed base is garbage.
  disk = "/dev/disk/by-id/nvme-WD_PC_SN5000S_SDEQNSJ-1T00-1002_25458D806996";
  state = "/var/lib/windows-vm";
  ovmf = pkgs.OVMFFull.fd;

  # Host mounts of partitions on that disk that Windows owns. / and /boot sit
  # on it too and stay mounted: the guest only ever sees its own overlay copy.
  windowsMounts = [ "mnt-windows.mount" ];

  # Root free space the overlay may never take. The launcher wants 5G on top
  # of this to start at all.
  minFreeGiB = 10;

  launcher = pkgs.writeShellApplication {
    name = "windows-vm-run";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      mtools
      ntfs3g
      qemu_kvm
      socat
      swtpm
      util-linux
    ];
    text = ''
      state=${state}
      disk=$(readlink -f ${disk})
      mkdir -p "$state/tpm"

      # Every Windows partition on the disk must be unmounted, or the guest
      # boots from a volume the host is changing underneath it.
      for part in /sys/block/"$(basename "$disk")"/*/partition; do
        dev=/dev/$(basename "$(dirname "$part")")
        [ "$(blkid -o value -s TYPE "$dev" || true)" = ntfs ] || continue
        if findmnt -rn -S "$dev" >/dev/null; then
          echo "$dev is mounted on the host, refusing to boot" >&2
          exit 1
        fi
        # A hibernated or Fast Startup session lives in hiberfil.sys; booting
        # anything else on top of it throws that session away.
        hdr=$(ntfscat "$dev" hiberfil.sys 2>/dev/null | head -c 4 | tr '[:upper:]' '[:lower:]' || true)
        if [ "$hdr" = hibr ]; then
          echo "$dev holds a hibernated Windows session, refusing to boot" >&2
          exit 1
        fi
      done

      # The last session's overlay is garbage now, and must not count against
      # the free-space check below.
      rm -f "$state/overlay.qcow2"

      avail=$(df --output=avail -B1G "$state" | tail -1)
      if [ "$avail" -lt $((${toString minFreeGiB} + 5)) ]; then
        echo "only ''${avail}G free under $state, refusing to start" >&2
        exit 1
      fi

      qemu-img create -q -f qcow2 -F raw -b "$disk" "$state/overlay.qcow2"

      # The shared ESP's \EFI\BOOT\BOOTX64.EFI is not the Windows loader, and an
      # empty OVMF NVRAM only tries that fallback path. A throwaway ESP whose
      # fallback is bootmgfw.efi, next to a copy of the BCD it reads, boots
      # Windows directly; the BCD finds C: by disk and partition GUID, which
      # the passed-through disk keeps.
      # OVMF only scans a fixed disk for an ESP inside a partition table, so a
      # bare FAT image is invisible to it.
      esp="$state/esp.img"
      rm -f "$esp"
      truncate -s 100M "$esp"
      printf 'label: gpt\nstart=2048, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\n' | sfdisk -q "$esp"
      mformat -i "$esp@@1M" -F -T 202752 -v VMESP ::
      mmd -i "$esp@@1M" ::/EFI ::/EFI/BOOT ::/EFI/Microsoft
      mcopy -s -i "$esp@@1M" /boot/EFI/Microsoft/Boot ::/EFI/Microsoft/
      mcopy -i "$esp@@1M" /boot/EFI/Microsoft/Boot/bootmgfw.efi ::/EFI/BOOT/BOOTX64.EFI

      # No keys enrolled, so Secure Boot is off.
      if [ ! -f "$state/vars.fd" ]; then
        install -m 0600 ${ovmf}/FV/OVMF_VARS.fd "$state/vars.fd"
      fi

      swtpm socket --tpm2 --tpmstate dir="$state/tpm" \
        --ctrl type=unixio,path="$state/swtpm.sock" --terminate &
      for _ in $(seq 50); do [ -S "$state/swtpm.sock" ] && break; sleep 0.1; done

      serial=$(cat /sys/block/"$(basename "$disk")"/device/serial)

      # shellcheck disable=SC2054  # QEMU flags carry their own commas
      args=(
        -name windows-vm
        -enable-kvm
        -machine q35,smm=on
        -global driver=cfi.pflash01,property=secure,value=on
        # A named model, not `host`: on this hybrid Arrow Lake part the
        # Windows kernel resets itself within seconds of winload with `host`
        # plus any hv_* flag, and hangs at the boot logo with plain `host`.
        # hv_crash makes QEMU log the bugcheck code if the guest ever panics.
        -cpu Skylake-Client-v4,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_time,hv_crash
        -smp 6,cores=6,sockets=1
        -m 8192
        -rtc base=localtime
        -drive if=pflash,format=raw,readonly=on,file=${ovmf}/FV/OVMF_CODE.fd
        -drive if=pflash,format=raw,file="$state/vars.fd"
        -chardev socket,id=tpm,path="$state/swtpm.sock"
        -tpmdev emulator,id=tpm0,chardev=tpm
        -device tpm-tis,tpmdev=tpm0

        -drive id=esp,if=none,format=raw,file="$state/esp.img"
        -device ide-hd,bus=ide.0,drive=esp,bootindex=0
        # Read-only is the backing node's own flag, not just qcow2's default.
        -blockdev driver=host_device,node-name=base,filename="$disk",read-only=on,cache.direct=on,aio=native
        # Guest TRIM frees overlay clusters on the host, so a deleted build
        # tree gives its space back instead of pinning it until the next start.
        -blockdev driver=file,node-name=ovl,filename="$state/overlay.qcow2",discard=unmap
        -blockdev driver=qcow2,node-name=win,file=ovl,backing=base,discard=unmap,detect-zeroes=unmap
        # Emulated NVMe binds Windows' inbox stornvme, the driver it already
        # boots from on bare metal (no VMD on this laptop).
        -device nvme,drive=win,serial="$serial",bootindex=1

        -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22
        -device e1000e,netdev=net0,mac=52:54:00:57:31:01
        -device qemu-xhci
        -device usb-tablet
        -vga std
        -display vnc=127.0.0.1:1
        -monitor unix:"$state/monitor.sock",server,nowait
      )
      # The overlay takes every guest write, and one WinUI build grew it past
      # 30G, so power the guest off before it eats the host's root: ACPI first,
      # then SIGINT (QEMU's quit) if it ignores that for a minute. $$ is QEMU
      # itself once the exec below has run.
      (
        while sleep 10 && kill -0 $$ 2>/dev/null; do
          avail=$(df --output=avail -B1G "$state" | tail -1)
          [ "$avail" -lt ${toString minFreeGiB} ] || continue
          echo "only ''${avail}G left under $state, powering the guest off" >&2
          echo system_powerdown | socat - unix-connect:"$state/monitor.sock" >/dev/null || true
          sleep 60
          kill -INT $$ 2>/dev/null || true
          exit 0
        done
      ) &

      # P-cores only: a vCPU on an E-core stalls the Windows compositor.
      exec taskset -c 0-5 qemu-system-x86_64 "''${args[@]}"
    '';
  };

  # Run once per start, as the user whose key the guest's sshd trusts. A
  # pagefile, Windows Update and the user's autostart launchers (Steam resumed
  # a 67G game download into D:) write gigabytes into the overlay that nothing
  # keeps, so the guest drops the pagefile, turns automatic updates off by
  # policy (wuauserv refuses Set-Service), empties its HKCU Run key, and
  # reboots once. A fresh overlay's
  # first boot reboots by itself too, hence the try around Restart-Computer.
  prep = pkgs.writeShellApplication {
    name = "windows-vm-prep";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
    ];
    text = ''
      guest() {
        ssh -n -p 2222 -o BatchMode=yes -o ConnectTimeout=5 -o LogLevel=ERROR \
          -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          kyan@127.0.0.1 "$@"
      }
      wait_ssh() {
        for _ in $(seq 60); do guest exit 2>/dev/null && return 0; sleep 5; done
        echo "guest ssh never came up" >&2
        exit 1
      }
      wait_ssh
      guest "Get-CimInstance Win32_ComputerSystem | Set-CimInstance -Property @{AutomaticManagedPagefile=\$false}; \
        Get-CimInstance Win32_PageFileSetting | Remove-CimInstance; \
        New-Item -Force HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU | \
          New-ItemProperty -Name NoAutoUpdate -Value 1 -PropertyType DWord -Force | Out-Null; \
        Stop-Service wuauserv,UsoSvc,BITS -Force -ErrorAction SilentlyContinue; \
        Remove-Item HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run; \
        New-Item HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run | Out-Null; \
        try { Restart-Computer -Force -ErrorAction Stop } catch { }"
      # Wait for sshd to go down with the old boot before waiting for it back.
      for _ in $(seq 60); do guest exit 2>/dev/null || break; sleep 2; done
      wait_ssh
      guest "if (Test-Path C:\\pagefile.sys) { 'pagefile still present' } else { 'pagefile off' }"
    '';
  };
in
{
  environment.systemPackages = [ prep ];

  systemd.services.windows-vm-prep = {
    description = "Prepare a fresh Windows guest overlay";
    after = [ "windows-vm.service" ];
    bindsTo = [ "windows-vm.service" ];
    wantedBy = [ "windows-vm.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "kyandesutter";
      ExecStart = lib.getExe prep;
    };
  };

  # sudo systemctl start windows-vm, then `ssh -p 2222 kyan@127.0.0.1` here
  # (from the macbook, ProxyCommand through g815); VNC on 127.0.0.1:5901.
  systemd.services.windows-vm = {
    description = "Bare-metal Windows 11 as a KVM guest over a throwaway overlay";
    # Stopped, never masked: they come back when the guest exits.
    conflicts = windowsMounts;
    after = windowsMounts;
    serviceConfig = {
      ExecStart = lib.getExe launcher;
      ExecStopPost = "-${pkgs.systemd}/bin/systemctl start --no-block ${lib.concatStringsSep " " windowsMounts}";
      KillSignal = "SIGINT";
      # SIGINT is QEMU's quit, but the space guard is a background subshell,
      # which ignores it; mixed sends it to QEMU alone and SIGKILLs the rest.
      KillMode = "mixed";
      TimeoutStopSec = 30;
    };
  };
}
