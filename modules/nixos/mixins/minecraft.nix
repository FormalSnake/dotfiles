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
    # On the PRIME laptop, wrap so Minecraft (OpenGL: it cannot grab the dGPU
    # opportunistically the way Vulkan games can) renders on the RTX 5070. The
    # game inherits the launcher's environment. gpuOffloadWrap comes from the
    # nvidia mixin's overlay; hosts without it get the plain package.
    environment.systemPackages = [
      (if pkgs ? gpuOffloadWrap then pkgs.gpuOffloadWrap pkgs.modrinth-app else pkgs.modrinth-app)
    ];
  };
}
