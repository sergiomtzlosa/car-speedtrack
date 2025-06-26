#!/usr/bin/env python3
"""Generate CarSpeedtrack's chiptune soundtrack and sound effects.

Everything is synthesised from oscillators and noise with numpy; no samples or
external audio are used. Music loops are rendered to exact bar lengths so they
can be looped by AVAudioPlayer without a rhythmic hiccup. A short de-click fade
is applied at both ends of every file.

Usage:
    python3 Tools/generate_music.py             # generate everything
    python3 Tools/generate_music.py --track menu
    python3 Tools/generate_music.py --preview   # generate and play menu loop
"""
from __future__ import annotations

import argparse
import json
import math
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "CarSpeedtrack" / "Resources" / "Audio"
MUSIC_DIR = AUDIO / "Music"
SFX_DIR = AUDIO / "SFX"
DATA = ROOT / "CarSpeedtrack" / "Resources" / "Data"
SR = 44100

rng = np.random.default_rng(0xC0FFEE)


# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

def t_axis(duration: float) -> np.ndarray:
    return np.arange(max(1, int(duration * SR)), dtype=np.float64) / SR


def midi_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def adsr(n: int, attack=0.008, decay=0.05, sustain=0.72, release=0.10) -> np.ndarray:
    """A stable ADSR envelope that never exceeds 1.0."""
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    s = max(1, n - a - d - r)
    env = np.concatenate([
        np.linspace(0.0, 1.0, a, endpoint=False),
        np.linspace(1.0, sustain, d, endpoint=False),
        np.full(s, sustain),
        np.linspace(sustain, 0.0, r),
    ])
    if env.size < n:
        env = np.pad(env, (0, n - env.size))
    return env[:n]


def oscillator(shape: str, freq: float, duration: float, duty=0.5,
               vibrato=0.0, glide=0.0) -> np.ndarray:
    t = t_axis(duration)
    if vibrato:
        phase_mod = np.sin(2.0 * math.pi * 5.2 * t) * vibrato * t
    else:
        phase_mod = 0.0
    f = freq * (1.0 + glide * t)
    phase = np.cumsum(f) / SR + phase_mod
    frac = phase - np.floor(phase)
    if shape == "sine":
        wave_data = np.sin(2.0 * math.pi * frac)
    elif shape == "triangle":
        wave_data = 1.0 - 4.0 * np.abs(frac - 0.5)
    elif shape == "saw":
        wave_data = 2.0 * frac - 1.0
    elif shape == "organ":
        wave_data = 0.65 * np.sin(2.0 * math.pi * frac) + 0.35 * np.sin(4.0 * math.pi * frac)
    else:  # pulse
        wave_data = np.where(frac < duty, 1.0, -1.0)
    return wave_data


def noise_burst(duration: float, smoothing=0.0) -> np.ndarray:
    n = max(1, int(duration * SR))
    data = rng.uniform(-1.0, 1.0, n)
    if smoothing > 0:
        kernel = np.exp(-np.arange(0, int(smoothing * SR)) / max(1.0, smoothing * SR * 0.35))
        kernel /= kernel.sum()
        data = np.convolve(data, kernel, mode="same")
    return data


def add_note(buffer: np.ndarray, start: float, note: float, duration: float,
             amp: float, shape="pulse", duty=0.5, attack=0.006,
             release=0.06, sustain=0.65, vibrato=0.0, glide=0.0) -> None:
    if start >= len(buffer) / SR or amp <= 0.0:
        return
    n = max(1, int(duration * SR))
    data = oscillator(shape, midi_hz(note), duration, duty, vibrato, glide)
    data *= adsr(n, attack, min(0.08, duration * 0.18), sustain, release)
    data *= amp
    begin = int(start * SR)
    end = min(len(buffer), begin + len(data))
    if end <= begin:
        return
    buffer[begin:end] += data[: end - begin]


