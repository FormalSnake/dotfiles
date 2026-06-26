{ config, lib, pkgs, ... }:
let
  cfg = config.kyan.sober;
in
{
  options.kyan.sober.enable =
    lib.mkEnableOption "Sober (Roblox client for Linux, installed via Flatpak)";

  # Sober is only distributed as a Flatpak (org.vinegarhq.Sober on Flathub) —
  # there is no nixpkgs package. It rides on the declarative Flatpak base in
  # ./flatpak.nix (enabled below), which nix-flatpak installs/updates on each
  # rebuild.
  config = lib.mkIf cfg.enable {
    kyan.flatpak.enable = true;

    services.flatpak = {
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
