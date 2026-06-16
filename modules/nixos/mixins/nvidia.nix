{ config, ... }:
{
  # Builds the NVIDIA kernel module against boot.kernelPackages (CachyOS).
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;

    # RTX 5070 is Blackwell → ONLY the open kernel modules support it.
    open = true;

    # nixpkgs-unstable's production driver is well past the 570+ Blackwell floor.
    package = config.boot.kernelPackages.nvidiaPackages.production;

    powerManagement = {
      enable = true;
      finegrained = true; # RTD3 — dGPU powers down when idle (laptop battery)
    };

    # PRIME offload: iGPU drives the desktop, dGPU spins up on demand (and when
    # the external monitor — wired to the dGPU — is connected). busIDs are set
    # per-host in systems/g815/default.nix.
    prime.offload = {
      enable = true;
      enableOffloadCmd = true; # provides the `nvidia-offload` wrapper
    };
  };

  # Force the dGPU's PowerMizer to prefer maximum performance on AC, and fall
  # back to adaptive on battery — mirroring the CPU power policy (max unless on
  # battery). The driver switches between the two itself based on the power
  # source, so no udev/session hook is needed, and it works headless/Wayland
  # (nvidia-settings would need an X server). PerfLevelSrc=0x2222 tells the
  # driver to honour the PowerMizerDefault* levels instead of its own heuristic;
  # AC=0x1 is "maximum performance", battery=0x3 is "adaptive". This governs
  # clocks only while the GPU is awake — RTD3 (finegrained, above) still powers
  # it down when idle, so it's "max when in use", not "always on".
  boot.extraModprobeConfig = ''
    options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerDefaultAC=0x1; PowerMizerDefault=0x3"
  '';

  environment.sessionVariables = {
    # NVIDIA + Wayland: hardware video decode through the dGPU.
    LIBVA_DRIVER_NAME = "nvidia";
    # Electron/Chromium apps run native Wayland.
    NIXOS_OZONE_WL = "1";
  };
}
