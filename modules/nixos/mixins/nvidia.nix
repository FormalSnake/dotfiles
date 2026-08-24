{ config, lib, pkgs, ... }:
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

    # Required for the NVIDIA open module + Wayland.
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];

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
    };

    # VA-API on the dGPU for browsers and Electron (LIBVA_DRIVER_NAME=nvidia is
    # exported per session in users/kyandesutter/mixins/hyprland.nix).
    hardware.graphics.extraPackages = [ pkgs.nvidia-vaapi-driver ];

    # PowerMizer at maximum performance. PerfLevelSrc=0x2222 makes the driver
    # honour the PowerMizerDefault* levels instead of its own heuristic;
    # 0x1 is "maximum performance". The machine lives on the barrel charger,
    # so the battery level is set to the same.
    boot.extraModprobeConfig = ''
      options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerDefaultAC=0x1; PowerMizerDefault=0x1"
    '';
  };
}
