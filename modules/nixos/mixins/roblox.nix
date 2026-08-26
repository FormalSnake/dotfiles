{ config, lib, ... }:
let
  cfg = config.kyan.roblox;
in
{
  options.kyan.roblox.enable = lib.mkEnableOption "Sober, the Roblox player";

  # Sober runs the x86_64 Android build of Roblox in its own runtime: no Wine,
  # no emulator, no VM. Roblox's Hyperion anti-cheat killed the Wine path in
  # 2024, which is why nixpkgs' vinegar now only covers Roblox Studio. Sober
  # ships as a Flatpak only, with no nixpkgs package, so it rides the base
  # Flatpak service in ./flatpak.nix — whose daily update timer is what keeps
  # it in step with Roblox's forced client updates.
  config = lib.mkIf cfg.enable {
    kyan.flatpak.enable = true;
    services.flatpak.packages = [ "org.vinegarhq.Sober" ];
  };
}
