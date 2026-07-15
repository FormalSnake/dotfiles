#!/usr/bin/env python3
"""Ambient per-key keyboard lighting: sample the focused screen, stream it to the
ASUS N-KEY keyboard via OpenRGB's Direct mode. Horizontal Ambilight spread — each
keyboard column takes the colour of the matching screen column.

Runs as the aura-ambient user service (AC only). Connects to a local OpenRGB
server the wrapper starts. Tuning knobs are the constants below."""

import io
import json
import subprocess
import sys
import time
import colorsys

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor
from PIL import Image

FPS = 15.0            # frame rate cap
GRAB_SCALE = 0.05     # grim downscale factor (2560px -> ~128px, cheap)
SMOOTH = 0.45         # per-column exponential smoothing (0..1, higher = snappier)
SAT = 1.4             # saturation multiplier — LEDs wash pastels out
VAL_GAMMA = 0.5       # <1 lifts dark tones; keeps range (bright stays < full)
VAL_GAIN = 1.0        # flat gain clamps bright areas to white — keep at 1.0
REASSERT = 5.0        # re-assert Direct mode every N s if something knocked it out

FRAME = 1.0 / FPS


def focused_connector():
    """niri's focused-output connector (e.g. eDP-1), or None to grab everything."""
    try:
        out = subprocess.run(
            ["niri", "msg", "--json", "focused-output"],
            capture_output=True, text=True, timeout=1.0,
        )
        if out.returncode == 0:
            return json.loads(out.stdout).get("name") or None
    except Exception:
        pass
    return None


def grab_columns(ncols):
    """Capture the focused screen, box-average it into `ncols` (r,g,b) columns."""
    cmd = ["grim", "-s", str(GRAB_SCALE), "-t", "ppm"]
    conn = focused_connector()
    if conn:
        cmd += ["-o", conn]
    cmd.append("-")
    shot = subprocess.run(cmd, capture_output=True, timeout=2.0)
    if shot.returncode != 0 or not shot.stdout:
        return None
    img = Image.open(io.BytesIO(shot.stdout)).convert("RGB")
    row = img.resize((ncols, 1), Image.BOX)
    return [row.getpixel((c, 0)) for c in range(ncols)]


def vivid(rgb):
    """Boost saturation / floor value so the mapped colour reads on the LEDs."""
    r, g, b = (v / 255.0 for v in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    s = min(1.0, s * SAT)
    v = min(1.0, (v ** VAL_GAMMA) * VAL_GAIN)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (round(r * 255), round(g * 255), round(b * 255))


def find_keyboard(client):
    """The per-key keyboard, or None if not detected yet. The ASUS N-KEY reports
    as DeviceType.UNKNOWN, so select on capability (a Direct mode + LEDs),
    preferring a 'Keyboard' zone, rather than on device type."""
    candidates = [
        dev for dev in client.devices
        if dev.leds and any(m.name.lower() == "direct" for m in dev.modes)
    ]
    for dev in candidates:
        if any(z.name.lower() == "keyboard" for z in dev.zones):
            return dev
    return candidates[0] if candidates else None


def wait_for_keyboard(client, tries=100):
    """Poll until the server finishes its hardware scan and the keyboard appears.
    The wrapper starts the server and runs us immediately, so the device list is
    usually empty for the first few seconds (i2c probing, etc.)."""
    for _ in range(tries):
        kbd = find_keyboard(client)
        if kbd:
            return kbd
        time.sleep(0.3)
        try:
            client.update()
        except Exception:
            pass
    raise SystemExit("no per-key (Direct-capable) device found via OpenRGB")


def column_of_led(kbd):
    """Map each device LED index -> screen column index, and return (map, ncols).

    Uses the keyboard zone's matrix layout when present (real key geometry);
    falls back to spreading LEDs evenly across a fixed column count."""
    zone = kbd.zones[0] if kbd.zones else None
    if zone and zone.matrix_map and zone.mat_width and zone.mat_width > 0:
        ncols = zone.mat_width
        col = {}
        for r, rowcells in enumerate(zone.matrix_map):
            for c, led_idx in enumerate(rowcells):
                if led_idx is not None:
                    col[led_idx] = c
        # Any LED missing from the matrix falls back to a proportional guess.
        n = len(kbd.leds)
        for i in range(n):
            col.setdefault(i, round(i / max(1, n - 1) * (ncols - 1)))
        return col, ncols
    n = len(kbd.leds)
    ncols = min(16, max(1, n))
    col = {i: round(i / max(1, n - 1) * (ncols - 1)) for i in range(n)}
    return col, ncols


def connect(retries=50):
    for _ in range(retries):
        try:
            return OpenRGBClient(name="aura-ambient")
        except Exception:
            time.sleep(0.2)
    raise SystemExit("could not connect to OpenRGB server")


def main():
    client = connect()
    kbd = wait_for_keyboard(client)
    kbd.set_mode("Direct")
    col_of, ncols = column_of_led(kbd)
    nleds = len(kbd.leds)

    smoothed = [(0, 0, 0)] * ncols
    last_reassert = time.monotonic()
    while True:
        t0 = time.monotonic()
        # If something (asusd, a manual asusctl call) switched the device out of
        # Direct mode, our per-key writes stop taking. Re-assert Direct when we
        # notice — only when actually needed, so there's no periodic flicker.
        if t0 - last_reassert >= REASSERT:
            last_reassert = t0
            try:
                client.update()
                if kbd.modes[kbd.active_mode].name.lower() != "direct":
                    kbd.set_mode("Direct")
            except Exception:
                pass
        cols = grab_columns(ncols)
        if cols is not None:
            for c in range(ncols):
                cur = vivid(cols[c])
                prev = smoothed[c]
                smoothed[c] = tuple(
                    round(prev[k] + (cur[k] - prev[k]) * SMOOTH) for k in range(3)
                )
            frame = [RGBColor(*smoothed[col_of[i]]) for i in range(nleds)]
            try:
                kbd.set_colors(frame, fast=True)
            except Exception as e:
                print(f"aura-ambient: set_colors failed: {e}", file=sys.stderr)
                return 1
        dt = time.monotonic() - t0
        if dt < FRAME:
            time.sleep(FRAME - dt)


if __name__ == "__main__":
    sys.exit(main() or 0)
