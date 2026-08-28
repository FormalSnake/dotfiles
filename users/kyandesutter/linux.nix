{ pkgs, ... }:
{
  # Linux/NixOS-only home mixins (Hyprland desktop). Wired on the g815 host via
  # self.homeModules.kyandesutter-linux.
  imports = [
    ./mixins/hyprland.nix
    ./mixins/qt.nix
    ./mixins/desktop-apps.nix
    ./mixins/autostart.nix
    ./mixins/macbook-mount.nix
    ./mixins/airpods.nix
    ./mixins/dualsense.nix
    ./mixins/easyeffects.nix
    ./mixins/dms.nix
    ./mixins/dankcal.nix
    ./mixins/formalshell.nix
    ./mixins/discord.nix
    ./mixins/beeper.nix
    ./mixins/helium.nix
    ./mixins/dillo.nix
    ./mixins/lumen.nix
    ./mixins/nordvpn.nix
    ./mixins/godot.nix
    ./mixins/obsidian.nix
    ./mixins/bambu-studio.nix
    ./mixins/parsec.nix
  ];

  # NixOS rebuild shortcut (linux-only, so it lives here rather than the shared
  # fish.nix: `nixos-rebuild` doesn't exist on the darwin host). Merges into the
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
}
