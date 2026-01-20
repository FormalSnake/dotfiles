#!/usr/bin/env python3
import json
import subprocess
import time

MAX_WIDTH = 35
SCROLL_INTERVAL = 0.5


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
            "track": track,
            "icon": icon,
            "class": css_class,
            "status": player_status
        }
    except Exception:
        return None


def scroll_text(text, position, max_width):
    if len(text) <= max_width:
        return text, 0

    scrolled = text[position:] + "   " + text[:position]
    return scrolled[:max_width], (position + 1) % (len(text) + 3)


def main():
    scroll_position = 0
    last_track = None

    while True:
        info = get_spotify_info()

        if info:
            track = info["track"]
            icon = info["icon"]
            css_class = info["class"]
            status = info["status"]

            if track != last_track:
                scroll_position = 0
                last_track = track

            display_text, new_position = scroll_text(track, scroll_position, MAX_WIDTH)

            if status == "Playing":
                scroll_position = new_position

            output = {
                "text": f"{icon} {display_text}",
                "class": css_class,
                "tooltip": track
            }
            print(json.dumps(output), flush=True)
        else:
            last_track = None
            scroll_position = 0
            print(json.dumps({"text": "", "class": "stopped"}), flush=True)

        time.sleep(SCROLL_INTERVAL)


if __name__ == "__main__":
    main()