def add_kick(buffer: np.ndarray, start: float, amp=0.4) -> None:
    if start >= len(buffer) / SR:
        return
    dur = 0.16
    t = t_axis(dur)
    freq = 128.0 * np.exp(-t * 22.0) + 42.0
    data = np.sin(2.0 * math.pi * np.cumsum(freq) / SR)
    data *= np.exp(-t * 17.0)
    begin = int(start * SR)
    end = min(len(buffer), begin + len(data))
    buffer[begin:end] += data[: end - begin] * amp


def add_snare(buffer: np.ndarray, start: float, amp=0.25) -> None:
    if start >= len(buffer) / SR:
        return
    dur = 0.14
    t = t_axis(dur)
    data = noise_burst(dur, 0.006) * np.exp(-t * 24.0)
    data += np.sin(2.0 * math.pi * 180.0 * t) * np.exp(-t * 30.0) * 0.35
    begin = int(start * SR)
    end = min(len(buffer), begin + len(data))
    buffer[begin:end] += data[: end - begin] * amp


def add_hat(buffer: np.ndarray, start: float, amp=0.06) -> None:
    if start >= len(buffer) / SR:
        return
    dur = 0.045
    t = t_axis(dur)
    data = noise_burst(dur, 0.0015) * np.exp(-t * 60.0)
    begin = int(start * SR)
    end = min(len(buffer), begin + len(data))
    buffer[begin:end] += data[: end - begin] * amp


