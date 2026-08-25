{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.minecraft;

  # Modrinth is a Tauri app on WebKitGTK. With the session on the NVIDIA dGPU
  # alone, WebKit's DMA-BUF renderer allocates through libEGL_nvidia, the
  # compositor rejects the buffer (GDK "Error 71 (Protocol error)") and
  # WebKitWebProcess segfaults in libnvidia-eglcore on teardown, so the
  # launcher dies at startup. Wrapped at the package level so the .desktop
  # entry and a terminal launch both get it.
  modrinth = pkgs.symlinkJoin {
    name = "modrinth-app-no-dmabuf";
    paths = [ pkgs.modrinth-app ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/ModrinthApp" \
        --set WEBKIT_DISABLE_DMABUF_RENDERER 1
    '';
    inherit (pkgs.modrinth-app) meta;
  };
in
{
  options.kyan.minecraft.enable = lib.mkEnableOption "Modrinth App launcher";

  # The nixpkgs wrapper puts jdk8/17/21/25 on the launcher's PATH and sets
  # LD_LIBRARY_PATH for GLFW/LWJGL/OpenAL, so Modrinth's Java autodetect picks
  # up Nix JDKs. Without it the launcher downloads an Adoptium build whose FHS
  # interpreter cannot exec here, and every instance fails to start.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ modrinth ];
  };
}
