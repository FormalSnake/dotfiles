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
    systemctl --user start --no-block formalshell-rig-pointer.service
  '';

  # Headless labwc has no input devices, so its seat offers no pointer and
  # neither does the Hyprland nested in it: a client's wl_pointer existed
  # only while some virtual pointer did, and wlrctl's exits before the shell
  # binds the one its own device brought. Holding one virtual pointer on
  # labwc gives the nested session a pointer for the slot's whole life.
  holdPointer = pkgs.writers.writePython3 "formalshell-rig-pointer" { } ''
    import os
    import socket
    import struct


    def send(sock, obj, op, payload=b""):
        size = 8 + len(payload)
        sock.sendall(struct.pack("<II", obj, (size << 16) | op) + payload)


    def recv(sock, buf):
        while len(buf) < 8 or len(buf) < struct.unpack_from("<I", buf, 4)[0] >> 16:
            chunk = sock.recv(65536)
            if not chunk:
                raise SystemExit("labwc closed the connection")
            buf += chunk
        obj, word = struct.unpack_from("<II", buf)
        size = word >> 16
        return obj, word & 0xFFFF, buf[8:size], buf[size:]


    path = os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"])
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)
    send(sock, 1, 1, struct.pack("<I", 2))
    send(sock, 1, 0, struct.pack("<I", 3))
    buf, manager = b"", None
    while True:
        obj, op, body, buf = recv(sock, buf)
        if obj == 2 and op == 0:
            name, n = struct.unpack_from("<II", body)
            if body[8:8 + n - 1] == b"zwlr_virtual_pointer_manager_v1":
                manager = name
        elif obj == 3:
            break
    if manager is None:
        raise SystemExit("labwc offers no zwlr_virtual_pointer_manager_v1")
    iface = b"zwlr_virtual_pointer_manager_v1\0"
    iface += b"\0" * (-len(iface) % 4)
    bind = struct.pack("<II", manager, 32) + iface + struct.pack("<II", 1, 4)
    send(sock, 2, 0, bind)
    send(sock, 4, 0, struct.pack("<II", 0, 5))
    while sock.recv(65536):
        pass
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

  systemd.user.services.formalshell-rig-pointer = {
    description = "virtual pointer held on the FormalShell rig's headless labwc";
    unitConfig.ConditionGroup = "fstest";
    partOf = [ "formalshell-rig-parent.service" ];
    serviceConfig = {
      ExecStart = holdPointer;
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
