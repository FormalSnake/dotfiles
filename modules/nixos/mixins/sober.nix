{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.sober;
in
{
  options.kyan.sober.enable =
    lib.mkEnableOption "Sober (Roblox client for Linux, installed via Flatpak)";

  # Sober is only distributed as a Flatpak (org.vinegarhq.Sober on Flathub) —
  # there is no nixpkgs package. nix-flatpak installs/updates it declaratively
  # on each rebuild. The nix-flatpak NixOS module is imported in ../default.nix.
  config = lib.mkIf cfg.enable {
    services.flatpak = {
      enable = true;

      # Sober tracks Roblox, which updates often — refresh installed Flatpaks on a
      # daily timer so it stays current without manual `flatpak update` / rebuilds.
      update.auto = {
        enable = true;
        onCalendar = "daily";
      };

      remotes = lib.mkOptionDefault [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      packages = [ "org.vinegarhq.Sober" ];

      overrides."org.vinegarhq.Sober" = {
        # Roblox-via-Sober renders on the iGPU by default like every other app
        # under PRIME offload. A Flatpak env override carries the same render-
        # offload vars the native launchers use (pkgs.nvidiaOffloadEnv, from
        # ../mixins/nvidia.nix) into the sandbox so it uses the RTX 5070.
        Environment = pkgs.nvidiaOffloadEnv;

        # Grant the sandbox access to input devices (/dev/input) — declarative
        # equivalent of `flatpak override --device=input org.vinegarhq.Sober`.
        Context.devices = [ "input" ];
      };
    };
  };
}
