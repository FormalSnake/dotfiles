{ pkgs, ... }:
{
  # Hyprland is enabled at the system level (programs.hyprland in
  # modules/nixos/mixins/hyprland.nix); here we only manage the user config.
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # use the system Hyprland (NixOS programs.hyprland)
    portalPackage = null;
    systemd.enable = false; # uwsm owns the session/target

    settings = {
      # — Monitors —
      # Internal 18" WQXGA 240Hz panel. Adjust scale to taste (1.0–1.5).
      # External desk monitor (1440p): the connector name is unknown until
      # docked — the catch-all line places any external display at native res.
      monitor = [
        "eDP-1, 2560x1600@240, 0x0, 1.25"
        ", preferred, auto, 1.0"
      ];

      "$mod" = "SUPER"; # primary modifier (the physical Cmd-position key)
      "$terminal" = "ghostty";

      # caelestia shell auto-starts via its systemd user service. A polkit agent
      # is needed for GUI auth prompts.
      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "wl-paste --watch cliphist store"
      ];

      env = [
        "XCURSOR_SIZE,24"
        # NVIDIA + Wayland hints (explicit-sync is automatic on recent drivers).
        "__GL_GSYNC_ALLOWED,1"
      ];

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
        sensitivity = 0;
      };

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        layout = "dwindle";
        resize_on_border = true;
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 6;
          passes = 3;
        };
      };

      animations.enabled = true;

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      # — Keybinds (mirror the macOS/aerospace muscle memory, SUPER as mod) —
      bind = [
        # App launcher (caelestia registers this Hyprland global shortcut).
        "$mod, Space, global, caelestia:launcher"

        "$mod, Return, exec, $terminal"
        "$mod, Q, killactive,"
        "$mod SHIFT, F, fullscreen,"
        "$mod, V, togglefloating,"
        "$mod, B, exec, helium"

        # Vim-style focus (aerospace alt-hjkl → SUPER+hjkl).
        "$mod, h, movefocus, l"
        "$mod, j, movefocus, d"
        "$mod, k, movefocus, u"
        "$mod, l, movefocus, r"

        # Vim-style move (aerospace alt-shift-hjkl → SUPER+SHIFT+hjkl).
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, j, movewindow, d"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, l, movewindow, r"

        # Named workspaces (1=web 2=terminal 3=development 4=communication
        # 5=productivity 6=print 7=ai 8=media 9=gaming) — matches aerospace.
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"

        "$mod, Tab, workspace, previous"

        # Screenshots (grim/slurp; caelestia also ships its own if preferred).
        ", Print, exec, grim - | wl-copy"
        "$mod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy"
      ];

      # Volume / brightness (repeat while held).
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # — Window → workspace rules (ported from the aerospace setup; Linux app
      #   classes. Verify exact classes on hardware with `hyprctl clients`). —
      windowrulev2 = [
        # web
        "workspace 1 silent, class:^([Hh]elium)$"
        # terminal
        "workspace 2 silent, class:^(com.mitchellh.ghostty)$"
        # development
        "workspace 3 silent, class:^([Cc]ode|[Zz]ed|dev.zed.Zed)$"
        # communication
        "workspace 4 silent, class:^([Ss]lack|WhatsApp)$"
        # ai
        "workspace 7 silent, class:^([Cc]laude)$"
        # media
        "workspace 8 silent, class:^([Ss]potify)$"
        # gaming
        "workspace 9 silent, class:^([Ss]team|steam|vesktop|discord)$"
        # floating PiP
        "float, title:^(Picture-in-Picture)$"
      ];
    };
  };

  # Clipboard history for the SUPER-launcher / cliphist.
  home.packages = with pkgs; [
    cliphist
    hyprpolkitagent
  ];
}
