{ inputs, pkgs, ... }:
let
  kopuz = inputs.kopuz.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # On darwin the upstream package installs the bundle as $out/bin/kopuz.app
  # (with $out/bin/kopuz symlinked at the Mach-O inside it), so mac-app-util —
  # which only looks at $out/Applications — never sees it and Kopuz stays
  # invisible to Spotlight, Launchpad and the Dock. A separate symlink-only
  # derivation puts the bundle where mac-app-util looks without touching
  # kopuz's own derivation hash, which would cost us the cachix hit and a full
  # Rust build.
  macApp = pkgs.runCommand "kopuz-app" { } ''
    mkdir -p $out/Applications
    ln -s ${kopuz}/bin/kopuz.app $out/Applications/Kopuz.app
  '';

  # Kopuz is Dioxus, so WebKitGTK draws the window and WebKitWebProcess owns
  # every frame. libglvnd picks its EGL vendor by filename order, and on the
  # g815 10_nvidia.json sorts ahead of 50_mesa.json: the web process came up on
  # the nvidia vendor and rendered into /dev/dri/renderD129 (dGPU) while
  # Hyprland scans out on the iGPU, so each frame crossed PCIe as an imported
  # dmabuf. That is why the much weaker e1504g felt smoother. Pinning the mesa
  # vendor moves the web process onto renderD128 next to the compositor
  # (verified 2026-08-19: renderD129 + libEGL_nvidia before, renderD128 +
  # libEGL_mesa on hardware gallium after). WEBKIT_WEB_RENDER_DEVICE_FILE does
  # not help — the vendor, not the device file, decides which GPU it lands on.
  #
  # Per-app rather than session-wide: nvidiaOffloadEnv
  # (modules/nixos/mixins/nvidia.nix) still needs the nvidia vendor reachable
  # for the launchers that genuinely want the dGPU. No-op on the e1504g, which
  # ships mesa as its only vendor.
  igpuKopuz = pkgs.symlinkJoin {
    name = "kopuz-igpu";
    paths = [ kopuz ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      target=$(readlink -f "$out/bin/kopuz")
      rm "$out/bin/kopuz"
      makeWrapper "$target" "$out/bin/kopuz" \
        --set __EGL_VENDOR_LIBRARY_FILENAMES \
          /run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
    '';
  };
in
{
  # Kopuz — music player (local library, Jellyfin/Subsonic/Spotify backends).
  # Built by the upstream flake and fetched from kopuz.cachix.org; the
  # substituter is configured per platform in modules/{nixos/mixins/nix.nix,
  # darwin/mixins/determinate.nix}.
  home.packages =
    if pkgs.stdenv.isDarwin then [ kopuz macApp ] else [ igpuKopuz ];
}
