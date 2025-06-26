{
  config,
  pkgs,
  ...
}: let
  mod = "Mod4"; # Use the Super key as the modifier
in {
  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.sway-unwrapped;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      waybar
      wofi
      mako
      wl-clipboard
      grim
      slurp
      pavucontrol
      networkmanagerapplet
    ];
    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      export _JAVA_AWT_WM_NONREPARENTING=1
      export MOZ_ENABLE_WAYLAND=1
    '';
    config = {
      modifier = mod;
      terminal = "ghostty";
      menu = "wofi --show drun";
      bars = []; # Disable default swaybar, we will use waybar
      keybindings = {
        "${mod}+Return" = "exec ${config.wayland.windowManager.sway.config.terminal}";
        "${mod}+q" = "kill";
        "${mod}+d" = "exec ${config.wayland.windowManager.sway.config.menu}";
        "${mod}+Shift+q" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'";

        # Screenshots
        "Print" = "exec grim -g \"$(slurp)\" - | wl-copy";
        "Shift+Print" = "exec grim - | wl-copy";

        # Lock screen
        "${mod}+l" = "exec swaylock -f -c 000000";
      };
      startup = [
        {command = "waybar";}
        {command = "swayidle -w timeout 300 'swaylock -f -c 000000' timeout 600 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"' before-sleep 'swaylock -f -c 000000'";}
      ];
    };
  };

  programs.waybar = {
    enable = true;
    style = ''
      * {
          border: none;
          border-radius: 0;
          font-family: GeistMono Nerd Font;
          font-size: 13px;
          min-height: 0;
      }
      window#waybar {
          background: #1e1e2e;
          color: #cdd6f4;
      }
      #workspaces button {
          padding: 0 5px;
          background: transparent;
          color: #cdd6f4;
      }
      #workspaces button.active {
          background: #89b4fa;
          color: #1e1e2e;
      }
      #workspaces button.focused {
          background: #a6e3a1;
          color: #1e1e2e;
      }
      #workspaces button.urgent {
          background-color: #f38ba8;
      }
      #mode {
          background-color: #f38ba8;
          border-bottom: 3px solid #cdd6f4;
      }
      #clock, #battery, #cpu, #memory, #temperature, #backlight, #network, #pulseaudio, #tray {
          padding: 0 10px;
          margin: 0 5px;
          color: #cdd6f4;
      }
    '';
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = ["sway/workspaces" "sway/mode"];
      modules-center = ["sway/window"];
      modules-right = ["pulseaudio" "network" "cpu" "memory" "clock"];
      "sway/window" = {
        "max-length" = 25;
      };
      pulseaudio = {
        format = "{volume}% ";
        format-muted = "Muted ";
        "on-click" = "pavucontrol";
      };
      network = {
        format-wifi = "{essid} ({signalStrength}%) ";
        format-ethernet = "{ifname}: {ipaddr}/{cidr} ";
        format-disconnected = "Disconnected ⚠";
        "on-click" = "nm-connection-editor";
      };
      cpu = {
        format = "{usage}% ";
      };
      memory = {
        format = "{}% ";
      };
      clock = {
        "tooltip-format" = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        "format-alt" = "{:%Y-%m-%d}";
      };
    };
  };
}
