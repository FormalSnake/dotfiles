{ config, lib, ... }:
let
  cfg = config.kyan.roblox;

  # Vulkan layer extensions are branch-pinned to the runtime they layer onto,
  # so this has to track whatever org.freedesktop.Platform branch Sober's
  # flatpak pulls (`flatpak info org.vinegarhq.Sober` shows it). A stale branch
  # here installs an extension the sandbox never loads, and the overlay just
  # silently fails to appear.
  runtimeBranch = "25.08";
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

    services.flatpak.packages = [
      "org.vinegarhq.Sober"
      # FPS readout. Sober has no counter of its own, and the Android client
      # Sober runs has no equivalent of the desktop client's Shift+F5 stats.
      "org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/${runtimeBranch}"
    ];

    # MangoHud reads both of these from the environment; the Flatpak sandbox
    # drops anything not declared here.
    services.flatpak.overrides.settings."org.vinegarhq.Sober".Environment = {
      MANGOHUD = "1";
      # fps_only is MangoHud's single-line mode and, per its docs, is not meant
      # to be combined with other display params, so only placement is set
      # alongside it. Top right keeps it clear of Roblox's own menu button.
      # Shift_R+F12 toggles the overlay off in game.
      MANGOHUD_CONFIG = "fps_only,font_size=32,position=top-right";
    };
  };
}
