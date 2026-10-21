{ pkgs, ... }:
let
  # Boxxy Terminal (miifrommera/boxxy): GTK4/libadwaita terminal. Not in
  # nixpkgs (pkgs.boxxy is an unrelated sandboxing tool) and upstream only
  # ships nightly binaries and its own Flatpak remote. Pinned to a main
  # commit: tags stopped at 0.0.35 while the nightly kept moving. The
  # in-app updater would try to replace the store binary, so it is compiled
  # out. boxxy-terminal spawns boxxy-agent from its own directory, so both
  # binaries stay in bin/.
  boxxy = pkgs.rustPlatform.buildRustPackage {
    pname = "boxxy-terminal";
    version = "0.0.35-unstable-2026-10-20";

    src = pkgs.fetchFromGitHub {
      owner = "miifrommera";
      repo = "boxxy";
      rev = "17dfb73270bfa1ea7d0ff0bb59ed98cb7db90816";
      hash = "sha256-6Biqnqkbj8gZt0PVf9VbMJJJkOUIF7PfMPhWE6Uszyg=";
    };

    cargoHash = "sha256-HS5ICnCwbwxwijFjyPYtgHa8rdi0j0+3nNtQ0ygUcTo=";

    cargoBuildFlags = [ "-p" "boxxy-app" "-p" "boxxy-agent" "--features" "boxxy-app/disable-self-update" ];

    nativeBuildInputs = with pkgs; [ pkg-config glib wrapGAppsHook4 cmake perl ];
    buildInputs = with pkgs; [
      gtk4
      libadwaita
      gtksourceview5
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
    ];

    doCheck = false;

    postInstall = ''
      install -Dm644 resources/icons/dev.boxxy.BoxxyTerminal.png \
        $out/share/icons/hicolor/256x256/apps/dev.boxxy.BoxxyTerminal.png
      install -Dm644 flatpak/dev.boxxy.BoxxyTerminal.desktop -t $out/share/applications
    '';
  };
in
{
  home.packages = [ boxxy ];
}
