# Epic's own Linux launcher (preview). It updates itself by replacing the
# AppImage file it was started from ($APPIMAGE), so, like Steam, it runs from a
# writable copy in $HOME. The pinned build only seeds that copy on first
# launch; after that the launcher keeps it current.
#
# Executed as a real AppImage, not through appimage-run: Tauri only treats
# itself as an AppImage (and so only self-updates) when it runs from the
# runtime's /tmp/.mount_* FUSE mount, which appimage-run's extraction skips.
# The runtime is static and the bundle carries its own libraries; nix-ld
# (../nix-ld.nix) supplies the loader. A Tauri app on WebKitGTK, so it hits the
# same NVIDIA DMA-BUF renderer crash as Modrinth (see ../minecraft.nix).
{ lib, fetchurl, appimageTools, writeShellApplication, symlinkJoin, coreutils }:
let
  version = "0.95.2+gfa9ad49";
  src = fetchurl {
    url = "https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/${lib.escapeURL version}/Linux/EpicGamesLauncher-x86_64.AppImage";
    hash = "sha256-cGYVnsmHr83CcGnwcLRWvbmoBb1fAhFKp62G5VWcv9U=";
  };
  extracted = appimageTools.extractType2 {
    pname = "epic-games-launcher";
    inherit version src;
  };
  launcher = writeShellApplication {
    name = "epic-games-launcher";
    runtimeInputs = [ coreutils ];
    text = ''
      dir="''${XDG_DATA_HOME:-$HOME/.local/share}/epic-games-launcher"
      img="$dir/EpicGamesLauncher-x86_64.AppImage"
      if [ ! -e "$img" ]; then
        mkdir -p "$dir"
        install -m 755 ${src} "$img"
      fi
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
      exec "$img" "$@"
    '';
  };
in
symlinkJoin {
  name = "epic-games-launcher-${version}";
  paths = [ launcher ];
  postBuild = ''
    install -Dm444 ${extracted}/usr/share/applications/epic-games-launcher.desktop \
      $out/share/applications/epic-games-launcher.desktop
    substituteInPlace $out/share/applications/epic-games-launcher.desktop \
      --replace-fail 'Exec=EpicGamesLauncher' "Exec=$out/bin/epic-games-launcher"
    cp -r ${extracted}/usr/share/icons $out/share/
  '';
  meta.mainProgram = "epic-games-launcher";
}
