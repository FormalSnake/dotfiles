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

  environment.sessionVariables = {
    # NVIDIA + Wayland: hardware video decode through the dGPU.
    LIBVA_DRIVER_NAME = "nvidia";
    # Electron/Chromium apps run native Wayland.
    NIXOS_OZONE_WL = "1";
  };
}
