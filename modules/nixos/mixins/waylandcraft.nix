{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.waylandcraft;

  # The Prism instance folder name under ~/.local/share/PrismLauncher/instances.
  # Runtime state, not nix-managed: it holds the mods, config and worlds.
  instance = "waylandcraft";

  # waylandcraft shells out to xkbcli for the system keymap and autostarts
  # xwayland-satellite for X11 clients, both looked up on the game's PATH. Its
  # native library links libxkbcommon.
  # Only Java 21 on the launcher's Java path: the wrapper's default set adds
  # jdk8, jdk17 and jdk25 to the closure for Minecraft versions not played here.
  prism = pkgs.prismlauncher.override {
    jdks = [ pkgs.zulu21 ];
    additionalPrograms = [ pkgs.libxkbcommon pkgs.xwayland-satellite ];
    additionalLibs = [ pkgs.libxkbcommon ];
  };

  # Minecraft has no DRM backend of its own, so cage hosts the one window.
  # -s keeps VT switching alive as the way out if the game wedges. Cage exits
  # with Prism, and SDDM comes back.
  start = pkgs.writeShellScript "waylandcraft-session" ''
    # waylandcraft README: required on NVIDIA, a no-op elsewhere.
    export __GL_THREADED_OPTIMIZATIONS=0

    # Cage spans every output as one canvas. Pin it to the configured
    # connector, but only while that is plugged in, or cage has no output.
    ${lib.optionalString (cfg.output != null) ''
      for status in /sys/class/drm/card*-${cfg.output}/status; do
        if [ "$(cat "$status")" = connected ]; then
          export WLR_DRM_CONNECTORS=${cfg.output}
        fi
      done
    ''}

    # Prism stays resident after --launch unless the instance says otherwise,
    # which would hold the session open. Force the per-instance override on.
    cfg="''${XDG_DATA_HOME:-$HOME/.local/share}/PrismLauncher/instances/${instance}/instance.cfg"
    if [ -f "$cfg" ]; then
      for kv in OverrideMiscellaneous=true QuitAfterGameStop=true CloseAfterLaunch=false; do
        key=''${kv%%=*}
        if ${pkgs.gnugrep}/bin/grep -q "^$key=" "$cfg"; then
          ${pkgs.gnused}/bin/sed -i "s/^$key=.*/$kv/" "$cfg"
        else
          ${pkgs.gnused}/bin/sed -i "/^\[General\]/a $kv" "$cfg"
        fi
      done
    fi
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
  options.kyan.waylandcraft = {
    enable = lib.mkEnableOption "Waylandcraft login session (Prism Launcher under cage)";
    output = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "HDMI-A-1";
      description = "DRM connector the session runs on while connected; null spans every output.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ prism ];
    services.displayManager.sessionPackages = [ session ];
  };
}
