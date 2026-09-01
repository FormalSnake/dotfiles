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
      # GTK4's GSK links libvulkan.so.1 unconditionally on the FHS builds.
      vulkan-loader
      # Without libGL.so.1 CEF's GPU process exits on every launch and
      # Chromium falls back to software rasterisation.
      libglvnd
      # libcef.so's runtime floor (the chromium engine is dlopened from the
      # CEF distribution; these are its own link-time needs).
      nss
      nspr
      atk
      at-spi2-atk
      at-spi2-core
      libdrm
      libgbm
      libxkbcommon
      expat
      alsa-lib
      cups
      dbus
      libx11
      libxcomposite
      libxdamage
      libxfixes
      libxrandr
      libxext
      libxcb
      # No webkitgtk here: the engine is dlopened, not linked, and its
      # gstreamer closure clashes with the one a dev shell brings along.
      # WebKit comes from the shell, CEF from its own distribution.
    ];
  };
}
