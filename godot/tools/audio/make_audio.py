#!/usr/bin/env python3
"""Synthesizes every sound the battle uses: no samples, only numpy.

    python3 godot/tools/audio/make_audio.py            # writes godot/assets/audio/sfx/*.ogg and music/*.ogg

These are PLACEHOLDERS made by Claude (Nov 2026) so the battle is not silent: the owner has supplied no audio. Replace any
file with a real recording of the same name and it plays with no code change (see CombatAudio / BattleMusic).
Needs numpy, scipy and ffmpeg (for the ogg encode). The output is deterministic (fixed seed).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "audio")


# ---------- building blocks ----------

def t(secs):
    return np.arange(int(SR * secs)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    """ADSR over n samples (attack, decay to `s`, hold, release)."""
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    h_n = max(0, n - a_n - d_n - r_n) if hold <= 0 else int(hold * SR)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)),
        np.linspace(1, s, max(d_n, 1)),
        np.full(h_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def decay(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def noise(n):
    return RNG.uniform(-1, 1, n)


def lp(x, hz, order=2):
    b, a = signal.butter(order, min(hz, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep(n, f0, f1, curve=1.0):
    """A sine whose pitch glides from f0 to f1."""
    k = np.linspace(0, 1, n) ** curve
    f = f0 * (f1 / f0) ** k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def swept_noise(n, f0, f1, q=3.0):
    """Noise through a band that glides: the whoosh of a swing."""
    x = noise(n)
    out = np.zeros(n)
    block = 256
    zi = None
    for i in range(0, n, block):
        k = i / max(n - 1, 1)
        f = f0 * (f1 / f0) ** k
        lo, hi = f / (1 + 1 / q), f * (1 + 1 / q)
        b, a = signal.butter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
        if zi is None or len(zi) != max(len(a), len(b)) - 1:
            zi = np.zeros(max(len(a), len(b)) - 1)
        out[i:i + block], zi = signal.lfilter(b, a, x[i:i + block], zi=zi)
    return out


def saw(f, n, detune=0.0):
    ph = np.cumsum(np.full(n, f * (1 + detune))) / SR
    return 2 * (ph % 1.0) - 1


def square(f, n, duty=0.5):
    ph = (np.cumsum(np.full(n, f)) / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(f, n):
    return 2 * np.abs(saw(f, n)) - 1


def reverb(x, secs=0.6, mix=0.2, tone=3500):
    """A short hall: the signal convolved with decaying filtered noise."""
    n = int(secs * SR)
    ir = lp(noise(n), tone) * decay(n, secs / 4)
    ir[: int(0.004 * SR)] = 0
    wet = pad_to(signal.fftconvolve(x, ir), len(x) + n)[: len(x) + n]
    wet /= max(np.max(np.abs(wet)), 1e-9)
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - mix) + wet * mix * np.max(np.abs(x))


def norm(x, peak=0.89):
    x = x - np.mean(x)
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def soft(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def pad_to(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:max(n, len(x))]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, x, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


def fade(x, a=0.002, r=0.01):
    n = len(x)
    a_n, r_n = min(int(a * SR), n // 2), min(int(r * SR), n // 2)
    x = x.copy()
    x[:a_n] *= np.linspace(0, 1, a_n)
    x[n - r_n:] *= np.linspace(1, 0, r_n)
    return x


# ---------- sound effects ----------

def whoosh(secs, f0, f1, q=2.5):
    n = int(secs * SR)
    e = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    return swept_noise(n, f0, f1, q) * e


def swing_sword():
    w = whoosh(0.2, 900, 4200) + 0.25 * whoosh(0.2, 2500, 7000, 4.0)
    return norm(fade(w), 0.6)


def swing_dagger():
    return norm(fade(whoosh(0.11, 2200, 7500, 3.5)), 0.5)


def swing_heavy():
    w = whoosh(0.34, 180, 1500, 1.8) + 0.5 * whoosh(0.34, 500, 2600)
    return norm(fade(w), 0.7)


def projectile_loose():
    n = int(0.3 * SR)
    twang = np.sin(2 * np.pi * 180 * t(0.3)) * decay(n, 0.04) * (1 + 0.5 * np.sin(2 * np.pi * 55 * t(0.3)))
    return norm(fade(mix(0.6 * twang, whoosh(0.26, 1800, 6500, 4.0))), 0.6)


def magic_cast():
    n = int(0.55 * SR)
    tt = t(0.55)
    shimmer = sum(np.sin(2 * np.pi * f * (1 + 0.5 * tt) * tt + i) for i, f in enumerate([660, 990, 1320, 1760])) / 4
    shimmer *= np.linspace(0, 1, n) ** 2 * (1 + 0.4 * np.sin(2 * np.pi * 14 * tt))
    air = hp(noise(n), 5000) * np.linspace(0, 1, n) ** 3 * 0.25
    return norm(fade(reverb(shimmer + air, 0.4, 0.3)), 0.55)


def thud(f0=140, f1=45, secs=0.22, tau=0.06):
    n = int(secs * SR)
    return sweep(n, f0, f1, 0.5) * decay(n, tau)


def clang(freqs, secs=0.35, tau=0.07):
    n = int(secs * SR)
    tt = t(secs)
    out = np.zeros(n)
    for i, f in enumerate(freqs):
        out += np.sin(2 * np.pi * f * tt + i) * decay(n, tau / (1 + 0.35 * i)) / (1 + 0.4 * i)
    return out


def crack(secs=0.06, lo=1500, hi=9000, tau=0.012):
    n = int(secs * SR)
    return bp(noise(n), lo, hi) * decay(n, tau)


def impact_blade():
    x = mix(1.0 * crack(0.07, 1800, 9000, 0.014), 0.55 * clang([1870, 2930, 4410, 6120], 0.3, 0.05), 0.8 * thud(170, 60, 0.16, 0.035))
    return norm(fade(soft(x * 1.6)), 0.85)


def impact_sharp():
    x = mix(1.0 * crack(0.05, 3000, 11000, 0.009), 0.4 * clang([2640, 3980, 5870], 0.2, 0.035), 0.5 * thud(220, 90, 0.1, 0.02))
    return norm(fade(soft(x * 1.5)), 0.75)


def impact_heavy():
    x = mix(1.2 * thud(120, 34, 0.42, 0.09), 0.8 * lp(crack(0.12, 200, 2500, 0.03), 2500), 0.35 * lp(noise(int(0.4 * SR)), 500) * decay(int(0.4 * SR), 0.12))
    return norm(fade(reverb(soft(x * 2.0), 0.35, 0.15, 1200)), 0.92)


def impact_arrow():
    x = mix(0.9 * crack(0.04, 2000, 8000, 0.008), 0.9 * thud(260, 110, 0.12, 0.025),
            0.3 * np.sin(2 * np.pi * 95 * t(0.25)) * decay(int(0.25 * SR), 0.05) * np.sin(2 * np.pi * 28 * t(0.25)))
    return norm(fade(soft(x * 1.4)), 0.75)


def magic_hit():
    n = int(0.5 * SR)
    tt = t(0.5)
    zap = sweep(n, 1900, 240, 0.4) * decay(n, 0.07)
    bell = clang([880, 1320, 1975, 2640], 0.5, 0.14) * 0.5
    burst = bp(noise(n), 700, 6000) * decay(n, 0.05) * 0.7
    x = zap * (0.6 + 0.4 * np.sin(2 * np.pi * 60 * tt)) + bell + burst + 0.6 * pad_to(thud(150, 50, 0.2, 0.05), n)
    return norm(fade(reverb(soft(x * 1.3), 0.5, 0.22)), 0.8)


def impact_crit():
    base = mix(1.2 * crack(0.09, 1500, 10000, 0.018), 0.7 * clang([1560, 2340, 3510, 4680, 7020], 0.6, 0.11), 1.2 * thud(190, 38, 0.4, 0.09))
    n = int(0.7 * SR)
    ring = np.sin(2 * np.pi * 3136 * t(0.7)) * decay(n, 0.2) * 0.18
    tail = hp(noise(n), 4000) * decay(n, 0.1) * 0.25
    x = mix(base, ring, tail)
    return norm(fade(reverb(soft(x * 2.2), 0.7, 0.25)), 0.95)


def miss():
    return norm(fade(whoosh(0.2, 3200, 900, 3.0)), 0.35)


def block():
    x = mix(0.9 * clang([520, 1210, 1790, 2890], 0.4, 0.09), 0.7 * crack(0.05, 900, 5000, 0.012), 0.6 * thud(150, 70, 0.12, 0.03))
    return norm(fade(soft(x * 1.5)), 0.75)


def heal():
    out = np.zeros(int(0.9 * SR))
    for i, n_ in enumerate([72, 76, 79, 84]):
        n = int(0.5 * SR)
        tt = t(0.5)
        tone = (np.sin(2 * np.pi * midi(n_) * tt) + 0.3 * np.sin(2 * np.pi * midi(n_) * 2 * tt)) * decay(n, 0.14)
        place(out, tone * 0.5, i * 0.07)
    return norm(fade(reverb(out, 0.6, 0.35)), 0.55)


def ko():
    n = int(0.6 * SR)
    fall = sweep(n, 420, 60, 0.7) * decay(n, 0.16) * 0.6
    body = pad_to(np.zeros(int(0.18 * SR)), 0)
    drop = np.concatenate([np.zeros(int(0.2 * SR)), thud(110, 36, 0.3, 0.08)])
    air = lp(noise(n), 1800) * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.25
    return norm(fade(reverb(mix(fall, drop, air, body), 0.5, 0.25, 1800)), 0.8)


def step():
    n = int(0.07 * SR)
    x = lp(noise(n), 900) * decay(n, 0.014) + 0.5 * thud(120, 70, 0.07, 0.015)
    return norm(fade(x), 0.3)


def ui_hover():
    n = int(0.045 * SR)
    return norm(fade(np.sin(2 * np.pi * 1320 * t(0.045)) * decay(n, 0.012)), 0.22)


def ui_click():
    n = int(0.09 * SR)
    x = np.sin(2 * np.pi * 880 * t(0.09)) * decay(n, 0.02) + 0.5 * np.sin(2 * np.pi * 1760 * t(0.09)) * decay(n, 0.012) + 0.4 * pad_to(crack(0.02, 2000, 8000, 0.004), n)
    return norm(fade(x), 0.4)


def ui_back():
    n = int(0.11 * SR)
    return norm(fade(sweep(n, 700, 380, 1.0) * decay(n, 0.03)), 0.35)


def ui_confirm():
    out = np.zeros(int(0.28 * SR))
    for i, n_ in enumerate([76, 83]):
        n = int(0.2 * SR)
        place(out, (np.sin(2 * np.pi * midi(n_) * t(0.2)) + 0.3 * tri(midi(n_) * 2, n)) * decay(n, 0.05) * 0.5, i * 0.06)
    return norm(fade(out), 0.45)


def bell(n_, secs=0.9, tau=0.25):
    n = int(secs * SR)
    tt = t(secs)
    f = midi(n_)
    return (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * f * 2.01 * tt) * decay(n, tau / 2) + 0.25 * np.sin(2 * np.pi * f * 3.98 * tt) * decay(n, tau / 3)) * decay(n, tau)


def turn_player():
    out = np.zeros(int(0.7 * SR))
    place(out, bell(74, 0.5, 0.12) * 0.5, 0)
    place(out, bell(81, 0.6, 0.16) * 0.5, 0.08)
    return norm(fade(reverb(out, 0.5, 0.3)), 0.4)


def turn_enemy():
    n = int(0.4 * SR)
    x = (saw(midi(38), n) + saw(midi(38) * 1.01, n)) * 0.5
    x = lp(x, 500) * env(n, 0.01, 0.15, 0.3, 0.2)
    return norm(fade(reverb(x, 0.4, 0.25, 900)), 0.4)


def callout():
    """A banner slams in: a rush and a hit."""
    rush = whoosh(0.16, 500, 5000, 2.0)
    hit = np.concatenate([np.zeros(int(0.12 * SR)), mix(thud(160, 50, 0.25, 0.06), 0.5 * clang([1046, 1568, 2093], 0.5, 0.12))])
    return norm(fade(reverb(mix(0.6 * rush, hit), 0.5, 0.22)), 0.7)


def momentum_tick():
    n = int(0.12 * SR)
    return norm(fade(sweep(n, 600, 1400, 1.0) * decay(n, 0.04)), 0.25)


def surge_ready():
    out = np.zeros(int(1.2 * SR))
    for i, n_ in enumerate([62, 69, 74, 78, 81, 86]):
        place(out, bell(n_, 0.7, 0.18) * 0.4, i * 0.055)
    n = int(0.5 * SR)
    place(out, hp(noise(n), 6000) * np.linspace(0, 1, n) ** 2 * decay(n, 0.3)[::-1] * 0.2, 0)
    return norm(fade(reverb(out, 0.8, 0.35)), 0.6)


def surge():
    """Surge spent: a rising charge and a burst."""
    n = int(0.5 * SR)
    tt = t(0.5)
    charge = (saw(1, n) * 0)  # placeholder array of the right length
    f = 110 * (8 ** (np.linspace(0, 1, n) ** 1.5))
    ph = np.cumsum(f) / SR
    charge = (2 * (ph % 1.0) - 1) * 0.35 + np.sin(2 * np.pi * ph * 2) * 0.4
    charge = lp(charge, 5000) * np.linspace(0.1, 1, n) ** 2
    air = swept_noise(n, 400, 8000, 2.0) * np.linspace(0, 1, n) ** 2 * 0.5
    boom = np.concatenate([np.zeros(n), mix(1.2 * thud(200, 36, 0.6, 0.14), 0.6 * clang([784, 1175, 1568, 2349], 0.9, 0.25), 0.5 * crack(0.12, 1000, 9000, 0.03))])
    return norm(fade(reverb(soft(mix(charge + air, boom) * 1.6), 0.9, 0.3)), 0.92)


def summon():
    n = int(0.9 * SR)
    tt = t(0.9)
    rise = sum(np.sin(2 * np.pi * f * (1 + 0.6 * tt / 0.9) * tt) for f in [220, 330, 440, 660]) / 4 * np.sin(np.linspace(0, np.pi, n)) ** 1.2
    spark = hp(noise(n), 5000) * (np.linspace(0, 1, n) ** 2) * 0.2
    chime = np.concatenate([np.zeros(int(0.55 * SR)), bell(86, 0.7, 0.2) * 0.5 + bell(93, 0.7, 0.2) * 0.3])
    return norm(fade(reverb(mix(rise * 0.6 + spark, chime), 0.8, 0.35)), 0.6)


def sword_get():
    out = np.zeros(int(0.9 * SR))
    place(out, clang([2093, 3140, 4186, 6280], 0.6, 0.16) * 0.5, 0)
    for i, n_ in enumerate([79, 83, 86, 91]):
        place(out, bell(n_, 0.5, 0.12) * 0.35, 0.08 + i * 0.06)
    return norm(fade(reverb(out, 0.7, 0.3)), 0.6)


def battle_start():
    """A war drum roll into a hit, with a low brass swell."""
    out = np.zeros(int(1.8 * SR))
    times = [0.0, 0.22, 0.4, 0.54, 0.64, 0.72, 0.78, 0.83, 0.88]
    for i, at in enumerate(times):
        place(out, thud(130, 55, 0.2, 0.05) * (0.35 + 0.07 * i), at)
    n = int(0.95 * SR)
    swell = sum(saw(midi(m), n, d) for m in [38, 45, 50] for d in [0, 0.004]) / 6
    swell = lp(swell, 900) * np.linspace(0, 1, n) ** 2
    place(out, swell * 0.5, 0.0)
    final = mix(1.3 * thud(150, 34, 0.7, 0.16), 0.5 * clang([587, 880, 1175, 1760], 0.8, 0.22), 0.5 * crack(0.1, 800, 7000, 0.03))
    place(out, final, 0.95)
    return norm(fade(reverb(soft(out * 1.5), 0.9, 0.28, 2500)), 0.9)


def xp_tick():
    n = int(0.035 * SR)
    return norm(fade(np.sin(2 * np.pi * 1975 * t(0.035)) * decay(n, 0.008)), 0.18)


def level_up():
    out = np.zeros(int(1.5 * SR))
    for i, n_ in enumerate([69, 73, 76, 81, 85, 88]):
        n = int(0.5 * SR)
        tone = (square(midi(n_), n, 0.3) * 0.25 + np.sin(2 * np.pi * midi(n_) * t(0.5))) * env(n, 0.004, 0.2, 0.2, 0.2)
        place(out, lp(tone, 5000) * 0.4, i * 0.075)
    place(out, bell(93, 0.9, 0.3) * 0.3, 0.45)
    return norm(fade(reverb(out, 0.9, 0.35)), 0.65)


def grade_stamp():
    x = mix(1.3 * thud(170, 36, 0.5, 0.11), 0.7 * crack(0.08, 900, 7000, 0.02), 0.6 * clang([523, 784, 1046, 1568, 2093], 0.9, 0.25))
    return norm(fade(reverb(soft(x * 1.8), 0.9, 0.3)), 0.92)


def feat_pop():
    out = np.zeros(int(0.3 * SR))
    place(out, bell(88, 0.25, 0.06) * 0.5, 0)
    place(out, crack(0.02, 2500, 9000, 0.005) * 0.3, 0)
    return norm(fade(out), 0.4)


def reward():
    out = np.zeros(int(1.0 * SR))
    for i, n_ in enumerate([76, 81, 85, 88]):
        place(out, bell(n_, 0.6, 0.16) * 0.4, i * 0.09)
    return norm(fade(reverb(out, 0.7, 0.35)), 0.55)


def warning():
    out = np.zeros(int(0.7 * SR))
    for i in range(2):
        n = int(0.22 * SR)
        x = lp(square(midi(63), n) * 0.5 + square(midi(57), n) * 0.5, 2200) * env(n, 0.005, 0.05, 0.6, 0.06)
        place(out, x, i * 0.28)
    return norm(fade(reverb(out, 0.4, 0.2)), 0.5)


SFX = {f.__name__: f for f in [
    swing_sword, swing_dagger, swing_heavy, projectile_loose, magic_cast, impact_blade, impact_sharp, impact_heavy,
    impact_arrow, magic_hit, impact_crit, miss, block, heal, ko, step, ui_hover, ui_click, ui_back, ui_confirm,
    turn_player, turn_enemy, callout, momentum_tick, surge_ready, surge, summon, sword_get, battle_start, xp_tick,
    level_up, grade_stamp, feat_pop, reward, warning,
]}


# ---------- music ----------

def brass(n_, secs, vib=True):
    n = int(secs * SR)
    tt = t(secs)
    f = midi(n_) * (1 + (0.004 * np.sin(2 * np.pi * 5.5 * tt) * np.clip(tt * 4 - 0.6, 0, 1) if vib else 0))
    ph = np.cumsum(f) / SR
    x = (2 * (ph % 1.0) - 1) * 0.6 + np.where((ph % 1.0) < 0.5, 1.0, -1.0) * 0.25
    bright = lp(x, 900 + 2600 * min(1.0, 0.2 / max(secs, 0.05) + 0.5))
    return bright * env(n, 0.025, 0.08, 0.75, min(0.12, secs / 3))


def strings(notes, secs, cutoff=1800):
    n = int(secs * SR)
    x = np.zeros(n)
    for m in notes:
        for d in [-0.006, 0.0, 0.007]:
            x += saw(midi(m), n, d)
    x = lp(x / (3 * len(notes)), cutoff)
    return x * env(n, min(0.25, secs / 3), 0.1, 0.9, min(0.4, secs / 3))


def pluck(n_, secs=0.22, cutoff=3200):
    n = int(secs * SR)
    x = saw(midi(n_), n) * 0.6 + square(midi(n_), n, 0.4) * 0.3
    return lp(x, cutoff) * decay(n, secs / 3.5) * env(n, 0.003, 0.01, 1.0, 0.02)


def bass_note(n_, secs):
    n = int(secs * SR)
    x = saw(midi(n_), n) * 0.5 + np.sin(2 * np.pi * midi(n_) * t(secs)) * 0.8
    return lp(x, 420) * env(n, 0.006, 0.05, 0.7, 0.03)


def kick():
    n = int(0.22 * SR)
    return sweep(n, 150, 42, 0.4) * decay(n, 0.07)


def snare():
    n = int(0.2 * SR)
    return bp(noise(n), 900, 7000) * decay(n, 0.045) * 0.8 + np.sin(2 * np.pi * 190 * t(0.2)) * decay(n, 0.03) * 0.5


def hat(open_=False):
    n = int((0.16 if open_ else 0.045) * SR)
    return hp(noise(n), 7000) * decay(n, 0.05 if open_ else 0.012)


def tom(f=110):
    n = int(0.3 * SR)
    return sweep(n, f * 1.5, f * 0.7, 0.5) * decay(n, 0.09)


def loop_fold(buf, loop_len):
    """Folds whatever rings past the loop's end back onto its start, so the loop is seamless."""
    n = int(loop_len * SR)
    out = buf[:n].copy()
    tail = buf[n:]
    out[: len(tail)] += tail[:n]
    return out


