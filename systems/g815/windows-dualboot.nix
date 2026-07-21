{ pkgs, ... }:
let
  # One-shot "reboot into Windows" helper. Limine — unlike systemd-boot — does
  # NOT implement systemd's Boot Loader Interface, so `systemctl reboot
  # --boot-loader-entry=` (the old mechanism) can't drive a one-shot Windows
  # boot. Instead we set a UEFI BootNext directly with efibootmgr: reuse the
  # firmware's existing "Windows Boot Manager" entry if present, otherwise create
  # a one-shot entry pointing at bootmgfw.efi on the ESP (Windows shares NixOS's
  # ESP here). BootNext is honoured once by the firmware and then cleared, so the
  # standing default (Limine → latest NixOS) is left untouched — same semantics
  # as the old LoaderEntryOneShot flow, but bootloader-agnostic.
  reboot-to-windows = pkgs.writeShellApplication {
    name = "reboot-to-windows";
    runtimeInputs = [
      pkgs.efibootmgr
      pkgs.gawk # awk
      pkgs.util-linux # findmnt, lsblk
      pkgs.coreutils
      pkgs.systemd # systemctl
    ];
    text = ''
      num=$(efibootmgr | awk '/Windows Boot Manager/ { n=$1; sub(/^Boot/,"",n); sub(/\*.*/,"",n); print n; exit }')
      if [ -n "''${num:-}" ]; then
        efibootmgr --bootnext "$num" >/dev/null
      else
        # No firmware entry yet — create a one-shot one pointing at the Windows
        # bootloader on whatever partition /boot lives on.
        src=$(findmnt -no SOURCE /boot)
        bn=$(basename "$src")
        part=$(cat "/sys/class/block/$bn/partition")
        disk=$(lsblk -no PKNAME "$src" | head -1)
        efibootmgr --create-next --disk "/dev/$disk" --part "$part" \
          --loader '\EFI\Microsoft\Boot\bootmgfw.efi' --label 'Windows Boot Manager' >/dev/null
      fi
      systemctl reboot
    '';
  };
in
{
  # Windows chainload. Host-specific (this laptop dual-boots the gaming Windows
  # install; other hosts are NixOS-only). extraEntries is APPENDED after the
  # auto-generated NixOS generation entries, giving the closest achievable order
  # to "NixOS first, Windows after" (the module emits all generations as one
  # contiguous block, so entries can't be wedged between current and older
  # generations). Windows and NixOS share this ESP, so boot():/// — the disk
  # Limine itself booted from — resolves without a cross-disk UUID.
  boot.loader.limine.extraEntries = ''
    /Windows 11
        comment: Chainload the Windows Boot Manager
        protocol: efi
        path: boot():///EFI/Microsoft/Boot/bootmgfw.efi
  '';

  # One-click "boot into Windows" support. DMS's powermenu / launcher desktop
  # entry (the parity replacement for noctalia's old session button) starts
  # this oneshot service, which runs the reboot-to-windows helper as root
  # (setting the UEFI BootNext needs privilege). The service — not a setuid
  # wrapper — keeps the privileged action declarative and lets a scoped
  # polkit rule below waive the password prompt.
  systemd.services.reboot-to-windows = {
    description = "One-shot reboot into Windows via UEFI BootNext";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${reboot-to-windows}/bin/reboot-to-windows";
    };
  };

  # Passwordless one-click for the "Windows" session button, scoped to the
  # active local wheel session (systemd manage-units defaults to a password
  # prompt — waived only for this one unit). The "BIOS" button's
  # firmware-setup grant is generic and lives in mixins/boot.nix.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "reboot-to-windows.service" &&
          subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
