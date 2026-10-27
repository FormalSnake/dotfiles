{ pkgs, lib, ... }:
# FormalShell's smoke rig runs here (dev/remote.sh in that repo) as two
# throwaway users, one per slot, so a run never shares a uid, runtime dir,
# session bus or systemd user manager with the live session: the rig's
# `pkill -x Hyprland` and scope cleanup cannot reach kyandesutter's.
# Each user's lingering manager runs a headless sway on the Intel render
# node, which advertises dmabuf, so dev/smoke.sh nests its Hyprland there
# and nothing ever appears on a real output or reads a real input device.
let
  slots = [ "fstest0" "fstest1" ];

  swayConfig = pkgs.writeText "formalshell-rig-sway.conf" ''
    output HEADLESS-1 resolution 1920x1080
    default_border none
    default_floating_border none
    exec "systemctl --user import-environment WAYLAND_DISPLAY; systemctl --user set-environment WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
  '';

  rigTools = with pkgs; [
    git rsync just jq iproute2 imagemagick libnotify wl-clipboard wireplumber
    pulseaudio grim wtype foot wlsunset qrencode curl matugen cava
    ffmpeg-headless (mpv.override { scripts = [ mpvScripts.mpris ]; })
    (python3.withPackages (ps: [ ps.pygobject3 ]))
  ];
in
{
  users.groups.fstest = { };
  users.users = lib.genAttrs slots (name: {
    isNormalUser = true;
    group = "fstest";
    linger = true;
    # dev/smoke.d/lock.sh types this password through the formalshell-lock
    # PAM service. sshd takes keys only, so it opens nothing over the network.
    hashedPassword = "$y$j9T$1XwN0Yw8RLnm7uMn0EnlA.$n5Tr3VdWxFwtInsHUysZeSLhJxCkEvOF6NT5bAK2TR6";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcVJF2yg72gRq6NceAnchCIgIWfC2Xx2Va2vcq1GVOm personal_mac"
    ];
    packages = rigTools;
  });

  # A global user unit, so the group condition keeps it out of every other
  # user's manager.
  systemd.user.services.formalshell-rig-parent = {
    description = "headless sway the FormalShell smoke rig nests Hyprland in";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionGroup = "fstest";
    path = [ pkgs.bash ];
    environment = {
      WLR_BACKENDS = "headless";
      WLR_RENDERER = "gles2";
      WLR_RENDER_DRM_DEVICE = "/dev/dri/by-path/pci-0000:00:02.0-render";
      WLR_LIBINPUT_NO_DEVICES = "1";
    };
    serviceConfig = {
      ExecStart = "${pkgs.sway}/bin/sway --config ${swayConfig}";
      Restart = "on-failure";
    };
  };
}
