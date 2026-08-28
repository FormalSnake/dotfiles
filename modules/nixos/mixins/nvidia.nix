{ config, lib, ... }:
let
  cfg = config.kyan.nvidia;
in
{
  # Gated so an Intel-only host can import this bundle untouched: the NVIDIA
  # kernel module would otherwise build for hardware that isn't there. g815
  # flips this on in systems/g815/default.nix.
  options.kyan.nvidia.enable = lib.mkEnableOption "NVIDIA dGPU stack";

  config = lib.mkIf cfg.enable {
    # Builds the NVIDIA kernel module against boot.kernelPackages (CachyOS).
    services.xserver.videoDrivers = [ "nvidia" ];

    # nvidia-drm.modeset=1 is required for the open module + Wayland.
    # acpi_backlight=native: with the MUX routing the panel through the dGPU
    # the kernel still picks nvidia_wmi_ec_backlight (EC over WMI), which
    # accepts writes that never reach the panel. nvidia-modeset only registers
    # its own nvidia_0 backlight (the one that drives a GPU-connected eDP
    # panel) when acpi_video_backlight_use_native() is true, which this forces.
    boot.kernelParams = [
      "nvidia-drm.modeset=1"
      "acpi_backlight=native"
    ];

    hardware.nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;

      # RTX 5070 is Blackwell → ONLY the open kernel modules support it.
      open = true;

      # Forza Horizon 6 gates at a 596+ NVIDIA driver and crashes on the splash
      # screen below it. production/stable are pinned at 595.80, so use `latest`
      # (610.x in this nixpkgs), comfortably past the 570+ Blackwell floor
      # and the FH6 596 floor.
      package = config.boot.kernelPackages.nvidiaPackages.latest;

      # The dGPU is the session's only GPU (the MUX routes the panel through
      # it, see systems/g815/default.nix), so suspend has to preserve its VRAM:
      # this enables nvidia-suspend/resume/hibernate.service plus
      # NVreg_PreserveVideoMemoryAllocations. RTD3 (finegrained) stays off:
      # the session holds the GPU for its whole lifetime, so it would never
      # engage, and the machine is plugged in anyway.
      powerManagement.enable = true;

      # nvidia-powerd. The GPU and the CPU share one chassis power budget;
      # dynamic boost hands the headroom to whichever one is loaded instead of
      # splitting it statically. Only useful because the machine is always on
      # AC. If the firmware doesn't support it, nvidia-powerd exits and the
      # rest of the stack is unaffected.
      dynamicBoost.enable = true;

      moduleParams.nvidia = {
        # PowerMizer at maximum performance. PerfLevelSrc=0x2222 makes the
        # driver honour the PowerMizerDefault* levels instead of its own
        # heuristic; 0x1 is "maximum performance". The machine lives on the
        # barrel charger, so the battery level is set to the same.
        NVreg_RegistryDwords = ''"PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerDefaultAC=0x1; PowerMizerDefault=0x1"'';

        # Where powerManagement.enable dumps VRAM across a suspend. The driver
        # default is /tmp, which is a 16G tmpfs here, so the card's 8G would be
        # written straight back into RAM. /var/tmp is on the disk.
        NVreg_TemporaryFilePath = "/var/tmp";
      };
    };
  };
}
