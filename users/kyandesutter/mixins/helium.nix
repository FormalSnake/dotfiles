{ pkgs, lib, ... }:
let
  igpuChromium = import ../../../lib/chromium-igpu.nix { inherit pkgs lib; };

  # Widevine DRM. Helium (ungoogled-chromium, chromium 149) is *compiled* with
  # Widevine support (the binary carries CdmAdapter / com.widevine.alpha) but the
  # upstream tarball ships no proprietary CDM, so DRM sites (Netflix, Spotify, …)
  # won't play. pkgs.widevine-cdm provides Chrome's CDM in the layout Chromium
  # expects: a dir with manifest.json + _platform_specific/linux_x64/libwidevinecdm.so.
  cdmDir = "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";

  # Chromium can locate the CDM two ways; Helium is built for the *second* one, so
  # the hint file below is what actually enables playback. We provide both anyway —
  # they point at the same CDM, so there is no version skew.
  #
  #  1. Bundled (DIR_BUNDLED_WIDEVINE_CDM) — a `WidevineCdm/` dir next to the
  #     binary. Honored only under the bundle_widevine_cdm build flag, which Helium
  #     does NOT set (the symlinked CDM is silently ignored). Kept as a no-cost
  #     fallback in case a future build flips the flag.
  #  2. Component hint (FILE_COMPONENT_WIDEVINE_CDM_HINT) — Helium is built with
  #     enable_widevine_cdm_component, so on first run it creates an empty
  #     ~/.config/net.imput.helium/WidevineCdm/ and, at CDM registration, reads a
  #     hint file there to find the CDM. Normally the component updater writes it,
  #     but Helium runs with --disable-component-update, so it stays empty. We
  #     write the hint ourselves (see home.file below).
  #
  # Symlinking the *directory* keeps the .so a real file in another store path, so
  # autoPatchelfHook (find -type f, no -L) and the LD_LIBRARY_PATH wrapper leave it
  # untouched — it is already patched upstream. Linux Widevine is L3 → up to 720p
  # on Netflix (the platform cap).
  heliumBase = pkgs.helium.overrideAttrs (old: {
    # Helium's "Use GTK" appearance option dlopens libgtk at runtime (the binary
    # carries the loader strings libgtk-4.so.1 then libgtk-3.so.0). The upstream
    # build ships no GTK, so the dlopen fails and the toggle silently falls back
    # to the Classic theme. runtimeDependencies (not buildInputs — GTK is
    # dlopen'd, not DT_NEEDED, so autoPatchelfHook won't add it otherwise) puts
    # libgtk-3.so.0 on the rpath. GTK3 not 4: Chromium defaults to the GTK3
    # backend (GTK4 is opt-in behind --gtk-version=4 and still incomplete).
    runtimeDependencies = (old.runtimeDependencies or [ ]) ++ [ pkgs.gtk3 ];
    postInstall = (old.postInstall or "") + ''
      ln -s ${cdmDir} $out/opt/helium/WidevineCdm
    '';
  });

  # GPU rendering + VA-API video decode on the iGPU (see lib/chromium-igpu.nix
  # for the nvidia-Wayland dmabuf reason this is necessary).
  helium = igpuChromium {
    package = heliumBase;
    exes = [ "helium" ];
  };
in
{
  # Helium browser. The overlay (inputs.helium.overlays.default) is applied at
  # the system level in modules/nixos/mixins/nix.nix, so pkgs.helium resolves.
  #
  home.packages = [ helium ];

  # Widevine component hint file (path #2 above). A JSON dict whose "Path" points
  # at the dir holding manifest.json + _platform_specific/…; Chromium reads it via
  # FILE_COMPONENT_WIDEVINE_CDM_HINT = <user-data-dir>/WidevineCdm/<this file>.
  # net.imput.helium is Helium's user-data dir (cf. its Crash Reports path).
  home.file.".config/net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm".text =
    builtins.toJSON { Path = cdmDir; };

  home.sessionVariables.BROWSER = "helium";

  # TODO (verify on hardware): set helium as the xdg default browser once we know
  # its .desktop name (e.g. `helium.desktop` or `net.imput.helium.desktop`):
  #   xdg.mimeApps.defaultApplications = {
  #     "x-scheme-handler/http"  = "helium.desktop";
  #     "x-scheme-handler/https" = "helium.desktop";
  #     "text/html"              = "helium.desktop";
  #   };
}
