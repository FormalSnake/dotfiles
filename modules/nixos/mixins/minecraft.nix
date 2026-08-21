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
    # Do not wrap this in gpuOffloadWrap the way Prism was. The launcher is
    # WebKitGTK, and __GLX_VENDOR_LIBRARY_NAME=nvidia kills its web process the
    # moment it starts ("WebKit encountered an internal error"). The game has to
    # be offloaded from the profile's own environment variables in Modrinth's
    # settings instead.
    environment.systemPackages = [ pkgs.modrinth-app ];
  };
}
