sketchybar -m \
    --add item weather right \
    --set weather \
        update_freq=600 \
        script="$PLUGIN_DIR/weather.sh" \
        icon.font="Hack Nerd Font:Regular:13.0" \
        background.drawing=on
