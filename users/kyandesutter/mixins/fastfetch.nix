{ ... }:
let
  separator = "{#1}│";
  keyPrefix = "{#separator}│ ";

  rule = format: { type = "custom"; inherit format; };
  blank = rule separator;
  section = label: rule "${separator} {#}${label}";

  field = { type, icon, label, ... }@extra:
    builtins.removeAttrs (extra // {
      inherit type;
      key = "${keyPrefix} {#keys}${icon} ${label}";
    }) [ "icon" "label" ];
in
{
  programs.fastfetch.settings = {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

    logo.padding = { top = 2; left = 1; right = 2; };
    display.separator = "  ";

    modules = [
      { type = "title"; format = "{#1}╭───────────── {#}{user-name-colored}"; }

      (section "System Information")
      (field { type = "os";       icon = "󰍹"; label = "OS"; })
      (field { type = "kernel";   icon = "󰒋"; label = "Kernel"; })
      (field { type = "uptime";   icon = "󰅐"; label = "Uptime"; })
      (field { type = "packages"; icon = "󰏖"; label = "Packages"; format = "{all}"; })
      blank

      (section "Desktop Environment")
      (field { type = "de";           icon = "󰧨"; label = "DE"; })
      (field { type = "wm";           icon = "󱂬"; label = "WM"; })
      (field { type = "wmtheme";      icon = "󰉼"; label = "Theme"; })
      (field { type = "display";      icon = "󰹑"; label = "Resolution"; })
      (field { type = "shell";        icon = "󰞷"; label = "Shell"; })
      (field { type = "terminalfont"; icon = "󰛖"; label = "Font"; })
      blank

      (section "Hardware Information")
      (field { type = "cpu";    icon = "󰻠"; label = "CPU"; })
      (field { type = "gpu";    icon = "󰢮"; label = "GPU"; })
      (field { type = "memory"; icon = "󰍛"; label = "Memory"; })
      (field { type = "disk";   icon = "󰋊"; label = "Disk (/)"; folders = "/"; })
      blank

      { type = "colors"; key = separator; symbol = "circle"; }

      { type = "custom"; format = "{#1}╰───────────────────────────────╯"; }
    ];
  };
}
