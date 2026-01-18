#!/usr/bin/env python3
import json
import subprocess
import time


def get_spotify_info():
    try:
        status = subprocess.run(
            ["playerctl", "-p", "spotify", "status"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if status.returncode != 0:
            return None

        player_status = status.stdout.strip()

        metadata = subprocess.run(
            ["playerctl", "-p", "spotify", "metadata", "--format", "{{artist}} - {{title}}"],
            capture_output=True,
            text=True,
            timeout=2
        )
        if metadata.returncode != 0:
            return None

        track = metadata.stdout.strip()
        if not track or track == " - ":
            return None

        if player_status == "Playing":
            icon = "󰓇"
            css_class = "playing"
        elif player_status == "Paused":
            icon = "󰏤"
            css_class = "paused"
        else:
            icon = "󰓇"
            css_class = "stopped"

        return {
            "text": f"{icon} {track}",
            "class": css_class,
            "tooltip": track
        }
    except Exception:
        return None


def main():
    while True:
        info = get_spotify_info()
        if info:
            print(json.dumps(info), flush=True)
        else:
            print(json.dumps({"text": "", "class": "stopped"}), flush=True)
        time.sleep(1)


if __name__ == "__main__":
    main()
