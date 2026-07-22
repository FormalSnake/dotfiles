{ inputs, ... }:
{
  # Zen browser (Firefox fork) via the community flake's home-manager module.
  imports = [ inputs.zen-browser.homeModules.beta ];

  # GPU: deliberately NOT pinned to the iGPU (contrast helium.nix). Firefox
  # follows the compositor's dmabuf-feedback device, so Zen renders on whatever
  # GPU niri renders on — iGPU normally, dGPU when docked — and a relog re-picks
  # it (Zen restarts with the session, so the gpu-relog-prompt flow also releases
  # a dGPU fd held from before an undock). The Chromium dmabuf-import bug that
  # forced lib/chromium-igpu.nix is ANGLE-specific and doesn't apply here.
  # VA-API likewise auto-selects its driver from the active render node, so no
  # LIBVA_DRIVER_NAME.
  programs.zen-browser = {
    enable = true;

    profiles.default.settings = {
      # Hardware video decode — off by default in Firefox on Linux.
      "media.ffmpeg.vaapi.enabled" = true;
    };
  };
}