CHORDS = {  # name -> (bass midi, chord tones around middle C)
    "Dm": (38, [62, 65, 69]), "Bb": (34, [62, 65, 70]), "C": (36, [60, 64, 67]), "A": (33, [61, 64, 69]),
    "Gm": (31, [62, 67, 70]), "F": (29, [60, 65, 69]), "Am": (33, [60, 64, 69]),
    "D": (38, [62, 66, 69]), "G": (31, [62, 67, 71]), "Bm": (35, [62, 66, 71]), "A7": (33, [61, 64, 67]), "Em": (28, [59, 64, 67]),
}


def battle_theme():
    """The battle loop: D minor, 138 bpm, 16 bars. Driving bass, drums, strings, an arpeggio and a brass lead."""
    bpm = 138.0
    beat = 60.0 / bpm
    bar = beat * 4
    prog = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Bb", "A", "Gm", "Gm", "Dm", "Dm", "Bb", "C", "A", "A"]
    total = bar * len(prog)
    buf = np.zeros(int((total + 3.0) * SR))
    # melody: (beat within the 16 bars, midi, length in beats). Two 8-bar phrases: a call and a climb.
    mel = [
        (0, 74, 1.5), (1.5, 72, 0.5), (2, 69, 1), (3, 65, 1), (4, 69, 2.5), (6.5, 67, 0.5), (7, 69, 1),
        (8, 70, 1.5), (9.5, 69, 0.5), (10, 65, 1), (11, 62, 1), (12, 64, 1.5), (13.5, 67, 0.5), (14, 72, 2),
        (16, 74, 1.5), (17.5, 72, 0.5), (18, 69, 1), (19, 74, 1), (20, 77, 2.5), (22.5, 76, 0.5), (23, 74, 1),
        (24, 70, 1), (25, 74, 1), (26, 77, 1), (27, 74, 1), (28, 73, 3), (31, 69, 1),
        (32, 70, 1.5), (33.5, 74, 0.5), (34, 79, 2), (36, 77, 1), (37, 74, 1), (38, 70, 2),
        (40, 69, 1.5), (41.5, 74, 0.5), (42, 77, 2), (44, 76, 1), (45, 74, 1), (46, 69, 2),
        (48, 70, 1), (49, 74, 1), (50, 77, 1), (51, 82, 1), (52, 79, 1.5), (53.5, 76, 0.5), (54, 72, 1), (55, 76, 1),
        (56, 76, 1.5), (57.5, 73, 0.5), (58, 69, 1), (59, 73, 1), (60, 76, 2), (62, 73, 1), (63, 69, 1),
    ]
    for at, n_, ln in mel:
        place(buf, brass(n_, ln * beat * 0.95) * 0.42, at * beat)
        place(buf, brass(n_ - 12, ln * beat * 0.95, False) * 0.14, at * beat)
    for b, name in enumerate(prog):
        root, tones = CHORDS[name]
        t0 = b * bar
        place(buf, strings(tones + [tones[0] + 12], bar * 1.02, 1700 if b < 8 else 2400) * 0.5, t0)
        for e in range(8):  # eighth-note bass: root, with the octave on the off-beats of beat 2 and 4
            n_ = root + (12 if e in (3, 7) else 0)
            place(buf, bass_note(n_, beat * 0.46) * 0.17, t0 + e * beat / 2)
        arp = [tones[0], tones[1], tones[2], tones[1] + 12, tones[2], tones[1], tones[0] + 12, tones[2]]
        for s in range(16):
            place(buf, pluck(arp[s % 8] + 12, 0.16, 2600 if b < 8 else 3600) * (0.16 if s % 2 else 0.21), t0 + s * beat / 4)
        for q in range(4):
            place(buf, kick() * 0.3, t0 + q * beat)
            if q in (1, 3):
                place(buf, snare() * 0.42, t0 + q * beat)
        place(buf, kick() * 0.2, t0 + 2.5 * beat)
        for e in range(8):
            place(buf, hat(e == 7 and b % 4 == 3) * (0.2 if e % 2 else 0.12), t0 + e * beat / 2)
        if b % 8 == 7:  # a tom fill into the next phrase
            for i, f in enumerate([150, 130, 110, 90]):
                place(buf, tom(f) * 0.25, t0 + (3 + i * 0.25) * beat)
    wet = reverb(buf, 1.4, 0.16, 3000)
    out = loop_fold(wet, total)
    return norm(soft(out * 1.25, 1.2), 0.8)


