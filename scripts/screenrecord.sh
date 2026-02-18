#!/usr/bin/env bash
# Toggle screen recording using gpu-screen-recorder
# Records to ~/Videos/Recordings

PIDFILE="/tmp/formalconf-screenrecord.pid"
RECORDING_DIR="$HOME/Videos/Recordings"

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    # Stop recording
    kill "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
    notify-send "Screen recording stopped" "Saved to $RECORDING_DIR"
else
    # Start recording
    mkdir -p "$RECORDING_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    FILE="$RECORDING_DIR/recording-$TIMESTAMP.mp4"

    # Freeze screen to let user select region
    if command -v wayfreeze >/dev/null 2>&1; then
        wayfreeze &
        FREEZE_PID=$!
        REGION=$(slurp)
        kill "$FREEZE_PID" 2>/dev/null
    else
        REGION=$(slurp)
    fi

    [[ -z "$REGION" ]] && exit 0

    gpu-screen-recorder -w "$REGION" -f 60 -o "$FILE" &
    echo $! > "$PIDFILE"
    notify-send "Screen recording started" "Recording to $FILE"
fi
