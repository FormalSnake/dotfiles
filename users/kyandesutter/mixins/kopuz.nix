{ inputs, pkgs, ... }:
let
  kopuz = inputs.kopuz.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # On darwin the upstream package installs the bundle as $out/bin/kopuz.app
  # (with $out/bin/kopuz symlinked at the Mach-O inside it), so mac-app-util,
  # which only looks at $out/Applications, never sees it and Kopuz stays
  # invisible to Spotlight, Launchpad and the Dock. A separate symlink-only
  # derivation puts the bundle where mac-app-util looks without touching
  # kopuz's own derivation hash, which would cost us the cachix hit and a full
  # Rust build.
  macApp = pkgs.runCommand "kopuz-app" { } ''
    mkdir -p $out/Applications
    ln -s ${kopuz}/bin/kopuz.app $out/Applications/Kopuz.app
  '';

  # Dioxus sets WEBKIT_DISABLE_DMABUF_RENDERER=1 on every Wayland session
  # (packages/desktop/src/app.rs). WebKitGTK 2.52 has no accelerated backing
  # store other than the DMA-BUF one, so that leaves the web process painting
  # on the CPU on one thread: no threaded compositor, no Skia GPU worker, no
  # async scrolling. XDG_SESSION_TYPE is the only half of dioxus's condition
  # reachable from out here, since it overwrites the env var itself.
  #
  # The real DMA-BUF path is not an option on the g815: the compositor rejects
  # the NVIDIA-allocated buffer and the app dies on "Gdk: Error 71 (Protocol
  # error)", the same failure as Modrinth in modules/nixos/mixins/minecraft.nix.
  # Pinning the renderer to shared memory keeps the compositor thread and GPU
  # painting, and only the final blit crosses the CPU.
  #
  # The upstream .desktop entry hardcodes kopuz's own store path, so it needs
  # repointing or the launcher would run around the wrapper.
  linuxApp = pkgs.symlinkJoin {
    name = "kopuz-shm-renderer";
    paths = [ kopuz ];
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    postBuild = ''
      rm $out/bin/kopuz $out/share/applications/moe.kopuz.kopuz.desktop
      makeBinaryWrapper ${kopuz}/bin/kopuz $out/bin/kopuz \
        --set XDG_SESSION_TYPE x11 \
        --set WEBKIT_DMABUF_RENDERER_FORCE_SHM 1
      substitute ${kopuz}/share/applications/moe.kopuz.kopuz.desktop \
        $out/share/applications/moe.kopuz.kopuz.desktop \
        --replace-fail "${kopuz}/bin/kopuz" "$out/bin/kopuz"
    '';
    inherit (kopuz) meta;
  };

in
{
  # Kopuz: music player (local library, Jellyfin/Subsonic/Spotify backends).
  # Built by the upstream flake and fetched from kopuz.cachix.org; the
  # substituter is configured per platform in modules/{nixos/mixins/nix.nix,
  # darwin/mixins/determinate.nix}.
  home.packages =
    if pkgs.stdenv.hostPlatform.isDarwin then [ kopuz macApp ] else [ linuxApp ];
}
