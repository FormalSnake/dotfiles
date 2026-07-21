{ pkgs, lib }:

# Pin a Chromium/Electron app to the Intel iGPU for GPU rendering + VA-API video
# decode, and keep it off the nvidia dGPU.
#
# Why this is needed: when the g815 is docked, niri renders on the dGPU and
# advertises the nvidia render node to Wayland clients. Chromium's ANGLE/EGL
# then can't import niri's dmabuf on that node (eglCreateImage → EGL_BAD_MATCH
# 0x3009): the GPU process crash-loops and the app silently drops to software
# rendering (--use-gl=disabled). ANGLE-Vulkan is rejected by Chromium's Wayland
# Ozone and XWayland GL init fails too — both dead ends on this stack. Forcing
# the Intel render node makes mesa render the app (no dmabuf-import bug); niri
# imports that iGPU buffer for scanout on the dGPU. It also keeps the app off the
# dGPU entirely, so nothing wakes it on battery. The iGPU is fixed at PCI 00:02.0
# on this laptop (the dGPU is at 02:00.0, cf. niri.nix's render-device select).
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
