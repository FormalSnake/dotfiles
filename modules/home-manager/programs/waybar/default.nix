{
  config,
  pkgs,
  ...
}: {
  programs.waybar = {
    enable = true;
    style = ''
      * {
        font-family: "GeistMono Nerd Font";
        font-size: 14px;
      }

      window#waybar {
        background-color: rgba(43, 48, 59, 0.5);
        border-bottom: 3px solid rgba(100, 114, 125, 0.5);
        color: #ffffff;
        transition-property: background-color;
        transition-duration: .5s;
      }

      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #ffffff;
        border-bottom: 3px solid transparent;
      }

      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
        box-shadow: inherit;
        border-bottom: 3px solid #ffffff;
      }

      #workspaces button.focused {
        background-color: #64727D;
        border-bottom: 3px solid #ffffff;
      }

      #mode {
        background-color: #64727D;
        border-bottom: 3px solid #eb4d4b;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #temperature,
      #backlight,
      #network,
      #pulseaudio,
      #custom-media,
      #tray,
      #mode,
      #idle_inhibitor,
      #mpd {
        padding: 0 10px;
        color: #ffffff;
      }
    '';
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
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
          format-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" ""];
          };
          scroll-step = 5;
        };

        network = {
          format-wifi = "  {essid}";
          format-ethernet = "";
          format-disconnected = "";
          tooltip-format = "{ifname} via {gwaddr} ";
          on-click = "nm-connection-editor";
        };

        cpu = {
          format = " {usage}%";
        };

        memory = {
          format = " {used:0.1f}G/{total:0.1f}G";
        };
      };
    };
  };
}
