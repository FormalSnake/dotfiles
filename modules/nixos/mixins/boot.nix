{ pkgs, ... }:
let
  # Fallout Limine theme (https://github.com/Neptune3013/fallout-limine-theme):
  # vault-boy backdrop + retro PHXEGA8 bitmap font. Pinned via fetchFromGitHub so
  # no binaries live in the repo. The upstream install script edits /boot
  # imperatively — useless on NixOS, which regenerates limine.conf on every
  # activation — so the theme is expressed through the module's style.* options
  # instead (see the limine block below).
  fallout-limine = pkgs.fetchFromGitHub {
    owner = "Neptune3013";
    repo = "fallout-limine-theme";
    rev = "9a777b932de07dce60e58b2a1162b7d41ecfd2e9";
    hash = "sha256-ZZb+x/dglrGEGljeDeHgr809qbFi9dc6ipfU53DIHwE=";
  };

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
  boot = {
    loader = {
      limine = {
        enable = true;
        # Parity with the old systemd-boot configurationLimit: keep the last few
        # generations selectable in the menu (older ones stay on disk).
        maxGenerations = 3;

        # Theming: the Fallout theme (see fallout-limine in the let block above).
        # Limine renders pre-boot, so — like SDDM — this is the theming model's
        # *static fallback* tier, not the matugen/DMS runtime pipeline
        # (which would mean a full rebuild on every wallpaper change).
        #
        # term_font / term_font_size have no dedicated module option, so the
        # PHXEGA8 bitmap font goes via extraConfig + additionalFiles (copied to
        # /boot/limine/, referenced as boot():/limine/…). Everything else maps
        # onto the module's style.* options below. Colour values are taken
        # verbatim from the theme's Limine.txt.
        extraConfig = ''
          term_font: boot():/limine/PHXEGA8.F14
          term_font_size: 8x14
        '';
        additionalFiles."PHXEGA8.F14" = "${fallout-limine}/Fallout_limine/PHXEGA8.F14";
        style = {
          # High-res (original GRUB) variant — sharper on the laptop panel than
          # the compressed jpg the theme ships by default.
          wallpapers = [ "${fallout-limine}/Fallout_limine/high-res-bg/background.png" ];
          wallpaperStyle = "stretched";
          interface = {
            branding = ""; # drop Limine's "Limine x.y.z (…)" title
            helpHidden = true; # hide the ARROWS/ENTER/S-Firmware key hints
          };
          graphicalTerminal = {
            font.scale = "2x2";
            margin = 0; # term_background covers the whole screen, uniform
            foreground = "67d97a"; # boot-entry text (Pip-Boy green)
            background = "9935453b"; # TTRRGGBB — 99 = ~40% opaque green tint
            brightBackground = "ffffff";
            palette = "000000;5c110c;074224;4d1c0d;00594d;f5c2e7;16de6d;989e9b";
            brightPalette = "2f3030;ff0000;16de6d;f7cd34;0ddeaa;f5c2e7;16de6d;ffffff";
          };
        };

        # Windows chainload. extraEntries is APPENDED after the auto-generated
        # NixOS generation entries, giving the closest achievable order to
        # "NixOS first, Windows after" (the module emits all generations as one
        # contiguous block, so entries can't be wedged between current and older
        # generations). Windows and NixOS share this ESP, so boot():/// — the
        # disk Limine itself booted from — resolves without a cross-disk UUID.
        extraEntries = ''
          /Windows 11
              comment: Chainload the Windows Boot Manager
              protocol: efi
              path: boot():///EFI/Microsoft/Boot/bootmgfw.efi
        '';
      };
      efi.canTouchEfiVariables = true;
      timeout = 4;
    };

    # CachyOS kernel (provided by the chaotic overlay imported in ../default.nix).
    kernelPackages = pkgs.linuxPackages_cachyos;

    kernelParams = [
      # Required for the NVIDIA open module + Wayland; also helps suspend.
      "nvidia-drm.modeset=1"
    ];

    # Larger /tmp helps big game/shader builds; back it with tmpfs.
    tmp.useTmpfs = true;
    tmp.tmpfsSize = "50%";

    # Cap the dirty page-cache backlog. The defaults (dirty_ratio=20) let up to
    # ~20% of RAM (~6 GB here) go dirty before the kernel forces synchronous
    # writeback on every writing process. When that backlog targets a slow
    # device — e.g. a Steam download committing to the USB external SSD — the
    # whole system stalls in bursts, which shows up in games as periodic
    # slow-motion/freezes. A small absolute cap keeps any single slow device
    # from building a multi-gigabyte backlog. (dirty_bytes overrides
    # dirty_ratio when nonzero.)
    kernel.sysctl = {
      "vm.dirty_bytes" = 268435456; # 256 MB
      "vm.dirty_background_bytes" = 67108864; # 64 MB — start flushing early

      # CachyOS-Settings parity. The CachyOS kernel ships via chaotic, but its
      # companion CachyOS-Settings package (sysctl/udev/tmpfiles) is Arch-only
      # and NOT applied on NixOS, so replicate the load-bearing tweaks here.
      # Values verbatim from CachyOS-Settings 70-cachyos-settings.conf.
      "vm.swappiness" = 100; # zram is fast → lean on it before evicting page cache
      "vm.page-cluster" = 0; # zram: fault one page at a time, no swap readahead
      "vm.vfs_cache_pressure" = 50; # retain dentry/inode cache longer
      "vm.dirty_writeback_centisecs" = 1500; # flush old dirty data less often
      "kernel.nmi_watchdog" = 0; # small perf + power win, one less timer
      "net.core.netdev_max_backlog" = 4096; # deeper RX queue; fewer dropped packets
      "fs.file-max" = 2097152; # raise the global file-handle ceiling
    };
  };

  # Transparent-hugepage defrag policy from CachyOS-Settings (thp.conf). Helps
  # tcmalloc-using apps (Chromium/Electron) without the latency spikes of the
  # default synchronous "madvise"/"always" defrag.
  systemd.tmpfiles.rules = [
    "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
  ];

  # I/O schedulers, matching CachyOS-Settings 60-ioschedulers.rules. NixOS
  # leaves NVMe on "none"; kyber adds light latency-aware ordering. mq-deadline
  # on the external USB Steam SSD (sd*) curbs the writeback bursts that the
  # dirty_bytes cap above also targets.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
  '';

  # zram swap — cheap responsiveness win on a 32 GB gaming box.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    priority = 5; # used before the disk swapfile below (RAM-speed first)
  };

  # Real overflow tier. zram is *compressed RAM*, not extra capacity — once the
  # 32 GB fills, zram can't help because its compressed pages live in that same
  # RAM. With no disk swap the kernel then OOM-kills processes (it took out
  # Noctalia during a BeamNG-with-traffic session). This 32 GB swapfile on the
  # ext4 root gives genuine spill space so a transient spike pages cold anon
  # memory to NVMe instead of reaping the desktop. Priority 1 (< zram's 5) so
  # it's only touched once zram is exhausted — the slow tier, used last.
  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024; # MiB → 32 GiB
      priority = 1;
    }
  ];

  # earlyoom — userspace OOM guard. The kernel's own OOM-killer only fires at
  # ~0 bytes free and picks purely by oom_score, which is how a BeamNG-with-
  # traffic spike got Noctalia/Spotify reaped instead of the game. earlyoom acts
  # earlier (at the free thresholds below) and SIGTERMs the biggest hog — almost
  # always the game itself — so a memory blowout costs you the game, never the
  # desktop session. The swapfile above is the capacity fix; this is the
  # graceful-failure backstop for when even that fills.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10; # SIGTERM when free RAM drops under 10% …
    freeSwapThreshold = 15; # … and free swap under 15% (disk-swap thrash is painful)
    enableNotifications = true; # DMS toast when it kills something
    extraArgs = [
      # NEVER sacrifice the compositor or shell — losing these collapses the whole
      # session. Matched against /proc/*/comm (truncated to 15 chars), so list the
      # wrapped names too — nixpkgs' wrapProgram/wrapQtAppsHook hide the real
      # binary as `.<name>-wrapped` and install the wrapper at the original
      # name, so DMS's actual running comms are `.dms-wrapped` (dms.service's
      # `dms run --session`) and `.quickshell-wra` (its quickshell renderer,
      # `.quickshell-wrapped` truncated) — verified via strace, not the
      # `dms`/`quickshell` names the wrapper scripts are installed under.
      "--avoid"
      "^(niri|\\.dms-wrapped|\\.quickshell-wra|polkit-kde-aut|sshd|systemd)$"
      # Prefer to reap the heavy gaming/Wine processes first.
      "--prefer"
      "^(BeamNG|wine|wineserver|gamescope)$"
    ];
  };

  # Cap crash-dump storage. Games/compositor crashes (Proton, gamescope, …)
  # produce large coredumps that are rarely useful here and otherwise grow
  # unbounded under /var/lib/systemd/coredump.
  systemd.coredump.settings.Coredump.MaxUse = "256M";

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

  # Passwordless one-click for the two session buttons, scoped to the active
  # local wheel session:
  #   • "Windows" starts reboot-to-windows.service (systemd manage-units, which
  #     defaults to a password prompt — waived only for that one unit).
  #   • "BIOS" runs `systemctl reboot --firmware-setup`, which sets the
  #     boot-to-firmware-UI EFI indication via logind (also auth_admin by
  #     default). The plain Reboot action is already allowed for the active
  #     local session, so only the firmware-setup indication needs a grant.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "reboot-to-windows.service" &&
          subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.login1.set-reboot-to-firmware-setup" &&
          subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
