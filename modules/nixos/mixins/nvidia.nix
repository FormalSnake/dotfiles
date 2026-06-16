{ config, lib, ... }:
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

  # PRIME render-offload plumbing for the gaming stack.
  #
  # In offload mode the iGPU drives the desktop and the dGPU is parked (RTD3)
  # until a process opts in via these env vars — the same set `nvidia-offload`
  # exports. There is no driver-level "this is a game → use the dGPU" detection;
  # selection is per-process. But a child inherits its parent's environment, so
  # carrying these vars on each game *launcher* (Steam, Prism, Lutris, Heroic,
  # Sober) makes every game they spawn land on the RTX 5070 automatically, while
  # the desktop and everything else stay on the iGPU and the dGPU still sleeps
  # when idle. Trade-off: a launcher (and its dGPU) is awake while open.
  #
  # Exposed as an overlay so both NixOS modules and home-manager (useGlobalPkgs)
  # can reach them through `pkgs`:
  #   • pkgs.nvidiaOffloadEnv — the attrset, for env-style consumers
  #     (Steam's extraEnv / gamescopeSession.env, the Sober flatpak override).
  #   • pkgs.gpuOffloadWrap   — wraps a package's executables to always render on
  #     the dGPU, for native launchers (Lutris, Heroic, Prism).
  nixpkgs.overlays = [
    (final: _prev: {
      nvidiaOffloadEnv = {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };

      gpuOffloadWrap =
        pkg:
        final.symlinkJoin {
          name = "${pkg.pname or pkg.name}-offload";
          paths = [ pkg ];
          nativeBuildInputs = [ final.makeWrapper ];
          # Re-wrap each executable so the offload env is prepended (Qt/GApp
          # wrappers underneath are preserved — makeWrapper just execs them).
          postBuild = ''
            for bin in "$out"/bin/*; do
              [ -e "$bin" ] || continue
              target=$(readlink -f "$bin")
              rm "$bin"
              makeWrapper "$target" "$bin" \
                ${lib.concatStringsSep " \\\n                " (
                  lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") final.nvidiaOffloadEnv
                )}
            done
          '';
        };
    })
  ];
}
