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

      # Internal eDP-1 panel (i915) goes "lit but black" after a long idle on
      # this hybrid laptop. The BOE NE180QDM panel is scanned out by the iGPU
      # while its backlight is driven by nvidia_wmi_ec_backlight (stays at 100% →
      # "lit"). The actual failure is at modeset: the kernel logs
      #   i915 0000:00:02.0: [drm] PHY A failed to request refclk
      # on every attempt to bring the panel back — the eDP PHY can't get its
      # reference clock, so no image, even though the connector reports
      # connected/enabled/dpms On. No compositor (hyprctl) command recovers it;
      # only a full GPU re-init (reboot / suspend-resume) does. The cause is i915
      # display power management gating the PHY refclk over idle:
      #   • enable_dc=0  — keep the display power wells up (don't enter DC5/DC6),
      #                    which is what gates the refclk; primary fix.
      #   • enable_psr=0 — disable Panel Self Refresh (same failure family).
      # Cost is a little idle power on the iGPU; no other behavioural change.
      "i915.enable_dc=0"
      "i915.enable_psr=0"
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
