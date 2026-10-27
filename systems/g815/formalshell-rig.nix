{ pkgs, lib, ... }:
# FormalShell's smoke rig runs here (dev/remote.sh in that repo) as two
# throwaway users, one per slot, so a run never shares a uid, runtime dir,
# session bus or systemd user manager with the live session: the rig's
# `pkill -x Hyprland` and scope cleanup cannot reach kyandesutter's.
# Each user's lingering manager runs a headless labwc on the Intel render
# node, which advertises dmabuf, so dev/smoke.sh nests its Hyprland there
# and nothing ever appears on a real output or reads a real input device.
let
  slots = [ "fstest0" "fstest1" ];

  # Hyprland 0.56's aquamarine binds xdg_wm_base at version 6, and sway
  # 1.12 offers 5, which ends the connection with a protocol error. labwc
  # offers 6.
  #
  # aquamarine 0.15.1 never flushes its first xdg_toplevel commit, so under
  # a parent that sends nothing unprompted (labwc) the configure never comes
  # and the nested session gets no monitor. Fixed upstream after 0.15.1
  # (hyprwm/aquamarine#415); drop the patch once nixpkgs carries it.
  # dev/remote.sh puts the slot user's own profile ahead of
  # /run/wrappers/bin, so this Hyprland is the one dev/smoke.sh finds.
  rigHyprland = pkgs.hyprland.override {
    aquamarine = pkgs.aquamarine.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          url = "https://github.com/hyprwm/aquamarine/commit/7bb8bdf4e8fedaf4dfae58512bc4c728671727df.patch";
          hash = "sha256-tiCVGZ2xDlDQ91U/HPGTpMBRngXNnRcjOUhUefwhaiw=";
        })
      ];
    });
  };

  exportDisplay = pkgs.writeShellScript "formalshell-rig-export-display" ''
    systemctl --user import-environment WAYLAND_DISPLAY
    systemctl --user set-environment WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
  '';

  rigTools = with pkgs; [
    rigHyprland git rsync just jq iproute2 imagemagick libnotify wl-clipboard wireplumber
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJi88WllIdjMaW5UJYbT7+NRYzSCrnKKYjGR7wL4n4io macbook"
    ];
    packages = rigTools;
  });

  # A global user unit, so the group condition keeps it out of every other
  # user's manager.
  systemd.user.services.formalshell-rig-parent = {
    description = "headless labwc the FormalShell smoke rig nests Hyprland in";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionGroup = "fstest";
    environment = {
      WLR_BACKENDS = "headless";
      WLR_RENDERER = "gles2";
      WLR_RENDER_DRM_DEVICE = "/dev/dri/by-path/pci-0000:00:02.0-render";
      WLR_LIBINPUT_NO_DEVICES = "1";
    };
    serviceConfig = {
      ExecStart = "${pkgs.labwc}/bin/labwc -s ${exportDisplay}";
      Restart = "on-failure";
    };
  };
}
