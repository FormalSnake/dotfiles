{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.vinegar;
in
{
  options.kyan.vinegar.enable =
    lib.mkEnableOption "Vinegar (Roblox Studio bootstrapper for Linux)";

  # Vinegar (Roblox Studio launcher) ships as a native nixpkgs package, so install
  # it directly rather than via Flatpak (https://vinegarhq.org/Vinegar/Installation.html).
  # Wrapped with gpuOffloadWrap (from ../mixins/nvidia.nix) so Roblox Studio and
  # anything it spawns render on the RTX 5070 under PRIME offload, matching the
  # dGPU behaviour the Sober flatpak gets via its env override.
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ (pkgs.gpuOffloadWrap pkgs.vinegar) ];
  };
}
