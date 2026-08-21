{ pkgs, ... }:
let
  # One-shot "reboot into Windows" helper. Limine (unlike systemd-boot) does
  # NOT implement systemd's Boot Loader Interface, so `systemctl reboot
  # --boot-loader-entry=` (the old mechanism) can't drive a one-shot Windows
  # boot. Instead we set a UEFI BootNext directly with efibootmgr: reuse the
  # firmware's existing "Windows Boot Manager" entry if present, otherwise create
  # a one-shot entry pointing at bootmgfw.efi on the ESP (Windows shares NixOS's
  # ESP here). BootNext is honoured once by the firmware and then cleared, so the
  # standing default (Limine → latest NixOS) is left untouched. Same semantics
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
        # No firmware entry yet: create a one-shot one pointing at the Windows
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

  # Share the Windows Modrinth instance's content with the NixOS one instead of
  # keeping two copies of the same modpack in step by hand. mods,
  # resourcepacks and shaderpacks become symlinks into /mnt/windows: the game
  # only reads those, so the read-only NTFS mount is enough, and Windows stays
  # the single place mods get installed or updated.
  #
  # config, options.txt and servers.dat are copied instead. Mods write their
  # config as they run, and Minecraft rewrites options.txt and servers.dat
  # through a temp file and a rename, none of which survives a read-only
  # source. Sodium in particular raises rather than degrading when its config
  # write fails. Copying means Windows seeds them once and the NixOS side owns
  # them from there.
  #
  # Re-run after installing or updating mods on the Windows side. Repeat runs
  # are fine; the copied files are overwritten from Windows each time.
  sync-minecraft-from-windows = pkgs.writeShellApplication {
    name = "sync-minecraft-from-windows";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      profile="''${1:-Fabric 26.2}"
      win="/mnt/windows/Users/Kyan/AppData/Roaming/ModrinthApp/profiles/$profile"
      lin="$HOME/.local/share/ModrinthApp/profiles/$profile"

      [ -d "$win" ] || { echo "no such Windows profile: $win" >&2; exit 1; }
      [ -d "$lin" ] || { echo "create the instance in Modrinth first: $lin" >&2; exit 1; }

      for dir in mods resourcepacks shaderpacks; do
        if [ -L "$lin/$dir" ] || [ ! -e "$lin/$dir" ]; then
          ln -sfn "$win/$dir" "$lin/$dir"
        elif rmdir "$lin/$dir" 2>/dev/null; then
          ln -s "$win/$dir" "$lin/$dir"
        else
          echo "$lin/$dir holds local files; move it aside and re-run" >&2
          exit 1
        fi
      done

      cp -rT --no-preserve=mode,ownership "$win/config" "$lin/config"
      for file in options.txt servers.dat; do
        cp --no-preserve=mode,ownership "$win/$file" "$lin/$file"
      done

      echo "linked mods, resourcepacks, shaderpacks; copied config, options.txt, servers.dat"
    '';
  };
in
{
  environment.systemPackages = [ sync-minecraft-from-windows ];

  # Windows C:, for reading and writing the Windows install's own files rather
  # than keeping a second copy on the NixOS side (Modrinth instance content is
  # the reason it exists; see kyan.minecraft in ./default.nix).
  #
  # Read-only on purpose. ntfs3 (in-kernel, no FUSE) refuses a read-write mount
  # while the volume is dirty, and Fast Startup leaves it dirty after every
  # Windows shutdown, so a read-write mount here would fail on any normal boot
  # rather than only after a crash. Read-only also removes the standing risk of
  # two operating systems writing the same NTFS metadata. Windows therefore
  # owns everything under here; the NixOS side reads and copies.
  # nofail keeps a detached or unreadable volume from holding up boot.
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/D0409F99409F84BE";
    fsType = "ntfs3";
    options = [
      "ro"
      "uid=1000"
      "gid=100"
      "umask=022"
      "windows_names"
      "noatime"
      "nofail"
    ];
  };

  # Windows chainload. Host-specific (this laptop dual-boots the gaming Windows
  # install; other hosts are NixOS-only). extraEntries is APPENDED after the
  # auto-generated NixOS generation entries, giving the closest achievable order
  # to "NixOS first, Windows after" (the module emits all generations as one
  # contiguous block, so entries can't be wedged between current and older
  # generations). Windows and NixOS share this ESP, so boot():/// (the disk
  # Limine itself booted from) resolves without a cross-disk UUID.
  boot.loader.limine.extraEntries = ''
    /Windows 11
        comment: Chainload the Windows Boot Manager
        protocol: efi
        path: boot():///EFI/Microsoft/Boot/bootmgfw.efi
  '';

  # One-click "boot into Windows" support. DMS's powermenu / launcher desktop
  # entry (the parity replacement for noctalia's old session button) starts
  # this oneshot service, which runs the reboot-to-windows helper as root
  # (setting the UEFI BootNext needs privilege). The service (not a setuid
  # wrapper) keeps the privileged action declarative and lets a scoped
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
  # prompt, waived only for this one unit). The "BIOS" button's
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
