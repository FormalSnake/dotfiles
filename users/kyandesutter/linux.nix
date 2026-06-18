{ pkgs, ... }:
{
  # Linux/NixOS-only home mixins (Hyprland desktop). Wired on the g815 host via
  # self.homeModules.kyandesutter-linux.
  imports = [
    ./mixins/hyprland.nix
    ./mixins/alttab.nix
    ./mixins/caelestia.nix
    ./mixins/beeper.nix
    ./mixins/helium.nix
    ./mixins/spicetify.nix
    ./mixins/fetch.nix
  ];

  # PrismLauncher (Minecraft) lives here rather than the shared programs.nix:
  # prismlauncher-11 segfaults in nixpkgs' wrap-qt6-apps-hook on aarch64-darwin
  # (upstream bug, exit 139) and it's a g815-only concern anyway (dGPU wrap).
  programs.prismlauncher = {
    enable = true;
    # Bundle zulu17 (older MC) and zulu21 (MC 1.20.5+/1.21 require Java 21).
    # Prism auto-selects the right JDK per instance. We skip the default
    # jdk21/17/8 triple to avoid pulling the extra Java 8 JDK we don't need.
    package =
      let
        prism = pkgs.prismlauncher.override { jdks = [ pkgs.zulu17 pkgs.zulu21 ]; };
      in
      # On the PRIME laptop, wrap so Minecraft (OpenGL — it can't grab the dGPU
      # opportunistically the way Vulkan games can) renders on the RTX 5070.
      # gpuOffloadWrap comes from the nvidia mixin's overlay (g815); other Linux
      # hosts fall through to the plain package.
      if pkgs ? gpuOffloadWrap then pkgs.gpuOffloadWrap prism else prism;
  };
}
