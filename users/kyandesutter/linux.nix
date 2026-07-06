{ pkgs, ... }:
{
  # Linux/NixOS-only home mixins (Hyprland desktop). Wired on the g815 host via
  # self.homeModules.kyandesutter-linux.
  imports = [
    ./mixins/hyprland.nix
    ./mixins/qt.nix
    ./mixins/desktop-apps.nix
    ./mixins/autostart.nix
    ./mixins/airpods.nix
    ./mixins/easyeffects.nix
    ./mixins/alttab.nix
    ./mixins/noctalia.nix
    ./mixins/beeper.nix
    ./mixins/helium.nix
    ./mixins/spicetify.nix
    ./mixins/fetch.nix
    ./mixins/lumen.nix
    ./mixins/nordvpn.nix
    ./mixins/webapps.nix
  ];

  # Standalone desktop web apps (see mixins/webapps.nix). Bare URL → auto
  # name+favicon; attrs for overrides. Claude gets a hand-picked icon.
  kyan.webapps.sites = [
    {
      url = "https://claude.ai";
      name = "Claude";
      icon = ./mixins/webapps-icons/claude.png;
      # Reuse the Helium login — Claude enforces a hard device limit, so an
      # isolated profile would burn a device slot.
      shareProfile = true;
    }
    {
      # X/Twitter — reuse the Helium login; favicon auto-fetched at activation.
      url = "https://x.com";
      name = "Twitter";
      shareProfile = true;
    }
    {
      # YouTube — reuse the Helium login; favicon auto-fetched at activation.
      url = "https://youtube.com";
      name = "YouTube";
      shareProfile = true;
    }
    {
      # Jump Desktop — reuse the Helium login; favicon auto-fetched at
      # activation. Connection auth-creds fragment stripped from the URL.
      url = "https://app.jumpdesktop.com/jump";
      name = "Jump Desktop";
      shareProfile = true;
    }
    {
      # Immich (photos.kaiiserni.com) — replaces the Mimick Flatpak client.
      # Shares the Helium login so the web app opens already authenticated.
      url = "https://photos.kaiiserni.com";
      name = "Photos";
      shareProfile = true;
    }
  ];

  # NixOS rebuild shortcut (g815-only, so it lives here rather than the shared
  # fish.nix — `nixos-rebuild` doesn't exist on the darwin host). Merges into the
  # programs.fish.functions set defined in mixins/fish.nix.
  #
  # The flake is referenced by absolute path (~/.config/nix#g815), not `.#g815`,
  # so `rebuild` works from any directory. `#g815` is literal: fish only treats
  # `#` as a comment at the start of a word, and `~` still expands at word-start.
  # Extra flags (e.g. --show-trace, boot) pass through via $argv.
  programs.fish.functions.rebuild = {
    description = "Rebuild NixOS from the flake (~/.config/nix#g815), runnable from any directory";
    body = ''
      sudo nixos-rebuild switch --flake ~/.config/nix#g815 $argv
    '';
  };

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
