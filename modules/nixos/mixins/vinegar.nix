{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.vinegar;
in
{
  options.kyan.vinegar.enable =
    lib.mkEnableOption "Vinegar (Roblox Studio client for Linux, installed via Flatpak)";

  # Vinegar is only distributed as a Flatpak (org.vinegarhq.Vinegar on Flathub) —
  # there is no nixpkgs package. nix-flatpak installs/updates it declaratively
  # on each rebuild. The nix-flatpak NixOS module is imported in ../default.nix.
  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;

      remotes = lib.mkOptionDefault [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      packages = [ "org.vinegarhq.Vinegar" ];

      overrides."org.vinegarhq.Vinegar" = {
        # Roblox-via-Vinegar renders on the iGPU by default like every other app
        # under PRIME offload. A Flatpak env override carries the same render-
        # offload vars the native launchers use (pkgs.nvidiaOffloadEnv, from
        # ../mixins/nvidia.nix) into the sandbox so it uses the RTX 5070.
        Environment = pkgs.nvidiaOffloadEnv;

        # Grant the sandbox access to input devices (/dev/input) — declarative
        # equivalent of `flatpak override --device=input org.vinegarhq.Vinegar`.
        Context.devices = [ "input" ];
      };
    };
  };
}
