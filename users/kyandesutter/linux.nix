{ pkgs, ... }:
{
  # Linux/NixOS-only home mixins (Hyprland desktop). Wired on the g815 host via
  # self.homeModules.kyandesutter-linux.
  imports = [
    ./mixins/desktop/hyprland
    ./mixins/desktop/qt.nix
    ./mixins/desktop/desktop-apps.nix
    ./mixins/desktop/autostart.nix
    ./mixins/devices/macbook-mount.nix
    ./mixins/devices/airpods.nix
    ./mixins/devices/dualsense.nix
    ./mixins/devices/streamdeck.nix
    ./mixins/desktop/easyeffects.nix
    ./mixins/desktop/dms.nix
    ./mixins/desktop/dankcal.nix
    ./mixins/desktop/formalshell.nix
    ./mixins/desktop/elementary
    ./mixins/desktop/kde.nix
    ./mixins/apps/discord.nix
    ./mixins/apps/beeper.nix
    ./mixins/apps/flare.nix
    ./mixins/apps/helium.nix
    ./mixins/apps/dillo.nix
    ./mixins/apps/lumen.nix
    ./mixins/apps/nordvpn.nix
    ./mixins/dev/godot.nix
    ./mixins/apps/obsidian.nix
    ./mixins/apps/parsec.nix
    ./mixins/cli/terminal-browser.nix
    ./mixins/desktop/webapps.nix
  ];

  kyan.webapps.sites = [
    {
      url = "https://music.youtube.com";
      name = "YouTube Music";
      profile = "Default";
      icon = ./mixins/desktop/webapps-icons/youtube-music.png;
    }
  ];

  # NixOS rebuild shortcut (linux-only, so it lives here rather than the shared
  # fish.nix: `nixos-rebuild` doesn't exist on the darwin host). Merges into the
  # programs.fish.functions set defined in mixins/cli/fish.nix.
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
}
