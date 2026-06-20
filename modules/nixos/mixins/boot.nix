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
    };
  };

  # zram swap — cheap responsiveness win on a 32 GB gaming box.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Cap crash-dump storage. Games/compositor crashes (Proton, gamescope, …)
  # produce large coredumps that are rarely useful here and otherwise grow
  # unbounded under /var/lib/systemd/coredump.
  systemd.coredump.settings.Coredump.MaxUse = "256M";
}
