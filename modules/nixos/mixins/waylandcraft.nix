{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.waylandcraft;

  # The Prism instance folder name under ~/.local/share/PrismLauncher/instances.
  # Runtime state, not nix-managed: it holds the mods, config and worlds.
  instance = "waylandcraft";

  # waylandcraft shells out to xkbcli for the system keymap and autostarts
  # xwayland-satellite for X11 clients, both looked up on the game's PATH. Its
  # native library links libxkbcommon.
  prism = pkgs.prismlauncher.override {
    additionalPrograms = [ pkgs.libxkbcommon pkgs.xwayland-satellite ];
    additionalLibs = [ pkgs.libxkbcommon ];
  };

  # Minecraft has no DRM backend of its own, so cage hosts the one window.
  # -s keeps VT switching alive as the way out if the game wedges. Prism exits
  # with the game under --launch, cage exits with Prism, and SDDM comes back.
  start = pkgs.writeShellScript "waylandcraft-session" ''
    # waylandcraft README: required on NVIDIA, a no-op elsewhere.
    export __GL_THREADED_OPTIMIZATIONS=0
    exec ${pkgs.cage}/bin/cage -s -- ${prism}/bin/prismlauncher --launch ${instance}
  '';

  session = (pkgs.writeTextDir "share/wayland-sessions/waylandcraft.desktop" ''
    [Desktop Entry]
    Name=Waylandcraft
    Comment=Minecraft as the desktop, hosted by cage
    Exec=${start}
    Type=Application
  '').overrideAttrs (_: {
    passthru.providedSessions = [ "waylandcraft" ];
  });
in
{
  options.kyan.waylandcraft.enable =
    lib.mkEnableOption "Waylandcraft login session (Prism Launcher under cage)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ prism ];
    services.displayManager.sessionPackages = [ session ];
  };
}
