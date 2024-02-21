#!/usr/bin/env sh

CURRENT_WIFI="$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)"
SSID="$(echo "$CURRENT_WIFI" | grep -o "SSID: .*" | sed 's/^SSID: //')"
CURR_TX="$(echo "$CURRENT_WIFI" | grep -o "lastTxRate: .*" | sed 's/^lastTxRate: //')"

if [ "$SSID" = "" ]; then
	sketchybar --set $NAME icon="󰤭"
else
	RSSI="$(echo "$CURRENT_WIFI" | grep -o "agrCtlRSSI: .*" | sed 's/^agrCtlRSSI: //')"
	if [ "$RSSI" -gt -60 ]; then
		sketchybar --set $NAME icon="󰤨"
	elif [ "$RSSI" -gt -67 ]; then
		sketchybar --set $NAME icon="󰤥"
	elif [ "$RSSI" -gt -70 ]; then
		sketchybar --set $NAME icon="󰤢"
	elif [ "$RSSI" -gt -80 ]; then
		sketchybar --set $NAME icon="󰤟"
	else
		sketchybar --set $NAME icon="󰤠"
	fi
	# sketchybar --set $NAME label="$SSID (${CURR_TX}Mbps)"
fi