def victory_fanfare():
    """Brass fanfare in D major, about six seconds, ending on a held chord that rings out."""
    beat = 60.0 / 126.0
    buf = np.zeros(int(8.0 * SR))
    line = [(0, 74, 0.33), (0.33, 74, 0.33), (0.67, 74, 0.33), (1, 78, 1), (2, 76, 0.67), (2.67, 78, 0.33), (3, 81, 1.5),
            (4.5, 79, 0.5), (5, 78, 0.5), (5.5, 79, 0.5), (6, 81, 0.67), (6.67, 83, 0.33), (7, 86, 4.5)]
    for at, n_, ln in line:
        place(buf, brass(n_, ln * beat * 0.96) * 0.45, at * beat)
        place(buf, brass(n_ - 5 if n_ != 86 else 81, ln * beat * 0.96) * 0.16, at * beat)
        place(buf, brass(n_ - 12, ln * beat * 0.96, False) * 0.12, at * beat)
    for at, name, ln in [(0, "D", 2), (2, "A", 1), (3, "D", 2), (5, "G", 1), (6, "A", 1), (7, "D", 4.5)]:
        root, tones = CHORDS[name]
        place(buf, strings(tones + [tones[0] + 12], ln * beat * 1.02, 2400) * 0.34, at * beat)
        place(buf, bass_note(root, ln * beat * 0.98) * 0.16, at * beat)
    for at in [0, 0.33, 0.67, 1, 3, 7]:
        place(buf, kick() * 0.3, at * beat)
    for at in [0, 0.33, 0.67, 2, 2.67, 6, 6.33, 6.67]:
        place(buf, snare() * 0.3, at * beat)
    place(buf, mix(hat(True) * 0.25, clang([2093, 3136, 4186], 1.2, 0.4) * 0.12), 7 * beat)
    out = reverb(buf, 1.6, 0.22, 3500)
    n = int(7.6 * SR)
    out = out[:n]
    out[-int(1.2 * SR):] *= np.linspace(1, 0, int(1.2 * SR))
    return norm(soft(out * 1.3, 1.2), 0.85)


