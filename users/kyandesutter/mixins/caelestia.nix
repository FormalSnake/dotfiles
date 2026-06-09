{ inputs, ... }:
{
  # Official caelestia flake home-manager module. Installs the Quickshell-based
  # shell + CLI, and runs the shell as a user systemd service bound to the
  # Wayland systemd target (auto-starts once Hyprland/uwsm reaches that target).
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    cli.enable = true; # `caelestia` CLI: launcher IPC, screenshots, wallpaper, theming

    systemd.enable = true; # default; explicit for clarity

    # Free-form JSON written to ~/.config/caelestia/shell.json. Keys are passed
    # through (not statically validated) — see the shell's own config docs.
    settings = {
      bar.status.showBattery = true;
    };
  };
}
