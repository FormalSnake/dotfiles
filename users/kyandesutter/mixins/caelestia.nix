{ inputs, config, lib, ... }:
let
  # Wallpaper tracked in-repo so it resolves to an immutable store path.
  wallpaper = ../wallpapers/storm.jpg;
in
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

      # Opaque panels (bar, popouts, dashboard). Transparency disabled — the
      # translucent look didn't read well against the wallpaper.
      appearance.transparency.enabled = false;

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

      # On-demand sleep. The session menu (SUPER+Space → power) has a fixed set
      # of four buttons baked into the shell QML — logout/shutdown/hibernate/
      # reboot — so a fifth "suspend" button isn't reachable from config. The
      # hibernate slot ran `systemctl hibernate`, which does nothing here (no
      # swap/resume device is configured), so repurpose it into a sleep button:
      # `systemctl suspend` with a crescent-moon icon. caelestia's LogindManager
      # locks the screen before sleep (general.idle.lockBeforeSleep, default on),
      # so resume lands on the lock screen. The matching keybind is in
      # hyprland.lua (SUPER+SHIFT+Escape).
      session = {
        commands.hibernate = [ "systemctl" "suspend" ];
        icons.hibernate = "bedtime";
      };
    };
  };

  # Wallpaper is runtime state too (~/.local/state/caelestia/wallpaper/path.txt,
  # written by the CLI). Point it at the in-repo store path on each activation.
  # `caelestia wallpaper -f` also regenerates a Material You scheme, so this MUST
  # run before caelestiaScheme below, which then re-pins catppuccin mocha over it.
  home.activation.caelestiaWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cli=${config.programs.caelestia.cli.package}/bin/caelestia
    want=${wallpaper}
    cur=$(cat "$HOME/.local/state/caelestia/wallpaper/path.txt" 2>/dev/null || true)
    if [ "$cur" != "$want" ]; then
      run "$cli" wallpaper -f "$want" || true
    fi
  '';

  # The active colour scheme is runtime state (~/.local/state/caelestia/scheme.json,
  # written by the `caelestia` CLI), not something the home-manager module exposes.
  # Pin it to the bundled catppuccin mocha on each activation so rebuilds — and
  # any wallpaper-driven dynamic theming — always settle back on mocha. The CLI
  # writes the file directly (no running shell needed); guarded so it's a no-op
  # when already on mocha and never fails the switch. Runs after caelestiaWallpaper
  # so it overrides the Material You scheme that setting a wallpaper generates.
  home.activation.caelestiaScheme = lib.hm.dag.entryAfter [ "writeBoundary" "caelestiaWallpaper" ] ''
    cli=${config.programs.caelestia.cli.package}/bin/caelestia
    if [ "$("$cli" scheme get -n 2>/dev/null)" != "catppuccin" ] \
      || [ "$("$cli" scheme get -f 2>/dev/null)" != "mocha" ]; then
      run "$cli" scheme set -n catppuccin -f mocha -m dark || true
    fi
  '';
}
