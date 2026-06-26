{ pkgs, ... }:
{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
        # Render the boot menu at the panel's highest available resolution so
        # the text is crisp instead of a stretched low-res framebuffer.
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
      # systemd-boot auto-detects the Windows EFI entry for dual-boot.
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
    enableNotifications = true; # Noctalia toast when it kills something
    extraArgs = [
      # NEVER sacrifice the compositor or shell — losing these collapses the whole
      # session. Matched against /proc/*/comm (truncated to 15 chars), so list the
      # wrapped names too.
      "--avoid"
      "^(Hyprland|\\.Hyprland-wrapp|noctalia|quickshell|hyprpolkitagent|sshd|systemd)$"
      # Prefer to reap the heavy gaming/Wine processes first.
      "--prefer"
      "^(BeamNG|wine|wineserver|gamescope)$"
    ];
  };

  # Cap crash-dump storage. Games/compositor crashes (Proton, gamescope, …)
  # produce large coredumps that are rarely useful here and otherwise grow
  # unbounded under /var/lib/systemd/coredump.
  systemd.coredump.settings.Coredump.MaxUse = "256M";
}