def write_wav(path: Path, samples: np.ndarray, peak=0.88) -> None:
    samples = np.nan_to_num(samples.astype(np.float64), nan=0.0, posinf=0.0, neginf=0.0)
    high = float(np.max(np.abs(samples)))
    if high > 1e-8:
        samples = samples / high * peak
    # Each file gets a tiny fade to guarantee a click-free start and end.
    fade = min(len(samples) // 2, int(0.008 * SR))
    if fade > 1:
        ramp = np.linspace(0.0, 1.0, fade)
        samples[:fade] *= ramp
        samples[-fade:] *= ramp[::-1]
    pcm = np.clip(samples * 32767.0, -32768, 32767).astype('<i2')
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

SCALE_MAJOR = [0, 2, 4, 5, 7, 9, 11]

TRACKS = [
    dict(file="music_menu", title="Sunny Start", bpm=112, root=60,
         progression=[0, 3, 4, 0, 5, 3, 4, 0], seed=1, melody_shape="pulse",
         pad_shape="organ", pattern="bouncy"),
    dict(file="music_world_1", title="Meadow Cruise", bpm=112, root=60,
         progression=[0, 4, 5, 3], seed=11, melody_shape="pulse",
         pad_shape="triangle", pattern="bouncy"),
    dict(file="music_world_2", title="Candy Coast", bpm=120, root=65,
         progression=[0, 3, 4, 3, 5, 3, 4, 0], seed=22, melody_shape="pulse",
         pad_shape="organ", pattern="beach"),
    dict(file="music_world_3", title="Citrus Canyon", bpm=116, root=67,
         progression=[0, 5, 3, 4], seed=33, melody_shape="triangle",
         pad_shape="organ", pattern="gallop"),
    dict(file="music_world_4", title="Bubblegum City", bpm=124, root=69,
         progression=[0, 4, 5, 3, 0, 4, 3, 4], seed=44, melody_shape="pulse",
         pad_shape="triangle", pattern="city"),
    dict(file="music_world_5", title="Rainbow Ridge", bpm=122, root=62,
         progression=[0, 3, 5, 4], seed=55, melody_shape="sine",
         pad_shape="organ", pattern="bouncy"),
    dict(file="music_world_6", title="Tropic Tides", bpm=118, root=70,
         progression=[0, 3, 4, 5, 3, 4, 0, 4], seed=66, melody_shape="triangle",
         pad_shape="sine", pattern="beach"),
    dict(file="music_world_7", title="Starfruit Space", bpm=126, root=64,
         progression=[0, 5, 3, 4, 0, 3, 5, 4], seed=77, melody_shape="pulse",
         pad_shape="organ", pattern="space"),
    dict(file="music_world_8", title="Frosty Peaks", bpm=110, root=63,
         progression=[0, 4, 5, 3], seed=88, melody_shape="sine",
         pad_shape="triangle", pattern="gentle"),
    dict(file="music_world_9", title="Marshmallow Volcano", bpm=128, root=65,
         progression=[0, 3, 4, 0, 5, 4, 3, 4], seed=99, melody_shape="organ",
         pad_shape="organ", pattern="fiery"),
    dict(file="music_world_10", title="Aurora Finale", bpm=132, root=60,
         progression=[0, 4, 5, 3, 0, 5, 3, 4], seed=111, melody_shape="pulse",
         pad_shape="organ", pattern="space"),
    dict(file="music_win", title="Confetti Finish", bpm=126, root=60,
         progression=[0, 4, 5, 0], seed=222, melody_shape="pulse",
         pad_shape="organ", pattern="win", bars=8, one_shot=True),
    dict(file="music_lose", title="Try Again", bpm=88, root=57,
         progression=[0, 5, 3, 4], seed=333, melody_shape="triangle",
         pad_shape="sine", pattern="lose", bars=8, one_shot=True),
]

CHORD_STEPS = {
    0: [0, 4, 7], 1: [2, 5, 9], 2: [4, 7, 11], 3: [5, 9, 12],
    4: [7, 11, 14], 5: [9, 12, 16], 6: [11, 14, 17],
}


def chord_for(step: int, root: int) -> list[int]:
    return [root + n for n in CHORD_STEPS[step % 7]]


def melody_bar(cfg: dict, bar: int, chords: list[int], state: dict) -> list[tuple]:
    """Return (beat_offset, midi_note, duration_beats) for one bar."""
    rng_local = np.random.default_rng(cfg["seed"] * 977 + bar * 37)
    scale = [cfg["root"] + 12 + s for s in SCALE_MAJOR]
    chord_tones = chords
    notes = []
    beat = 0.0
    # Sparse intro/outro and busier middle section.
    intro = bar < 2
    outro = bar >= cfg.get("bars", 16) - 1
    density = 0.45 if intro else (0.35 if outro else 0.78)
    while beat < 4.0:
        if rng_local.random() > density:
            beat += rng_local.choice([0.5, 1.0])
            continue
        duration = rng_local.choice([0.5, 0.5, 0.5, 1.0])
        duration = min(duration, 4.0 - beat)
        if rng_local.random() < 0.55:
            note = int(rng_local.choice(chord_tones)) + 12
            # Keep chord tones in a singable range.
            while note > cfg["root"] + 32:
                note -= 12
            while note < cfg["root"] + 12:
                note += 12
        else:
            last = state.get("last", cfg["root"] + 19)
            step = int(rng_local.integers(-2, 3))
            idx = min(len(scale) - 1, max(0, min(range(len(scale)),
                  key=lambda i: abs(scale[i] - last)) + step))
            note = scale[idx]
        state["last"] = note
        notes.append((beat, note, duration))
        beat += duration + (0.0 if rng_local.random() < 0.7 else 0.5)
    return notes


def render_music(cfg: dict) -> np.ndarray:
    bars = cfg.get("bars", 16)
    beat = 60.0 / cfg["bpm"]
    bar = beat * 4.0
    duration = bars * bar
    buffer = np.zeros(int(duration * SR) + SR // 4, dtype=np.float64)
    progression = cfg["progression"]
    melody_state: dict = {}

    for b in range(bars):
        start = b * bar
        step = progression[b % len(progression)]
        chords = chord_for(step, cfg["root"])
        intro = b < 2
        outro = b >= bars - 1

        # Warm pad, one chord per bar.
        if not outro:
            for i, note in enumerate(chords):
                add_note(buffer, start, note, bar * 0.95, 0.055,
                         shape=cfg["pad_shape"], duty=0.5, attack=0.04,
                         release=0.25, sustain=0.62)
                add_note(buffer, start, note + 12, bar * 0.9, 0.018,
                         shape="sine", attack=0.06, release=0.3, sustain=0.5)

        # Bass: bouncy root/fifth pattern.
        pattern = cfg["pattern"]
        if pattern == "beach":
            bass_beats = [(0, 0), (1.5, 7), (2, 0), (3.5, 7)]
        elif pattern == "gallop":
            bass_beats = [(0, 0), (0.75, 0), (1.5, 7), (2.5, 0), (3.25, 12)]
        elif pattern == "city":
            bass_beats = [(0, 0), (1, 0), (2, 7), (3, 7)]
        elif pattern == "space":
            bass_beats = [(0, 0), (1, 12), (2, 7), (3, 12)]
        elif pattern == "fiery":
            bass_beats = [(i * 0.5, 0 if i % 4 < 2 else 7) for i in range(8)]
        elif pattern == "win":
            bass_beats = [(i * 0.5, [0, 0, 7, 7, 12, 12, 7, 0][i]) for i in range(8)]
        elif pattern == "lose":
            bass_beats = [(0, 0), (2, 7)]
        else:
            bass_beats = [(0, 0), (1.5, 7), (2, 0), (3, 12)]
        if intro:
            bass_beats = [(0, 0), (2, 7)]
        for offset, semis in bass_beats:
            if start + offset * beat + 0.1 < duration:
                add_note(buffer, start + offset * beat, cfg["root"] - 24 + semis,
                         beat * 0.62, 0.22, shape="triangle", attack=0.006,
                         release=0.05, sustain=0.8)

        # Arpeggio sparkle.
        if not intro:
            arp_notes = (chords + [chords[0] + 12] * 2)[:4]
            for i in range(4):
                if (i + b) % (2 if pattern == "gentle" else 1) == 0:
                    add_note(buffer, start + i * beat, arp_notes[i % len(arp_notes)] + 12,
                             beat * 0.42, 0.045, shape="sine", attack=0.004,
                             release=0.05, sustain=0.45)

        # Melody.
        if not (intro and b % 2 == 1):
            for offset, note, length in melody_bar(cfg, b, chords, melody_state):
                if start + offset * beat + length * beat * 0.5 < duration:
                    add_note(buffer, start + offset * beat, note,
                             length * beat * 0.9, 0.15,
                             shape=cfg["melody_shape"], duty=0.25,
                             attack=0.004, release=0.06, sustain=0.55,
                             vibrato=0.0015 if cfg["melody_shape"] != "pulse" else 0.0)

        # Drums.
        if pattern not in ("lose",):
            for bar_beat in range(4):
                if pattern in ("bouncy", "beach", "city", "fiery", "win"):
                    add_kick(buffer, start + bar_beat * beat, 0.34)
                if bar_beat in (1, 3):
                    add_snare(buffer, start + bar_beat * beat, 0.21)
                if pattern in ("city", "space", "fiery"):
                    add_hat(buffer, start + bar_beat * beat + beat * 0.5, 0.07)
                if pattern in ("bouncy", "beach"):
                    add_hat(buffer, start + bar_beat * beat + beat * 0.5, 0.045)
        elif b >= bars - 2:
            add_kick(buffer, start, 0.26)
            add_snare(buffer, start + 2 * beat, 0.18)

    # Trim to exact loop length (tail overhang is allowed to decay into the
    # buffer only if the track is a one-shot).
    exact = int(duration * SR)
    if cfg.get("one_shot"):
        buffer = buffer[: int((duration + 1.4) * SR)]
    else:
        buffer = buffer[:exact]
        # Fold the final bar's low-level reverb tail back to the start.
        tail = int(0.4 * SR)
        if len(buffer) > tail * 2:
            # Nothing to fold in this simple mix; the fade below prevents clicks.
            pass
    return buffer


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------

def tone_seq(notes, shape="pulse", note_dur=0.08, gap=0.0, amp=0.5,
             glide=0.0, duty=0.5) -> np.ndarray:
    total = note_dur * len(notes) + gap * max(0, len(notes) - 1) + 0.05
    buffer = np.zeros(int(total * SR))
    cursor = 0.0
    for note in notes:
        add_note(buffer, cursor, note, note_dur, amp, shape=shape, duty=duty,
                 attack=0.002, release=0.02, sustain=0.7, glide=glide)
        cursor += note_dur + gap
    return buffer


def sweep(f0, f1, duration, amp=0.5, shape="sine") -> np.ndarray:
    t = t_axis(duration)
    freq = np.linspace(f0, f1, len(t))
    phase = np.cumsum(freq) / SR
    data = np.sin(2.0 * math.pi * phase) if shape == "sine" else np.sign(np.sin(2.0 * math.pi * phase))
    data *= np.exp(-t * (2.8 / duration))
    return data * amp


def noise_sweep(duration, amp=0.4, smoothing=0.005) -> np.ndarray:
    t = t_axis(duration)
    data = noise_burst(duration, smoothing)
    data *= np.exp(-t * (4.0 / duration))
    return data * amp


def build_sfx() -> dict[str, np.ndarray]:
    sfx: dict[str, np.ndarray] = {}
    sfx["sfx_click"] = tone_seq([88, 84], "pulse", 0.035, 0.0, 0.55)
    sfx["sfx_hover"] = tone_seq([93], "sine", 0.025, 0, 0.25)
    sfx["sfx_coin"] = tone_seq([88, 95], "pulse", 0.055, 0.02, 0.42, duty=0.25)
    sfx["sfx_gem"] = tone_seq([84, 88, 91, 96], "sine", 0.055, 0.012, 0.4)
    sfx["sfx_heart"] = tone_seq([72, 76, 79], "triangle", 0.12, 0.03, 0.45)
    sfx["sfx_shield"] = sweep(220, 880, 0.35, 0.36, "sine")
    sfx["sfx_magnet"] = np.concatenate([
        sweep(240, 420, 0.18, 0.28, "sine"),
        sweep(420, 240, 0.18, 0.24, "sine"),
    ])
    sfx["sfx_star"] = np.concatenate([
        tone_seq([84, 88, 91, 96, 100], "pulse", 0.07, 0.004, 0.38, duty=0.25),
        sweep(880, 1760, 0.18, 0.18, "sine"),
    ])
    boost = np.concatenate([noise_sweep(0.55, 0.34, 0.004),
                            sweep(110, 660, 0.55, 0.18, "saw")])
    sfx["sfx_boost"] = boost
    whoosh = noise_sweep(0.28, 0.3, 0.02) * np.linspace(1.0, 0.1, int(0.28 * SR))
    sfx["sfx_nearmiss"] = whoosh
    crash = noise_sweep(0.32, 0.5, 0.003)
    crash[: int(0.14 * SR)] += sweep(140, 48, 0.14, 0.45, "sine")
    sfx["sfx_crash"] = crash
    sfx["sfx_cone"] = np.concatenate([sweep(180, 90, 0.12, 0.32), noise_sweep(0.08, 0.12)])
    slick = np.concatenate([sweep(900, 180, 0.3, 0.28, "sine"),
                            noise_sweep(0.15, 0.12, 0.01)])
    sfx["sfx_slick"] = slick
    sfx["sfx_splash"] = noise_sweep(0.35, 0.35, 0.012)
    sfx["sfx_countdown"] = tone_seq([76], "pulse", 0.12, 0.0, 0.4)
    sfx["sfx_go"] = tone_seq([84, 88], "pulse", 0.13, 0.02, 0.45)
    sfx["sfx_finish"] = np.concatenate([
        tone_seq([72, 76, 79, 84], "pulse", 0.14, 0.02, 0.4, duty=0.25),
        tone_seq([79, 84, 88], "pulse", 0.2, 0.01, 0.35, duty=0.25),
        tone_seq([88], "sine", 0.6, 0.0, 0.3),
    ])
    sfx["sfx_newbest"] = np.concatenate([
        tone_seq([79, 84, 91], "sine", 0.1, 0.02, 0.34),
        tone_seq([96], "sine", 0.5, 0, 0.25),
    ])
    sfx["sfx_unlock"] = np.concatenate([
        tone_seq([72, 76], "triangle", 0.14, 0.02, 0.35),
        tone_seq([79, 84, 88], "triangle", 0.16, 0.02, 0.35),
    ])
    sfx["sfx_purchase"] = tone_seq([84, 91, 96], "pulse", 0.08, 0.01, 0.4, duty=0.25)

    # Engine and tyre loops: integer-cycle hums so they loop without a click.
    seconds = 2.0
    t = t_axis(seconds)
    engine = (0.34 * np.sin(2 * math.pi * 80 * t) +
              0.22 * np.sin(2 * math.pi * 160 * t) +
              0.10 * np.sin(2 * math.pi * 240 * t) +
              0.06 * np.sin(2 * math.pi * 320 * t))
    engine *= 0.8 + 0.2 * np.sin(2 * math.pi * 4 * t)
    engine += noise_burst(seconds, 0.003) * 0.035
    sfx["engine_loop"] = engine
    tyre = noise_burst(seconds, 0.0025) * (0.16 + 0.05 * np.sin(2 * math.pi * 3 * t))
    sfx["tyre_loop"] = tyre
    return sfx


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--track", help="generate one music track by file name")
    parser.add_argument("--sfx", action="store_true", help="generate SFX only")
    parser.add_argument("--preview", action="store_true", help="play the menu loop")
    args = parser.parse_args()

    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    SFX_DIR.mkdir(parents=True, exist_ok=True)

    music_manifest = []
    selected = [t for t in TRACKS if not args.track or t["file"] == args.track]
    if not args.sfx:
        for cfg in selected:
            data = render_music(cfg)
            path = MUSIC_DIR / f"{cfg['file']}.wav"
            write_wav(path, data, 0.86)
            duration = len(data) / SR
            music_manifest.append({
                "file": cfg["file"], "title": cfg["title"], "bpm": cfg["bpm"],
                "root": cfg["root"], "duration": round(duration, 3),
                "loop": not bool(cfg.get("one_shot")),
            })
            print(f"music  {cfg['file']:<20} {duration:5.1f}s  {cfg['bpm']} BPM")

    sfx_manifest = []
    if not args.track:
        for name, data in build_sfx().items():
            # Keep loop levels consistent so volume sliders behave predictably.
            peak = 0.82 if name.endswith("_loop") else 0.9
            path = SFX_DIR / f"{name}.wav"
            write_wav(path, data, peak)
            sfx_manifest.append({"file": name, "duration": round(len(data) / SR, 3),
                                 "loop": name.endswith("_loop")})
            print(f"sfx    {name:<20} {len(data) / SR:5.2f}s")

    if not args.track and not args.sfx:
        existing_music = []
        for cfg in TRACKS:
            candidate = next((m for m in music_manifest if m["file"] == cfg["file"]), None)
            if candidate is None:
                path = MUSIC_DIR / f"{cfg['file']}.wav"
                with wave.open(str(path), "rb") as handle:
                    duration = handle.getnframes() / handle.getframerate()
                candidate = {"file": cfg["file"], "title": cfg["title"], "bpm": cfg["bpm"],
                             "root": cfg["root"], "duration": round(duration, 3),
                             "loop": not bool(cfg.get("one_shot"))}
            existing_music.append(candidate)
        manifest = {
            "sampleRate": SR,
            "channels": 1,
            "music": existing_music,
            "sfx": sfx_manifest,
        }
        (DATA / "audio_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        print(f"Wrote {len(existing_music)} music loops and {len(sfx_manifest)} sound effects")

    if args.preview:
        subprocess.run(["afplay", str(MUSIC_DIR / "music_menu.wav")], check=False)


if __name__ == "__main__":
    main()
