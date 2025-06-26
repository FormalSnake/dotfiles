{
  config,
  pkgs,
  ...
}: {
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
