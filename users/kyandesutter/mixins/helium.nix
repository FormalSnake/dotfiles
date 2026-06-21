{ pkgs, ... }:
let
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
  helium = pkgs.helium.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      ln -s ${cdmDir} $out/opt/helium/WidevineCdm
    '';
  });
in
{
  # Helium browser. The overlay (inputs.helium.overlays.default) is applied at
  # the system level in modules/nixos/mixins/nix.nix, so pkgs.helium resolves.
  #
  # No GPU wrapper needed: LIBVA_DRIVER_NAME is chosen per session by power source
  # (users/kyandesutter/mixins/hyprland.nix uwsm/env-hyprland), so on battery Helium
  # decodes video on the iGPU and leaves the dGPU asleep; on AC it uses nvidia.
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
