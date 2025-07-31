{
  config,
  pkgs,
  lib,
  ...
}: let
  # Catppuccin Mocha color scheme
  colors = {
    # Base colors
    base = "0xff1e1e2e";
    mantle = "0xff181825";
    crust = "0xff11111b";
    
    # Text colors
    text = "0xffcdd6f4";
    subtext1 = "0xffbac2de";
    subtext0 = "0xffa6adc8";
    
    # Surface colors
    surface0 = "0xff313244";
    surface1 = "0xff45475a";
    surface2 = "0xff585b70";
    
    # Accent colors
    blue = "0xff89b4fa";
    lavender = "0xffb4befe";
    sapphire = "0xff74c7ec";
    sky = "0xff89dceb";
    teal = "0xff94e2d5";
    green = "0xffa6e3a1";
    yellow = "0xfff9e2af";
    peach = "0xfffab387";
    maroon = "0xffeba0ac";
    red = "0xfff38ba8";
    mauve = "0xffcba6f7";
    pink = "0xfff5c2e7";
    flamingo = "0xfff2cdcd";
    rosewater = "0xfff5e0dc";
  };

  # Create space items for workspaces 1-9
  spaceScript = pkgs.writeShellScript "space.sh" ''
    #!/bin/bash
    
    if [ "$SELECTED" = "true" ]; then
      sketchybar --set $NAME background.drawing=on \
                        background.color=${colors.blue} \
                        label.color=${colors.base} \
                        icon.color=${colors.base}
    else
      sketchybar --set $NAME background.drawing=off \
                        label.color=${colors.subtext0} \
                        icon.color=${colors.subtext0}
    fi
  '';
  
  # Front app script to show current application
  frontAppScript = pkgs.writeShellScript "front_app.sh" ''
    #!/bin/bash
    
    INFO="$INFO"
    if [ -z "$INFO" ]; then
      INFO=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
    fi
    
    sketchybar --set front_app label="$INFO"
  '';
  
  # Battery script
  batteryScript = pkgs.writeShellScript "battery.sh" ''
    #!/bin/bash
    
    PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
    CHARGING=$(pmset -g batt | grep 'AC Power')
    
    if [ $PERCENTAGE = "" ]; then
      exit 0
    fi
    
    case ''${PERCENTAGE} in
      9[0-9]|100) ICON=""
      ;;
      [6-8][0-9]) ICON=""
      ;;
      [3-5][0-9]) ICON=""
      ;;
      [1-2][0-9]) ICON=""
      ;;
      *) ICON=""
    esac
    
    if [[ $CHARGING != "" ]]; then
      ICON=""
    fi
    
    sketchybar --set battery icon="$ICON" label="''${PERCENTAGE}%"
  '';

  # Clock script
  clockScript = pkgs.writeShellScript "clock.sh" ''
    #!/bin/bash
    
    sketchybar --set clock label="$(date '+%a %d %b %H:%M')"
  '';

  # Main configuration string
  sketchybarConfig = ''
    #!/bin/bash
    
    # This is a generated file, do not edit!
    
    ############## BAR ##############
    sketchybar --bar height=32 \
                    blur_radius=30 \
                    position=top \
                    sticky=off \
                    padding_left=10 \
                    padding_right=10 \
                    color=${colors.base} \
                    border_width=2 \
                    border_color=${colors.surface0} \
                    corner_radius=9
    
    ############## GLOBAL DEFAULTS ##############
    sketchybar --default icon.font="GeistMono Nerd Font:Bold:16.0" \
                        icon.color=${colors.text} \
                        label.font="GeistMono Nerd Font:Bold:14.0" \
                        label.color=${colors.text} \
                        background.color=${colors.surface0} \
                        background.corner_radius=6 \
                        background.height=24 \
                        padding_left=5 \
                        padding_right=5 \
                        label.padding_left=4 \
                        label.padding_right=10 \
                        icon.padding_left=10 \
                        icon.padding_right=4
    
    ############## SPACE INDICATORS ##############
    SPACE_SIDS=(1 2 3 4 5 6 7 8 9)
    for i in "''${!SPACE_SIDS[@]}"
    do
      sid=$(($i+1))
      space_name="space.$sid"
      sketchybar --add space $space_name left \
                 --set $space_name space=$sid \
                                   icon=$sid \
                                   label.drawing=off \
                                   script="${spaceScript}" \
                                   click_script="aerospace workspace $sid"
    done
    
    ############## LEFT SIDE ITEMS ##############
    sketchybar --add item space_separator left \
               --set space_separator icon="" \
                                     label.drawing=off \
                                     background.drawing=off \
                                     padding_left=10
    
    sketchybar --add item front_app left \
               --set front_app       script="${frontAppScript}" \
                                     icon.drawing=off \
                                     background.color=${colors.surface1} \
               --subscribe front_app front_app_switched
    
    ############## RIGHT SIDE ITEMS ##############
    sketchybar --add item clock right \
               --set clock           update_freq=10 \
                                     icon="" \
                                     script="${clockScript}" \
                                     background.color=${colors.surface1}
    
    sketchybar --add item battery right \
               --set battery         update_freq=120 \
                                     script="${batteryScript}" \
                                     background.color=${colors.surface1} \
               --subscribe battery   power_source_change system_woke
    
    ############## FINALIZING THE SETUP ##############
    sketchybar --update
  '';
in {
  programs.sketchybar = {
    enable = true;
    config = sketchybarConfig;
    
    # Enable the service to start automatically
    service.enable = true;
    
    # Extra packages needed for scripts
    extraPackages = with pkgs; [
      jq
      # Note: aerospace should already be available from the aerospace module
    ];
  };
}