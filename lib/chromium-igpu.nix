{ pkgs, lib }:

# Pin a Chromium/Electron app to the Intel iGPU for GPU rendering + VA-API video
# decode, and keep it off the nvidia dGPU.
#
# Why this is needed: a Chromium GPU process enumerates EGL/Vulkan vendors on
# its own rather than following the compositor, so left alone it opens the
# nvidia render node whenever the dGPU is powered — pinning the chip at D0 and
# parking VRAM on it for nothing. Worse, if it ends up rendering on a node the
# compositor didn't hand it, ANGLE/EGL can't import the peer's dmabuf
# (eglCreateImage → EGL_BAD_MATCH 0x3009): the GPU process crash-loops and the
# app silently drops to software rendering (--use-gl=disabled). ANGLE-Vulkan is
# rejected by Chromium's Wayland Ozone and XWayland GL init fails too — both
# dead ends on this stack. Forcing the Intel render node makes mesa render the
# app on the same device Hyprland composites on (the session is always
# iGPU-primary — see the AQ_DRM_DEVICES comment in hyprland.nix), which fixes
# both halves. The iGPU is fixed at PCI 00:02.0 on this laptop, the dGPU at
# 02:00.0.
#
# --render-node-override alone is enough to force the iGPU (mesa is auto-selected
# for an Intel node); the EGL/VA-API env below is belt-and-suspenders that also
# guarantees the nvidia EGL vendor is never loaded. For apps that can't be
# wrapped (a flatpak, a setuid launcher) just pass the flags at the launch
# command — the flags do the load-bearing work, the env is optional.
#
#   package     the Chromium/Electron derivation to wrap
#   exes        bin/ executables to wrap (e.g. [ "helium" ])
#   extraFlags  app-specific flags to append (e.g. Equibop's mic-AGC workaround)

{
  package,
  exes,
  extraFlags ? [ ],
}:
let
  flags = [
    "--use-gl=angle"
    "--use-angle=gl"
    "--render-node-override=/dev/dri/by-path/pci-0000:00:02.0-render"
    "--enable-features=VaapiVideoDecoder"
  ]
  ++ extraFlags;
in
pkgs.symlinkJoin {
  name = "${package.name}-igpu";
  paths = [ package ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = lib.concatMapStringsSep "\n" (exe: ''
    wrapProgram "$out/bin/${exe}" \
      --add-flags "${lib.concatStringsSep " " flags}" \
      --set-default __EGL_VENDOR_LIBRARY_FILENAMES /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json \
      --set-default LIBVA_DRIVER_NAME iHD
  '') exes;
  inherit (package) meta;
}
