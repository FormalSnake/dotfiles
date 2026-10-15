{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.kyan.gaming;

  # Epic's own Linux launcher (preview). It updates itself by replacing the
  # AppImage file it was started from ($APPIMAGE), so, like Steam, it runs
  # from a writable copy in $HOME. The pinned build only seeds that copy on
  # first launch; after that the launcher keeps it current.
  eglVersion = "0.95.2+gfa9ad49";
  eglSrc = pkgs.fetchurl {
    url = "https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/${lib.escapeURL eglVersion}/Linux/EpicGamesLauncher-x86_64.AppImage";
    hash = "sha256-cGYVnsmHr83CcGnwcLRWvbmoBb1fAhFKp62G5VWcv9U=";
  };
  eglExtracted = pkgs.appimageTools.extractType2 {
    pname = "epic-games-launcher";
    version = eglVersion;
    src = eglSrc;
  };
  # Executed as a real AppImage, not through appimage-run: Tauri only treats
  # itself as an AppImage (and so only self-updates) when it runs from the
  # runtime's /tmp/.mount_* FUSE mount, which appimage-run's extraction skips.
  # The runtime is static and the bundle carries its own libraries; nix-ld
  # (./nix-ld.nix) supplies the loader. A Tauri app on WebKitGTK, so it hits
  # the same NVIDIA DMA-BUF renderer crash as Modrinth (see ./minecraft.nix).
  eglLauncher = pkgs.writeShellApplication {
    name = "epic-games-launcher";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      dir="''${XDG_DATA_HOME:-$HOME/.local/share}/epic-games-launcher"
      img="$dir/EpicGamesLauncher-x86_64.AppImage"
      if [ ! -e "$img" ]; then
        mkdir -p "$dir"
        install -m 755 ${eglSrc} "$img"
      fi
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
      exec "$img" "$@"
    '';
  };
  epic-games-launcher = pkgs.symlinkJoin {
    name = "epic-games-launcher";
    paths = [ eglLauncher ];
    postBuild = ''
      install -Dm444 ${eglExtracted}/usr/share/applications/epic-games-launcher.desktop \
        $out/share/applications/epic-games-launcher.desktop
      substituteInPlace $out/share/applications/epic-games-launcher.desktop \
        --replace-fail 'Exec=EpicGamesLauncher' "Exec=$out/bin/epic-games-launcher"
      cp -r ${eglExtracted}/usr/share/icons $out/share/
    '';
  };
in
{
  # Imported on every NixOS host (options must exist for the mkIf below); its
  # overlay only swaps steam, gamescope and mangohud, which nothing else uses.
  imports = [ inputs.jovian.nixosModules.default ];

  options.kyan.gaming.enable = lib.mkEnableOption "Steam Gaming Mode, Heroic (Epic library) and the Proton tooling around them";

  # Fortnite is not covered here and cannot be on NixOS as Epic specified EAC
  # Linux v2 (2026-10-14): it requires a kernel and every module signed with a
  # well-known distro key (Ubuntu, Fedora, Debian, openSUSE, Universal Blue).
  # A NixOS kernel and the nixpkgs NVIDIA module are unsigned, and lanzaboote
  # only signs with self-enrolled keys. Fortnite stays on the Windows side.
  config = lib.mkIf cfg.enable {
    # SteamOS-style boot: SDDM autologins into Gaming Mode (gamescope prefers
    # any external output over eDP-1, so the desk monitor when plugged in).
    # Steam's Switch to Desktop drops into the UWSM Hyprland session, and
    # logging out of that returns to Gaming Mode. The qylock greeter only
    # shows again when autologin is turned off here.
    jovian.steam = {
      enable = true;
      autoStart = true;
      user = "kyandesutter";
      desktopSession = "hyprland-uwsm";
    };
    # Jovian defaults to scx_lavd, which is broken on this CPU (./scx.nix).
    services.scx.scheduler = lib.mkForce "scx_bpfland";

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

    environment.systemPackages = [
      epic-games-launcher
      # Fallback Epic client (Legendary underneath) while the official one is
      # in preview.
      pkgs.heroic
      pkgs.mangohud
    ];
  };
}
