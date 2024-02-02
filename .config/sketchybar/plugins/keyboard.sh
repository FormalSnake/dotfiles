#!/bin/bash

# this is jank and ugly, I know
LAYOUT="$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | grep "KeyboardLayout Name" | cut -c 33- | rev | cut -c 2- | rev)"

# specify short layouts individually.
case "$LAYOUT" in
    "ABC") SHORT_LAYOUT="ABC";;
    "Spanish - ISO") SHORT_LAYOUT="ES";;
    *) SHORT_LAYOUT="한";;
esac

sketchybar --set keyboard label="$SHORT_LAYOUT"
