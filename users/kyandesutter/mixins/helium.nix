{ pkgs, ... }:
{
  # Helium browser. The overlay (inputs.helium.overlays.default) is applied at
  # the system level in modules/nixos/mixins/nix.nix, so pkgs.helium resolves.
  #
  # No GPU wrapper needed: LIBVA_DRIVER_NAME is chosen per session by power source
  # (users/kyandesutter/mixins/hyprland.nix uwsm/env-hyprland), so on battery Helium
  # decodes video on the iGPU and leaves the dGPU asleep; on AC it uses nvidia.
  home.packages = [ pkgs.helium ];

  home.sessionVariables.BROWSER = "helium";

  # TODO (verify on hardware): set helium as the xdg default browser once we know
  # its .desktop name (e.g. `helium.desktop` or `net.imput.helium.desktop`):
  #   xdg.mimeApps.defaultApplications = {
  #     "x-scheme-handler/http"  = "helium.desktop";
  #     "x-scheme-handler/https" = "helium.desktop";
  #     "text/html"              = "helium.desktop";
  #   };
}
