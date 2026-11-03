#!/usr/bin/env bash
# Keeps a BetterDisplay virtual screen connected, so with the lid closed Sunshine still has a
# display to capture. BetterDisplay starts at login; this waits for it, then creates the screen
# when its settings lost it.
set -u
B=/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay
for _ in $(seq 60); do
	pgrep -xq BetterDisplay && "$B" get -name=Default\ Group -identifiers >/dev/null 2>&1 && break
	sleep 2
done
if ! "$B" get -name=Headless -identifiers >/dev/null 2>&1; then
	"$B" create -type=VirtualScreen -virtualScreenName=Headless -aspectWidth=16 -aspectHeight=10 -virtualScreenHiDPI=on
fi
"$B" set -name=Headless -connected=on
