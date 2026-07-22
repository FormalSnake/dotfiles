{ pkgs, ... }:
{
  # Linux/NixOS-only home mixins (niri desktop). Wired on the g815 host via
  # self.homeModules.kyandesutter-linux.
  imports = [
    ./mixins/niri.nix
    ./mixins/qt.nix
    ./mixins/desktop-apps.nix
    ./mixins/autostart.nix
    ./mixins/macbook-mount.nix
    ./mixins/airpods.nix
    ./mixins/easyeffects.nix
    ./mixins/dms.nix
    ./mixins/dankcal.nix
    ./mixins/wallpaper-engine.nix
    ./mixins/beeper.nix
    ./mixins/helium.nix
    ./mixins/zen.nix
    ./mixins/spicetify.nix
    ./mixins/fetch.nix
    ./mixins/lumen.nix
    ./mixins/nordvpn.nix
    ./mixins/godot.nix
    ./mixins/obsidian.nix
    ./mixins/bambu-studio.nix
  ];

  # NixOS rebuild shortcut (linux-only, so it lives here rather than the shared
  # fish.nix — `nixos-rebuild` doesn't exist on the darwin host). Merges into the
  # programs.fish.functions set defined in mixins/fish.nix.
  #
  # The flake is referenced by absolute path (~/.config/nix#<host>), not `.#…`,
  # so `rebuild` works from any directory. The host attr comes from the live
  # hostname so this mixin serves every NixOS host, not just g815. `#` is
  # literal: fish only treats it as a comment at the start of a word, and `~`
  # still expands at word-start. Extra flags (e.g. --show-trace) pass through
  # via $argv.
  programs.fish.functions.rebuild = {
    description = "Rebuild NixOS from the flake (~/.config/nix#<hostname>), runnable from any directory";
    body = ''
      sudo nixos-rebuild switch --flake ~/.config/nix#"$(hostname)" $argv
    '';
  };

  # PrismLauncher (Minecraft) lives here rather than the shared programs.nix:
  # prismlauncher-11 segfaults in nixpkgs' wrap-qt6-apps-hook on aarch64-darwin
  # (upstream bug, exit 139) and it's a g815-only concern anyway (dGPU wrap).
  programs.prismlauncher = {
    enable = true;
    # Bundle zulu17 (older MC), zulu21 (MC 1.20.5+/1.21 require Java 21) and
    # zulu25 (current LTS, for the newest snapshots). Prism auto-selects the
    # right JDK per instance. We skip the default jdk21/17/8 triple to avoid
    # pulling the extra Java 8 JDK we don't need.
    package =
      let
        prism = pkgs.prismlauncher.override { jdks = [ pkgs.zulu17 pkgs.zulu21 pkgs.zulu25 ]; };
      in
      # On the PRIME laptop, wrap so Minecraft (OpenGL — it can't grab the dGPU
      # opportunistically the way Vulkan games can) renders on the RTX 5070.
      # gpuOffloadWrap comes from the nvidia mixin's overlay (g815); other Linux
      # hosts fall through to the plain package.
      if pkgs ? gpuOffloadWrap then pkgs.gpuOffloadWrap prism else prism;
  };
}
