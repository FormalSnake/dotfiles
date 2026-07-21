{ config, lib, ... }:
let
  cfg = config.kyan.nvidia;
in
{
  # Gated so an Intel-only host can import this bundle untouched: without the
  # gate the PRIME assertion below fails eval on any host that doesn't set the
  # bus IDs, and the NVIDIA kernel module would build for hardware that isn't
  # there. g815 flips this on in systems/g815/default.nix.
  options.kyan.nvidia.enable =
    lib.mkEnableOption "NVIDIA dGPU stack (driver, PRIME offload, offload overlay)";

  config = lib.mkIf cfg.enable {
    # PRIME offload needs the iGPU bus ID; it's set per-host (systems/g815).
    assertions = [
      {
        assertion = config.hardware.nvidia.prime.intelBusId != "";
        message = "nvidia.nix: PRIME offload requires hardware.nvidia.prime.intelBusId set in the host config";
      }
    ];

    # Builds the NVIDIA kernel module against boot.kernelPackages (CachyOS).
    services.xserver.videoDrivers = [ "nvidia" ];

    # Required for the NVIDIA open module + Wayland; also helps suspend.
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];

    hardware.nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;

      # RTX 5070 is Blackwell → ONLY the open kernel modules support it.
      open = true;

      # Forza Horizon 6 gates at a 596+ NVIDIA driver and crashes on the splash
      # screen below it. production/stable are pinned at 595.80, so use `latest`
      # (610.43.02 in this nixpkgs) — comfortably past the 570+ Blackwell floor
      # and the FH6 596 floor.
      package = config.boot.kernelPackages.nvidiaPackages.latest;

      powerManagement = {
        enable = true;
        # RTD3 plumbing. NOTE: RTD3/D3cold does NOT actually work on this Blackwell
        # RTX 5070 + open kernel module (open-gpu-kernel-modules #882) — the dGPU
        # never self-suspends and idles at D0. Kept enabled so the udev/modeset
        # hooks are in place if a driver update fixes it; the real battery win is
        # the hard power-off in power.nix (dgpu-reconcile).
        finegrained = true;
      };

      # Dynamic Boost (nvidia-powerd) shifts power budget between CPU and dGPU
      # under combined load — a gaming feature (it's what let the 5070 pass its
      # 50W base TGP toward 115W). Gaming lives on Windows now and the session
      # never renders on the dGPU, so keep it off; the power path
      # (modules/nixos/mixins/power.nix) no longer manages the service either.
      dynamicBoost.enable = false;

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

    # LIBVA_DRIVER_NAME is intentionally NOT set globally. It's chosen per session
    # by power source in users/kyandesutter/mixins/niri.nix (settings.environment):
    # nvidia on AC (dGPU decode), iHD on battery so the dGPU can stay asleep instead
    # of being woken by any app that decodes video. Offloaded apps still get nvidia
    # decode via nvidiaOffloadEnv below.

    # PRIME render-offload plumbing for offloaded launchers.
    #
    # In offload mode the iGPU drives the desktop and the dGPU stays idle until a
    # process opts in via these env vars — the same set `nvidia-offload` exports.
    # There is no driver-level "this app → use the dGPU" detection; selection
    # is per-process. But a child inherits its parent's environment, so carrying
    # these vars on a *launcher* makes every process it spawns land on the
    # RTX 5070 automatically, while the desktop and everything else stay on the
    # iGPU. Trade-off: a launcher (and its dGPU) is awake while open.
    #
    # Exposed as an overlay so both NixOS modules and home-manager (useGlobalPkgs)
    # can reach them through `pkgs`:
    #   • pkgs.nvidiaOffloadEnv — the attrset, for env-style consumers.
    #   • pkgs.gpuOffloadWrap   — wraps a package's executables to always render on
    #     the dGPU, for native launchers (Prism, via users/kyandesutter/linux.nix).
    nixpkgs.overlays = [
      (final: _prev: {
        nvidiaOffloadEnv = {
          __NV_PRIME_RENDER_OFFLOAD = "1";
          __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __VK_LAYER_NV_optimus = "NVIDIA_only";
          # An offloaded process drives the dGPU, so keep its VA-API decode there too.
          # The session default is now iHD on battery (niri.nix settings.environment),
          # so offloaded apps must set this explicitly to decode on the dGPU.
          LIBVA_DRIVER_NAME = "nvidia";
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
                  ${lib.concatStringsSep " \\\n                  " (
                    lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg v}") final.nvidiaOffloadEnv
                  )}
              done
            '';
          };
      })
    ];
  };
}
