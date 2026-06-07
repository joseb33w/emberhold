#!/usr/bin/env python3
"""Synthesize Emberhold's procedural audio (CC0, tiny OGG files).

Writes mono 32 kHz WAVs then encodes them to OGG with ffmpeg so the
exported .pck stays small. Re-run any time: `python3 tools/gen_audio.py`.
"""
import math
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")
os.makedirs(OUT, exist_ok=True)


def _norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def _adsr(n, a, d, s, r, sl=0.6):
    a = max(1, int(a * n)); d = max(1, int(d * n)); r = max(1, int(r * n))
    sus = max(0, n - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, a),
        np.linspace(1, sl, d),
        np.full(sus, sl),
        np.linspace(sl, 0, r),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def _sine(freq, t):
    return np.sin(2 * np.pi * freq * t)


def _save(name, samples, loop=False):
    samples = _norm(samples).astype(np.float32)
    pcm = (samples * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wav_path = tf.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    ogg_path = os.path.join(OUT, name + ".ogg")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
         "-c:a", "libvorbis", "-q:a", "2", ogg_path],
        check=True,
    )
    os.unlink(wav_path)
    print(f"  {name}.ogg  {os.path.getsize(ogg_path)//1024} KB")


# ---------------- MUSIC: torchlit town (light, hopeful) ----------------
def town_music():
    bpm = 96
    beat = 60.0 / bpm
    bars = 8
    total = beat * 4 * bars
    n = int(total * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    prog = [[220.0, 277.18, 329.63], [196.0, 246.94, 293.66],
            [174.61, 220.0, 261.63], [196.0, 246.94, 329.63]]
    seg = total / len(prog)
    for i, chord in enumerate(prog):
        s = int(i * seg * SR); e = int((i + 1) * seg * SR)
        tt = np.arange(e - s) / SR
        pad = np.zeros(e - s)
        for f in chord:
            pad += _sine(f, tt) * 0.5 + _sine(f * 2, tt) * 0.12
        amp = 0.5 + 0.5 * np.sin(np.pi * np.arange(e - s) / (e - s))
        out[s:e] += pad * amp * 0.18
    scale = [440.0, 523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25]
    step = beat / 2
    k = 0
    pos = 0.0
    while pos < total - step:
        s = int(pos * SR)
        ln = int(step * SR)
        tt = np.arange(ln) / SR
        f = scale[k % len(scale)]
        note = (_sine(f, tt) + 0.3 * _sine(f * 2, tt)) * _adsr(ln, 0.01, 0.2, 0.0, 0.4, 0.0)
        out[s:s + ln] += note * 0.22
        pos += step
        k += 1
    pos = 0.0
    while pos < total:
        s = int(pos * SR)
        ln = int(0.12 * SR)
        tt = np.arange(ln) / SR
        f = 90 * np.exp(-tt * 18)
        kick = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 9)
        out[s:s + ln] += kick * 0.5
        pos += beat
    return _norm(out, 0.8)


# ---------------- MUSIC: dungeon ambience (dark, tense) ----------------
def dungeon_ambience():
    total = 16.0
    n = int(total * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    out += np.sin(2 * np.pi * 55.0 * t) * 0.5
    out += np.sin(2 * np.pi * 55.5 * t) * 0.4
    out += np.sin(2 * np.pi * 82.41 * t) * 0.25
    out *= 0.4 + 0.3 * np.sin(2 * np.pi * t / 8.0)
    shimmer = (np.sin(2 * np.pi * 660 * t) + np.sin(2 * np.pi * 990 * t)) * 0.5
    shimmer *= np.clip(np.sin(2 * np.pi * t / 5.0), 0, 1) ** 3 * 0.06
    out += shimmer
    rng = np.random.default_rng(7)
    for _ in range(10):
        s = int(rng.uniform(0, total - 0.6) * SR)
        ln = int(0.5 * SR)
        tt = np.arange(ln) / SR
        f = rng.uniform(120, 240)
        drip = np.sin(2 * np.pi * f * tt) * np.exp(-tt * 7) * 0.18
        out[s:s + ln] += drip
    wind = np.cumsum(rng.standard_normal(n)) * 0.0002
    wind -= np.linspace(wind[0], wind[-1], n)
    out += wind * 0.5
    return _norm(out, 0.7)


# ---------------- SFX ----------------
def sfx_footstep():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(3)
    body = rng.standard_normal(n) * np.exp(-t * 45)
    thump = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 30) * 0.6
    return _norm(body * 0.6 + thump, 0.7)


def sfx_swing():
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(11)
    noise = rng.standard_normal(n)
    sweep = np.sin(2 * np.pi * (400 + 1800 * t) * t)
    env = np.exp(-((t - 0.12) ** 2) / (2 * 0.05 ** 2))
    return _norm((noise * 0.5 + sweep * 0.5) * env, 0.7)


def sfx_hit():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(5)
    clang = (np.sin(2 * np.pi * 320 * t) + np.sin(2 * np.pi * 540 * t)
             + np.sin(2 * np.pi * 870 * t)) * np.exp(-t * 16)
    impact = rng.standard_normal(n) * np.exp(-t * 40)
    return _norm(clang * 0.6 + impact * 0.5, 0.9)


def sfx_takehit():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(9)
    thud = np.sin(2 * np.pi * (180 * np.exp(-t * 5)) * t) * np.exp(-t * 12)
    crunch = rng.standard_normal(n) * np.exp(-t * 22) * 0.5
    return _norm(thud * 0.7 + crunch, 0.85)


def sfx_death():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    rng = np.random.default_rng(13)
    for k in range(7):
        s = int((0.02 + k * 0.07) * SR)
        ln = int(0.05 * SR)
        tt = np.arange(ln) / SR
        f = 900 - k * 90
        out[s:s + ln] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 60) * 0.5
    crumble = rng.standard_normal(n) * np.exp(-t * 6) * 0.3
    low = np.sin(2 * np.pi * (120 * np.exp(-t * 2)) * t) * np.exp(-t * 4) * 0.4
    return _norm(out + crumble + low, 0.85)


def sfx_loot():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    notes = [784, 988, 1319]
    out = np.zeros(n)
    for i, f in enumerate(notes):
        s = int(i * 0.07 * SR)
        tt = np.arange(n - s) / SR
        out[s:] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 6) * 0.4
    return _norm(out, 0.8)


def sfx_ui():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * 660 * t) + 0.4 * np.sin(2 * np.pi * 1320 * t)
    return _norm(tone * _adsr(n, 0.02, 0.2, 0.0, 0.6, 0.0), 0.6)


def sfx_npc():
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    f = 520 + 120 * np.sin(2 * np.pi * 8 * t)
    blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * _adsr(n, 0.05, 0.2, 0.0, 0.5, 0.3)
    return _norm(blip, 0.55)


def main():
    print("Synthesizing Emberhold audio ->", OUT)
    _save("town_music", town_music(), loop=True)
    _save("dungeon_ambience", dungeon_ambience(), loop=True)
    _save("sfx_footstep", sfx_footstep())
    _save("sfx_swing", sfx_swing())
    _save("sfx_hit", sfx_hit())
    _save("sfx_takehit", sfx_takehit())
    _save("sfx_death", sfx_death())
    _save("sfx_loot", sfx_loot())
    _save("sfx_ui", sfx_ui())
    _save("sfx_npc", sfx_npc())
    print("done.")


if __name__ == "__main__":
    main()
