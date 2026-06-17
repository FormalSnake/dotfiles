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
