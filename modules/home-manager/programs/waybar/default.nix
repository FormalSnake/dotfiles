{
  config,
  pkgs,
  ...
}: {
  # Install required fonts for waybar icons
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    font-awesome # For waybar icons
    (nerdfonts.override {fonts = ["JetBrainsMono"];}) # Optional: better font
  ];

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;
        modules-left = ["sway/workspaces" "sway/mode"];
        modules-center = ["sway/window"];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "clock"
          "tray"
        ];
        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{name}";
        };
        "sway/window" = {
          max-length = 25;
        };
        tray = {
          icon-size = 21;
          spacing = 10;
        };
        clock = {
          format = "{:%H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        pulseaudio = {
          format = "{volume}% {icon}";
          format-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" ""];
          };
          scroll-step = 5;
        };
        network = {
          format-wifi = "  {essid}";
          format-ethernet = "";
          format-disconnected = "";
          tooltip-format = "{ifname} via {gwaddr} ";
          on-click = "nm-connection-editor";
        };
        cpu = {
          format = " {usage}%";
        };
        memory = {
          format = " {used:0.1f}G/{total:0.1f}G";
        };
      };
    };

    # Optional: Custom styling that works with Catppuccin colors
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: 'JetBrainsMono Nerd Font', 'Font Awesome 6 Free', monospace;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: @base;
        color: @text;
        transition-property: background-color;
        transition-duration: .5s;
      }

      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: @text;
      }

      #workspaces button:hover {
        background: @surface0;
      }

      #workspaces button.focused {
        background-color: @surface0;
        box-shadow: inset 0 -3px @accent-color;
      }

      #workspaces button.urgent {
        background-color: @red;
        color: @base;
      }

      #mode {
        background-color: @red;
        color: @base;
        border-bottom: 3px solid @text;
      }

      #clock,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #tray,
      #window {
        padding: 0 10px;
        color: @text;
        background-color: @surface0;
      }

      #window {
        margin: 0 4px;
        background-color: transparent;
      }

      #workspaces {
        margin: 0 4px;
      }

      #clock {
        background-color: @blue;
        color: @base;
      }

      #cpu {
        background-color: @green;
        color: @base;
      }

      #memory {
        background-color: @yellow;
        color: @base;
      }

      #network {
        background-color: @teal;
        color: @base;
      }

      #network.disconnected {
        background-color: @red;
      }

      #pulseaudio {
        background-color: @peach;
        color: @base;
      }

      #pulseaudio.muted {
        background-color: @surface0;
        color: @overlay0;
      }

      #tray {
        background-color: @surface0;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: @red;
      }
    '';
  };
}
