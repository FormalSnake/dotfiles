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

  launcher = pkgs.writeShellApplication {
    name = "windows-vm-run";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      mtools
      ntfs3g
      qemu_kvm
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

      avail=$(df --output=avail -B1G "$state" | tail -1)
      if [ "$avail" -lt 8 ]; then
        echo "only ''${avail}G free under $state, refusing to start" >&2
        exit 1
      fi

      rm -f "$state/overlay.qcow2"
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

      if [ ! -f "$state/OVMF_VARS.fd" ]; then
        install -m 0600 ${ovmf}/FV/OVMF_VARS.ms.fd "$state/OVMF_VARS.fd"
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
        -cpu host,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_time,hv_vpindex,hv_synic,hv_stimer,hv_frequencies,hv_tlbflush,hv_ipi
        -smp 8,cores=8,sockets=1
        -m 12288
        -rtc base=localtime
        -drive if=pflash,format=raw,readonly=on,file=${ovmf}/FV/OVMF_CODE.ms.fd
        -drive if=pflash,format=raw,file="$state/OVMF_VARS.fd"
        -chardev socket,id=tpm,path="$state/swtpm.sock"
        -tpmdev emulator,id=tpm0,chardev=tpm
        -device tpm-tis,tpmdev=tpm0

        -drive id=esp,if=none,format=raw,file="$state/esp.img"
        -device ide-hd,bus=ide.0,drive=esp,bootindex=0
        # Read-only is the backing node's own flag, not just qcow2's default.
        -blockdev driver=host_device,node-name=base,filename="$disk",read-only=on,cache.direct=on,aio=native
        -blockdev driver=file,node-name=ovl,filename="$state/overlay.qcow2"
        -blockdev driver=qcow2,node-name=win,file=ovl,backing=base
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
      # P-cores only: a vCPU on an E-core stalls the Windows compositor.
      exec taskset -c 0-7 qemu-system-x86_64 "''${args[@]}"
    '';
  };
in
{
  # sudo systemctl start windows-vm, then `ssh -p 2222 kyan@127.0.0.1` here or
  # `ssh windows-vm` from the macbook; VNC on 127.0.0.1:5901 for the console.
  systemd.services.windows-vm = {
    description = "Bare-metal Windows 11 as a KVM guest over a throwaway overlay";
    # Stopped, never masked: they come back when the guest exits.
    conflicts = windowsMounts;
    after = windowsMounts;
    serviceConfig = {
      ExecStart = lib.getExe launcher;
      ExecStopPost = "-${pkgs.systemd}/bin/systemctl start --no-block ${lib.concatStringsSep " " windowsMounts}";
      KillSignal = "SIGINT";
      TimeoutStopSec = 30;
    };
  };
}
