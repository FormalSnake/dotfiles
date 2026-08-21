{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.minecraft;
in
{
  options.kyan.minecraft.enable = lib.mkEnableOption "Modrinth App launcher";

  # The nixpkgs wrapper puts jdk8/17/21/25 on the launcher's PATH and sets
  # LD_LIBRARY_PATH for GLFW/LWJGL/OpenAL, so Modrinth's Java autodetect picks
  # up Nix JDKs. Without it the launcher downloads an Adoptium build whose FHS
  # interpreter cannot exec here, and every instance fails to start.
  config = lib.mkIf cfg.enable {
    # Minecraft is OpenGL, so it cannot claim the dGPU opportunistically the way
    # a Vulkan game can: it has to be told through the PRIME offload env. That
    # selection is per-process and there is no hook on the java Modrinth spawns,
    # so the env rides on the launcher and the game inherits it.
    #
    # WEBKIT_DISABLE_DMABUF_RENDERER comes along because the launcher is
    # WebKitGTK. With the offload env its web process renders on the dGPU while
    # Hyprland composites on the iGPU, and the dmabuf handoff across the two
    # dies as a Wayland protocol error before the window ever maps. Shared
    # memory instead costs a launcher nothing worth having.
    environment.systemPackages = [
      (
        if pkgs ? gpuOffloadWrap then
          pkgs.gpuOffloadWrap pkgs.modrinth-app { WEBKIT_DISABLE_DMABUF_RENDERER = "1"; }
        else
          pkgs.modrinth-app
      )
    ];
  };
}
