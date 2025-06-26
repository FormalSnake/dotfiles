{
  config,
  pkgs,
  ...
}: let
  mod = "Mod4"; # Use the Super key as the modifier
  alt = "Mod1"; # Use the Alt key as a secondary modifier
in {
  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.sway-unwrapped;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
    '';

    # Extra config for settings not in the module
    extraConfig = ''
      # Move mouse to newly focused window
      mouse_warping container

      include catppuccin-mocha

      # target                 title     bg    text   indicator  border
      client.focused           $lavender $base $text  $rosewater $lavender
      client.focused_inactive  $overlay0 $base $text  $rosewater $overlay0
      client.unfocused         $overlay0 $base $text  $rosewater $overlay0
      client.urgent            $peach    $base $peach $overlay0  $peach
      client.placeholder       $overlay0 $base $text  $overlay0  $overlay0
      client.background        $base

      # bar
      bar {
        colors {
          background         $base
          statusline         $text
          focused_statusline $text
          focused_separator  $base

          # target           border bg        text
          focused_workspace  $base  $mauve    $crust
          active_workspace   $base  $surface2 $text
          inactive_workspace $base  $base     $text
          urgent_workspace   $base  $red      $crust
        }
      }
    '';

    config = {
      modifier = mod;
      terminal = "ghostty";
      bars = [
        # {
        # command = "waybar";
        # }
      ];

      # Gaps inspired by Aerospace config
      gaps = {
        inner = 8;
        outer = 8;
      };

      window = {
        border = 2;
        titlebar = false;
      };

      # Focus follows keyboard, not mouse
      focus.followMouse = false;

      # Default layout
      defaultWorkspace = "layout splith";

      keybindings = {
        # Your existing bindings
        "${mod}+Return" = "exec ${config.wayland.windowManager.sway.config.terminal}";
        "${mod}+d" = "exec rofi -show drun";
        "${mod}+Shift+q" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'";

        # Window management (alt key)
        "${alt}+q" = "kill";
        "${alt}+Shift+f" = "fullscreen toggle";
        "${alt}+t" = "layout toggle split";

        # Focus movement (alt key)
        "${alt}+h" = "focus left";
        "${alt}+j" = "focus down";
        "${alt}+k" = "focus up";
        "${alt}+l" = "focus right";

        # Window movement (alt key)
        "${alt}+Shift+h" = "move left";
        "${alt}+Shift+j" = "move down";
        "${alt}+Shift+k" = "move up";
        "${alt}+Shift+l" = "move right";

        # Resize windows (alt key)
        "${alt}+Shift+minus" = "resize shrink width 10px";
        "${alt}+Shift+equal" = "resize grow width 10px";

        # Workspace management (mod key)
        "${mod}+1" = "workspace number 1";
        "${mod}+2" = "workspace number 2";
        "${mod}+3" = "workspace number 3";
        "${mod}+4" = "workspace number 4";
        "${mod}+5" = "workspace number 5";
        "${mod}+6" = "workspace number 6";
        "${mod}+7" = "workspace number 7";
        "${mod}+8" = "workspace number 8";
        "${mod}+9" = "workspace number 9";

        # Move windows to workspaces (mod key)
        "${mod}+Shift+1" = "move container to workspace number 1";
        "${mod}+Shift+2" = "move container to workspace number 2";
        "${mod}+Shift+3" = "move container to workspace number 3";
        "${mod}+Shift+4" = "move container to workspace number 4";
        "${mod}+Shift+5" = "move container to workspace number 5";
        "${mod}+Shift+6" = "move container to workspace number 6";
        "${mod}+Shift+7" = "move container to workspace number 7";
        "${mod}+Shift+8" = "move container to workspace number 8";
        "${mod}+Shift+9" = "move container to workspace number 9";

        # Workspace navigation (alt key)
        "${alt}+Tab" = "workspace back_and_forth";
        "${alt}+Shift+Tab" = "move workspace to output next";

        # Enter service mode (alt key)
        "${alt}+Shift+s" = "mode service";
      };

      # Service mode
      modes.service = {
        "Escape" = "reload, mode default";
        "r" = "layout default, mode default";
        "f" = "floating toggle, mode default";
      };
    };
  };

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    terminal = "${pkgs.ghostty}/bin/ghostty";

    extraConfig = {
      modi = "drun";
      show-icons = true;
      drun-display-format = "{icon} {name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "   Apps ";
      sidebar-mode = true;
    };
  };

  home.packages = [pkgs.bemoji];
}