def results_loop():
    """A calm loop under the results screen: D major, 84 bpm, 8 bars of warm strings, harp-like plucks and a soft bass."""
    beat = 60.0 / 84.0
    bar = beat * 4
    prog = ["D", "Bm", "G", "A", "D", "Bm", "Em", "A7"]
    total = bar * len(prog)
    buf = np.zeros(int((total + 3.0) * SR))
    for b, name in enumerate(prog):
        root, tones = CHORDS[name]
        t0 = b * bar
        place(buf, strings(tones, bar * 1.05, 1300) * 0.3, t0)
        place(buf, bass_note(root + 12, bar * 0.9) * 0.1, t0)
        arp = [tones[0], tones[1], tones[2], tones[0] + 12, tones[1] + 12, tones[2], tones[0] + 12, tones[1]]
        for s in range(8):
            place(buf, pluck(arp[s] + 12, 0.5, 2200) * 0.13, t0 + s * beat / 2)
    mel = [(0, 81, 2), (2, 78, 2), (4, 78, 1.5), (5.5, 74, 2.5), (8, 79, 2), (10, 83, 2), (12, 81, 3),
           (16, 86, 2), (18, 81, 2), (20, 78, 3), (24, 79, 1.5), (25.5, 76, 2.5), (28, 76, 2), (30, 73, 2)]
    for at, n_, ln in mel:
        place(buf, bell(n_, ln * beat, ln * beat / 3) * 0.1, at * beat)
    out = loop_fold(reverb(buf, 1.8, 0.28, 2600), total)
    return norm(out, 0.6)


