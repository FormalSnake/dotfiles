"""The FormalOS boot chime, synthesised from scratch (stdlib only).

chime.py <out.wav> writes it as 48 kHz stereo. The pixel logo's chiptune
arpeggio climbs into one wide chord.
"""

import math
import struct
import sys
import wave

RATE = 48000


def hz(note):
    """Note name like 'D4' or 'F#5' to Hz, A4 = 440."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[note[0]]
    rest = note[1:]
    if rest[0] == "#":
        semis, rest = semis + 1, rest[1:]
    elif rest[0] == "b":
        semis, rest = semis - 1, rest[1:]
    return 440.0 * 2 ** ((semis + 12 * (int(rest) - 4)) / 12)


def buffer(seconds):
    n = int(seconds * RATE)
    return [0.0] * n, [0.0] * n


def add(buf, start, f, length, partials, attack, decay, gain, pan=0.0, detune=0.0):
    """One additive voice: partials are (ratio, amplitude, decay multiplier)."""
    left, right = buf
    s0 = int(start * RATE)
    n = min(int(length * RATE), len(left) - s0)
    lg = gain * math.cos((pan + 1) * math.pi / 4)
    rg = gain * math.sin((pan + 1) * math.pi / 4)
    for ratio, amp, dmul in partials:
        w = 2 * math.pi * f * ratio * (1 + detune) / RATE
        k = 1.0 / (decay * dmul * RATE)
        a = 1.0 / max(1, attack * RATE)
        for i in range(n):
            env = min(1.0, i * a) * math.exp(-i * k)
            v = amp * env * math.sin(w * i)
            left[s0 + i] += v * lg
            right[s0 + i] += v * rg


def square(buf, start, f, length, gain, pan=0.0):
    """A soft pulse wave: odd harmonics rolled off, short pluck envelope."""
    add(buf, start, f, length, [(h, 1.0 / h ** 1.6, 1.0 / h ** 0.3) for h in (1, 3, 5, 7, 9)], 0.004, length / 4, gain, pan)


def reverb(buf, mix, size=1.0):
    """Schroeder: four combs into two allpasses, per channel."""
    out = []
    for ch, spread in zip(buf, (0, 23)):
        wet = [0.0] * len(ch)
        for d, fb in ((1557, 0.84), (1617, 0.83), (1491, 0.85), (1422, 0.86)):
            d = int((d + spread) * size * RATE / 44100)
            line = [0.0] * d
            j = 0
            for i, x in enumerate(ch):
                y = line[j]
                line[j] = x + y * fb
                wet[i] += y * 0.25
                j = (j + 1) % d
        for d in (225, 556):
            d = int(d * RATE / 44100)
            line = [0.0] * d
            j = 0
            for i, x in enumerate(wet):
                b = line[j]
                y = -x + b
                line[j] = x + b * 0.5
                wet[i] = y
                j = (j + 1) % d
        out.append([x * (1 - mix) + w * mix for x, w in zip(ch, wet)])
    return out


def finish(buf, peak=0.7, tail=0.4):
    left, right = buf
    m = max(max(map(abs, left)), max(map(abs, right))) or 1.0
    g = peak / m
    n = len(left)
    fade = int(tail * RATE)
    for i in range(n):
        f = min(1.0, (n - i) / fade)
        left[i] *= g * f
        right[i] *= g * f
    return left, right


BELL = [(1, 1.0, 1.0), (2.0, 0.35, 0.6), (2.76, 0.22, 0.45), (5.4, 0.08, 0.25), (8.93, 0.03, 0.15)]
PAD = [(1, 1.0, 1.0), (2, 0.4, 0.8), (3, 0.15, 0.6), (4, 0.07, 0.5)]


def formal():
    """The pixel arpeggio climbing into the glass chord, all in D."""
    buf = buffer(4.8)
    for i, note in enumerate(["D5", "F#5", "A5", "D6", "F#6"]):
        square(buf, i * 0.075, hz(note), 0.6, 0.3, -0.4 + i * 0.2)
    at = 0.4
    for note, pan in (("D3", 0), ("A3", -0.3), ("F#4", 0.3), ("A4", -0.5), ("E5", 0.5), ("D2", 0)):
        for det in (-0.0015, 0.0015):
            add(buf, at, hz(note), 4.4, PAD, 0.035, 1.6, 0.5, pan + det * 100, det)
    for note, pan in (("D5", -0.2), ("A5", 0.2)):
        add(buf, at, hz(note), 3.0, BELL, 0.002, 1.2, 0.25, pan)
    return finish(reverb(buf, 0.35, 1.3))


def main():
    left, right = formal()
    frames = b"".join(struct.pack("<hh", int(l * 32767), int(r * 32767)) for l, r in zip(left, right))
    with wave.open(sys.argv[1], "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


if __name__ == "__main__":
    main()
