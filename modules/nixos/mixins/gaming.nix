{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.gaming;

  # Epic's own Linux launcher (preview). The download link on
  # launcher.epicgames.com redirects to this versioned build URL; bump both
  # when Epic ships a new one.
  eglVersion = "0.96.0+g2fade97";
  eglSrc = pkgs.fetchurl {
    url = "https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/${lib.escapeURL eglVersion}/Linux/EpicGamesLauncher-x86_64.AppImage";
    hash = "sha256-bFzEbu+MgLAXWcx2FUtpogZFsBt5UmRCqFUAkNtdJR4=";
  };
  eglExtracted = pkgs.appimageTools.extractType2 {
    pname = "epic-games-launcher";
    version = eglVersion;
    src = eglSrc;
  };
  # A Tauri app on WebKitGTK, so it hits the same NVIDIA DMA-BUF renderer
  # crash as Modrinth (see ./minecraft.nix).
  epic-games-launcher = pkgs.appimageTools.wrapType2 {
    pname = "epic-games-launcher";
    version = eglVersion;
    src = eglSrc;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    extraInstallCommands = ''
      wrapProgram $out/bin/epic-games-launcher \
        --set WEBKIT_DISABLE_DMABUF_RENDERER 1
      install -Dm444 ${eglExtracted}/usr/share/applications/epic-games-launcher.desktop \
        $out/share/applications/epic-games-launcher.desktop
      substituteInPlace $out/share/applications/epic-games-launcher.desktop \
        --replace-fail 'Exec=EpicGamesLauncher' "Exec=$out/bin/epic-games-launcher"
      cp -r ${eglExtracted}/usr/share/icons $out/share/
    '';
  };
in
{
  options.kyan.gaming.enable = lib.mkEnableOption "Steam, Heroic (Epic library) and the Proton tooling around them";

  # Fortnite is not covered here and cannot be on NixOS as Epic specified EAC
  # Linux v2 (2026-10-14): it requires a kernel and every module signed with a
  # well-known distro key (Ubuntu, Fedora, Debian, openSUSE, Universal Blue).
  # A NixOS kernel and the nixpkgs NVIDIA module are unsigned, and lanzaboote
  # only signs with self-enrolled keys. Fortnite stays on the Windows side.
  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      protontricks.enable = true;
      # GE-Proton shows up in Steam's per-game compatibility dropdown.
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    # Steam picks gamemode up per game with `gamemoderun %command%`.
    programs.gamemode.enable = true;
    programs.gamescope.enable = true;

    environment.systemPackages = [
      epic-games-launcher
      # Fallback Epic client (Legendary underneath) while the official one is
      # in preview.
      pkgs.heroic
      pkgs.mangohud
    ];
  };
}
