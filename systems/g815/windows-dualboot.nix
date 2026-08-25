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

  # One shared Modrinth instance across both OSes: the NixOS profile directory
  # IS the Windows one, symlinked whole. Mods, config, options, keybinds,
  # waypoints and caches are then a single set of files instead of two that
  # drift, and either side can install a mod.
  #
  # Needs /mnt/windows read-write (below). Minecraft and most mods rewrite
  # their config through a temp file and a rename, which a read-only source
  # cannot serve; Sodium raises rather than degrading when that write fails.
  #
  # Run once per profile, with Modrinth closed. An existing local profile
  # directory is moved to <profile>.local rather than deleted; delete it
  # yourself once the linked instance has launched.
  link-minecraft-to-windows = pkgs.writeShellApplication {
    name = "link-minecraft-to-windows";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux # findmnt
    ];
    text = ''
      profile="''${1:-Fabric 26.2}"
      win="/mnt/windows/Users/Kyan/AppData/Roaming/ModrinthApp/profiles/$profile"
      lin="$HOME/.local/share/ModrinthApp/profiles/$profile"

      case ",$(findmnt -no OPTIONS /mnt/windows)," in
        *,rw,*) ;;
        *)
          echo "/mnt/windows is not read-write: NTFS is dirty, so ntfs3 refused it." >&2
          echo "Boot Windows and shut down cleanly with Fast Startup and hibernation off." >&2
          exit 1
          ;;
      esac

      [ -d "$win" ] || { echo "no such Windows profile: $win" >&2; exit 1; }

      if [ -L "$lin" ]; then
        if [ "$(readlink "$lin")" = "$win" ]; then
          echo "already linked: $lin -> $win"
          exit 0
        fi
        rm "$lin"
      elif [ -e "$lin" ]; then
        if [ -e "$lin.local" ]; then
          echo "$lin.local is in the way; move it aside" >&2
          exit 1
        fi
        mv "$lin" "$lin.local"
        echo "moved the local profile to $lin.local"
      fi

      mkdir -p "$(dirname "$lin")"
      ln -s "$win" "$lin"
      echo "linked $lin -> $win"
    '';
  };
in
{
  environment.systemPackages = [ link-minecraft-to-windows ];

  # Windows C:, mounted read-write so the shared Modrinth profile above can be
  # one set of files rather than two kept in step by hand.
  #
  # Read-write holds only while the NTFS volume is clean. ntfs3 refuses a dirty
  # volume outright rather than falling back to read-only, so if Fast Startup
  # or hibernation comes back on (either one parks the volume dirty on every
  # Windows shutdown) this mount vanishes at boot and the profile symlink
  # dangles. Both are off on the Windows side; keep them off. A dirty bit left
  # by an unclean shutdown clears the same way, by booting Windows and shutting
  # it down properly.
  # nofail keeps a detached or unreadable volume from holding up boot.
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/D0409F99409F84BE";
    fsType = "ntfs3";
    options = [
      "rw"
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
