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
    environment.systemPackages = [ pkgs.modrinth-app ];
  };
}
