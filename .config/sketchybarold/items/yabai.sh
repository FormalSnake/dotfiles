sketchybar -m --add       item               yabai_float left                                                    \
              --add       event              window_focus                                                        \
              --add       event              float_change                                                        \
              --set       yabai_float        script="$PLUGIN_DIR/yabai_float.sh"                \
                                             click_script="$PLUGIN_DIR/yabai_float_click.sh"    \
                                             lazy=off                                                            \
              --subscribe yabai_float        front_app_switched window_focus float_change                        \

