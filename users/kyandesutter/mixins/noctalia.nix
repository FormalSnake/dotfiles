{ inputs, ... }:
let
  # Wallpaper tracked in-repo so it resolves to an immutable store path.
  wallpaper = ../wallpapers/storm.jpg;
in
{
  # Official noctalia flake home-manager module. noctalia V5 is a native C++ /
  # OpenGL ES Wayland shell (the V4 line was Quickshell). The module installs the
  # `noctalia` shell + runs it as a user systemd service bound to the Wayland
  # systemd target (auto-starts once Hyprland/uwsm reaches that target).
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true; # user service, PartOf the Wayland/graphical-session target

    # Declarative config written to ~/.config/noctalia/config.toml (the module
    # converts this attrset to TOML and runs `noctalia config validate` on it at
    # build time, so unknown/invalid keys fail the build — keys below all come
    # from the upstream example.toml). noctalia may still mutate this file at
    # runtime via its Settings menu; the service is restart-triggered on changes.
    settings = {
      shell = {
        # UI text font (Pango family). Mirrors caelestia's Geist UI font. noctalia
        # draws its own glyphs/icons from a bundled icon font, so no separate Nerd
        # Font is needed here. There is no distinct monospace key in the schema.
        font_family = "Geist";

        # Opaque panels — mirrors caelestia's appearance.transparency.enabled =
        # false. "solid" is also noctalia's default; set explicitly for clarity.
        panel.transparency_mode = "solid";
      };

      # Catppuccin (dark) builtin theme — the static equivalent of caelestia's
      # `scheme set -n catppuccin -f mocha -m dark`, now fully declarative (no
      # activation script / CLI state to pin).
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";

        # App theming: render the active palette into GTK 3/4 config and drive the
        # system dark signal. The gtk3/gtk4 templates write
        # ~/.config/gtk-{3,4}.0/noctalia.css (imported via gtk.css) and their
        # apply.sh post-hook sets `org.gnome.desktop.interface color-scheme =
        # prefer-dark` + `gtk-theme = adw-gtk3-dark` via gsettings/dconf at
        # runtime. This is what makes native-Wayland/GTK and X11 apps follow dark
        # mode (the role caelestia's portal signal used to fill). adw-gtk3 is
        # installed by the gtk module in ../mixins/hyprland.nix, which sets the
        # same adw-gtk3-dark / prefer-dark values declaratively — they agree.
        templates = {
          enable_builtin_templates = true;
          builtin_ids = [ "gtk3" "gtk4" ];
        };
      };

      # Wallpaper is declarative now (caelestia tracked it as CLI runtime state).
      # crop = fill the screen, matching caelestia's behaviour.
      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        default.path = "${wallpaper}";
      };

      # Auto screen-off on idle (DPMS), preserving caelestia's idle screen
      # blanking. The Wayland idle-inhibit locks held during games/downloads (see
      # modules/nixos/mixins/{gaming,asus}.nix) suppress this. Lock-before-sleep
      # is handled explicitly by the SUPER+SHIFT+Escape `session lock-and-suspend`
      # keybind in ../mixins/hyprland.nix, so no idle auto-lock is enabled here.
      idle.behavior."screen-off" = {
        timeout = 660;
        command = "noctalia:dpms-off";
        resume_command = "noctalia:dpms-on";
        enabled = true;
      };
    };
  };
}
