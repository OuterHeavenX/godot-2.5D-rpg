#!/usr/bin/env python3
"""Generate the looping ambient tracks for the outer regions.

Pure standard library: additive synthesis plus a feedback delay for space.
Run from the project root:  python3 tools/make_music.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "src", "audio", "music")


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def add(buf, start, samples, gain=1.0):
    i = int(start * RATE)
    n = len(buf)
    for s in samples:
        if 0 <= i < n:
            buf[i] += s * gain
        i += 1


def tone(freq, seconds, shape="sine", attack=0.01, decay=0.0, vib=0.0, vib_hz=5.0):
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1.0 + vib * math.sin(2 * math.pi * vib_hz * t))
        phase += 2 * math.pi * f / RATE
        if shape == "sine":
            v = math.sin(phase)
        elif shape == "saw":
            v = 2.0 * ((phase / (2 * math.pi)) % 1.0) - 1.0
        elif shape == "square":
            v = 1.0 if math.sin(phase) >= 0 else -1.0
        else:
            v = math.sin(phase)
        env = 1.0
        if attack > 0 and t < attack:
            env *= t / attack
        if decay > 0:
            env *= math.exp(-t / decay)
        else:
            tail = 0.02
            if t > seconds - tail:
                env *= max(0.0, (seconds - t) / tail)
        out.append(v * env)
    return out


def noise(seconds, decay=0.0, lowpass=0.0):
    n = int(RATE * seconds)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / RATE
        v = random.uniform(-1.0, 1.0)
        if lowpass > 0.0:
            prev = prev + (v - prev) * lowpass
            v = prev
        if decay > 0:
            v *= math.exp(-t / decay)
        out.append(v)
    return out


def delay(buf, seconds, feedback, mix):
    """Simple feedback delay so the loops feel like a place, not a speaker."""
    d = int(seconds * RATE)
    out = list(buf)
    for i in range(d, len(buf)):
        out[i] += out[i - d] * feedback
    for i in range(len(buf)):
        buf[i] = buf[i] * (1.0 - mix) + out[i] * mix
    return buf


def wrap_tail(buf, seconds):
    """Fold the tail back over the head so the loop has no seam."""
    n = int(seconds * RATE)
    for i in range(n):
        w = i / n
        buf[i] = buf[i] * w + buf[len(buf) - n + i] * (1.0 - w)
    del buf[len(buf) - n:]
    return buf


def write(name, buf, peak=0.72):
    hi = max(1e-6, max(abs(v) for v in buf))
    scale = peak / hi
    path = os.path.abspath(os.path.join(OUT, name))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32000)) for v in buf))
    print("wrote %s (%.1f s)" % (path, len(buf) / RATE))


def ash():
    """The Ashen Highlands: heat haze, war drums, a dry wind."""
    random.seed(7)
    length = 16.0
    buf = silence(length + 2.0)
    for f, g in ((73.42, 0.30), (110.0, 0.18), (146.8, 0.09)):
        add(buf, 0.0, tone(f, length + 2.0, "saw", attack=2.0, vib=0.004, vib_hz=0.13), g)
    # Slow war drum, two beats to the bar.
    t = 0.6
    while t < length + 1.0:
        add(buf, t, tone(58.0, 0.9, "sine", attack=0.002, decay=0.16), 0.85)
        add(buf, t, noise(0.18, decay=0.05, lowpass=0.25), 0.30)
        t += 2.0 if int(t) % 4 else 1.25
    # Embers.
    for _ in range(40):
        at = random.uniform(0.0, length)
        add(buf, at, noise(random.uniform(0.05, 0.2), decay=0.05, lowpass=0.6), 0.10)
    # A lone horn far off in the hills.
    add(buf, 5.0, tone(196.0, 2.4, "saw", attack=0.5, decay=1.4), 0.16)
    add(buf, 11.5, tone(146.8, 2.8, "saw", attack=0.6, decay=1.6), 0.13)
    buf = delay(buf, 0.37, 0.28, 0.35)
    return wrap_tail(buf, 2.0)


def mire():
    """The Mirefen: standing water, gas, things moving under the surface."""
    random.seed(11)
    length = 16.0
    buf = silence(length + 2.0)
    for f, g in ((49.0, 0.34), (49.6, 0.26), (98.0, 0.12)):
        add(buf, 0.0, tone(f, length + 2.0, "sine", attack=2.5, vib=0.006, vib_hz=0.09), g)
    # Drips.
    for _ in range(26):
        at = random.uniform(0.0, length)
        base = random.uniform(700.0, 1500.0)
        add(buf, at, tone(base, 0.25, "sine", attack=0.001, decay=0.05,
                          vib=0.3, vib_hz=9.0), 0.10)
    # Croaks and things surfacing.
    for at, f in ((2.3, 118.0), (6.9, 96.0), (10.4, 132.0), (13.8, 104.0)):
        add(buf, at, tone(f, 0.5, "square", attack=0.02, decay=0.12,
                          vib=0.09, vib_hz=17.0), 0.16)
    # Gas bubbling up.
    for _ in range(14):
        at = random.uniform(0.0, length)
        add(buf, at, noise(random.uniform(0.3, 0.8), decay=0.25, lowpass=0.12), 0.13)
    buf = delay(buf, 0.29, 0.34, 0.42)
    return wrap_tail(buf, 2.0)


def vault():
    """The Sunken Vault: stone, depth, and a bell nobody rings."""
    random.seed(13)
    length = 18.0
    buf = silence(length + 2.5)
    # Choir pad, swelling.
    for f, g in ((110.0, 0.26), (164.8, 0.17), (220.0, 0.11), (329.6, 0.05)):
        add(buf, 0.0, tone(f, length + 2.5, "sine", attack=3.0, vib=0.003, vib_hz=0.07), g)
    # Sub rumble under everything.
    add(buf, 0.0, tone(36.7, length + 2.5, "sine", attack=2.0, vib=0.01, vib_hz=0.05), 0.30)
    # Bell tolls.
    for at in (1.0, 7.0, 13.0):
        add(buf, at, tone(220.0, 4.0, "sine", attack=0.004, decay=1.5), 0.34)
        add(buf, at, tone(682.0, 3.0, "sine", attack=0.004, decay=0.8), 0.12)
        add(buf, at, tone(110.0, 4.5, "sine", attack=0.01, decay=2.0), 0.20)
    # Distant falling stone.
    for _ in range(9):
        at = random.uniform(0.0, length)
        add(buf, at, noise(random.uniform(0.1, 0.3), decay=0.08, lowpass=0.2), 0.12)
    buf = delay(buf, 0.53, 0.42, 0.5)
    return wrap_tail(buf, 2.5)


if __name__ == "__main__":
    write("ash_highlands.wav", ash())
    write("mire_drone.wav", mire())
    write("vault_deep.wav", vault())