def defeat_sting():
    """Low strings falling in D minor, a slow heartbeat of a drum, about five seconds."""
    buf = np.zeros(int(7.0 * SR))
    for at, tones, ln in [(0, [50, 57, 62, 65], 1.6), (1.5, [48, 55, 60, 63], 1.6), (3.0, [46, 53, 58, 62], 1.4), (4.2, [45, 52, 57, 61], 2.4)]:
        place(buf, strings(tones, ln, 900) * 0.4, at)
        place(buf, bass_note(tones[0] - 12, ln * 0.95) * 0.35, at)
    for at, n_, ln in [(0.1, 69, 1.3), (1.5, 67, 1.3), (3.0, 65, 1.1), (4.2, 64, 2.2)]:
        place(buf, brass(n_, ln, True) * 0.12, at)
    for at in [0, 1.5, 3.0, 4.2]:
        place(buf, thud(90, 34, 0.5, 0.14) * 0.5, at)
    out = reverb(buf, 2.0, 0.3, 1500)[: int(6.6 * SR)]
    out[-int(1.5 * SR):] *= np.linspace(1, 0, int(1.5 * SR))
    return norm(out, 0.7)


MUSIC = {"battle_theme": battle_theme, "victory_fanfare": victory_fanfare, "results_loop": results_loop, "defeat_sting": defeat_sting}


# ---------- output ----------

def write_ogg(path, x, quality):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        name = tmp.name
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", name, "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    finally:
        os.unlink(name)


def main():
    only = set(sys.argv[1:])
    for sub, table, q in [("sfx", SFX, 5), ("music", MUSIC, 4)]:
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
        for name, make in table.items():
            if only and name not in only:
                continue
            x = make()
            path = os.path.join(OUT, sub, name + ".ogg")
            write_ogg(path, x, q)
            print("%-18s %5.2f s  %6.1f KB" % (name, len(x) / SR, os.path.getsize(path) / 1024))


if __name__ == "__main__":
    main()
