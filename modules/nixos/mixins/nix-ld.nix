{ pkgs, ... }:
{
  # Prebuilt FHS binaries from npm platform packages
  # (@nativedesktop/host-linux-x64 ships one, interpreter
  # /lib64/ld-linux-x86-64.so.2) cannot exec on NixOS without a loader shim.
  # nix-ld supplies the interpreter and resolves the sonames below through
  # NIX_LD_LIBRARY_PATH. The list is the host binary's documented runtime
  # contract (NativeDesktop docs/runtime-deps.md): libadwaita and its
  # dependency closure, nothing app-specific.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      gtk4
      libadwaita
      glib
      pango
      cairo
      gdk-pixbuf
      graphene
      harfbuzz
      webkitgtk_6_0
      # GTK4's GSK links libvulkan.so.1 unconditionally on the FHS builds.
      vulkan-loader
    ];
  };
}
