{ inputs, config, lib, ... }:
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

      # System font: Geist for UI text, GeistMono (Nerd Font) for monospace.
      # appearance.font.<style>.family overrides the shell's defaults
      # (GoogleSansFlex / CaskaydiaCove NF). icon stays Material Symbols, and
      # clock/workspaces keep their Rubik default (it carries the glyphs Geist
      # lacks).
      appearance.font = {
        headline.family = "Geist";
        title.family = "Geist";
        body.family = "Geist";
        label.family = "Geist";
        mono.family = "GeistMono Nerd Font";
      };
    };
  };

  # The active colour scheme is runtime state (~/.local/state/caelestia/scheme.json,
  # written by the `caelestia` CLI), not something the home-manager module exposes.
  # Pin it to the bundled catppuccin mocha on each activation so rebuilds — and
  # any wallpaper-driven dynamic theming — always settle back on mocha. The CLI
  # writes the file directly (no running shell needed); guarded so it's a no-op
  # when already on mocha and never fails the switch.
  home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cli=${config.programs.caelestia.cli.package}/bin/caelestia
    if [ "$("$cli" scheme get -n 2>/dev/null)" != "catppuccin" ] \
      || [ "$("$cli" scheme get -f 2>/dev/null)" != "mocha" ]; then
      run "$cli" scheme set -n catppuccin -f mocha -m dark || true
    fi
  '';
}
