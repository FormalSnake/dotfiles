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
      bars = []; # Disable default swaybar
      keybindings = {
        "${mod}+Return" = "exec ${config.wayland.windowManager.sway.config.terminal}";
        "${mod}+q" = "kill";
        "${mod}+Shift+q" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'";
      };
    };
  };

  programs.rofi = {
    enable = true;
  };
}
