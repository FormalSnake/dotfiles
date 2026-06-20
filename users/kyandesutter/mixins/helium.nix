{ pkgs, ... }:
let
  # Helium browser. The overlay (inputs.helium.overlays.default) is applied at
  # the system level in modules/nixos/mixins/nix.nix, so pkgs.helium resolves.
  #
  # Helium (Chromium) does VA-API hardware video decode, and the global
  # LIBVA_DRIVER_NAME=nvidia (modules/nixos/mixins/nvidia.nix) routes that decode to
  # the dGPU — which keeps the RTX 5070 awake (holding /dev/nvidia0 open) for the
  # whole life of the browser, even undocked on battery. Pin Helium's VA-API to the
  # Intel iGPU (iHD) so it never touches the dGPU. Wrapper-set (not session env) so
  # it applies on the next Helium launch without a full relogin; helium.desktop uses
  # `Exec=helium`, resolved via PATH, so the launcher hits this wrapper too.
  helium = pkgs.symlinkJoin {
    name = "helium-igpu";
    paths = [ pkgs.helium ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in "$out"/bin/*; do
        [ -e "$bin" ] || continue
        target=$(readlink -f "$bin")
        rm "$bin"
        makeWrapper "$target" "$bin" --set LIBVA_DRIVER_NAME iHD
      done
    '';
  };
in
{
  home.packages = [ helium ];

  home.sessionVariables.BROWSER = "helium";

  # TODO (verify on hardware): set helium as the xdg default browser once we know
  # its .desktop name (e.g. `helium.desktop` or `net.imput.helium.desktop`):
  #   xdg.mimeApps.defaultApplications = {
  #     "x-scheme-handler/http"  = "helium.desktop";
  #     "x-scheme-handler/https" = "helium.desktop";
  #     "text/html"              = "helium.desktop";
  #   };
}
