#!/usr/bin/env bash
# Pop window: float, pin, and bring to top (picture-in-picture style)

hyprctl dispatch togglefloating
hyprctl dispatch pin active
hyprctl dispatch alterzorder top
