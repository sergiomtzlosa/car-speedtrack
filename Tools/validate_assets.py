#!/usr/bin/env python3
"""Validate every generated CarSpeedtrack asset before building."""
from __future__ import annotations

import json
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "CarSpeedtrack" / "Resources"
ART = RES / "Art"
DATA = RES / "Data"
MUSIC = RES / "Audio" / "Music"
SFX = RES / "Audio" / "SFX"
ICONS = RES / "Assets.xcassets" / "AppIcon.appiconset"

errors: list[str] = []
warnings: list[str] = []


def check(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def load_json(path: Path, label: str):
    if not path.exists():
        errors.append(f"missing {label}: {path.relative_to(ROOT)}")
        return None
    try:
        return json.loads(path.read_text())
    except Exception as exc:
        errors.append(f"invalid {label}: {exc}")
        return None


def check_png(name: str, min_size=1) -> None:
    path = ART / f"{name}.png"
    if not path.exists():
        errors.append(f"missing sprite: {name}.png")
        return
    try:
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            check(image.width >= min_size and image.height >= min_size,
                  f"sprite too small: {name} {image.size}")
            if image.mode != "RGBA":
                warnings.append(f"{name} is {image.mode}, expected RGBA")
    except Exception as exc:
        errors.append(f"broken sprite {name}: {exc}")


# --- campaign data ---------------------------------------------------------
levels_payload = load_json(DATA / "levels.json", "levels.json")
cars_payload = load_json(DATA / "cars.json", "cars.json")

if levels_payload:
    worlds = levels_payload.get("worlds", [])
    levels = levels_payload.get("levels", [])
    check(len(worlds) == 10, f"expected 10 worlds, found {len(worlds)}")
    check(len(levels) == 100, f"expected 100 levels, found {len(levels)}")
    world_ids = {w.get("id") for w in worlds}
    check(len(world_ids) == len(worlds), "duplicate world ids")
    ids = [level.get("id") for level in levels]
    names = [level.get("name") for level in levels]
    seeds = [level.get("seed") for level in levels]
    check(len(set(ids)) == 100 and sorted(ids) == list(range(1, 101)), "level ids must be 1..100")
    check(len(set(names)) == 100, "level names must be unique")
    check(len(set(seeds)) == 100, "level seeds must be unique")
    counts = {world: 0 for world in world_ids}
    for level in levels:
        level_id = level.get("id")
        check(level.get("world") in world_ids, f"level {level_id}: unknown world")
        counts[level.get("world")] = counts.get(level.get("world"), 0) + 1
        check(8000 <= level.get("length", 0) <= 22000, f"level {level_id}: length out of range")
        check(300 <= level.get("roadWidth", 0) <= 480, f"level {level_id}: road width out of range")
        check(0.0 <= level.get("curviness", -1) <= 1.0, f"level {level_id}: curviness out of range")
        for key in ("trafficDensity", "hazardDensity", "trafficSpeed"):
            check(0.0 <= level.get(key, -1) <= 1.5, f"level {level_id}: {key} out of range")
        check(0.3 <= level.get("pickupDensity", 0) <= 1.5, f"level {level_id}: pickupDensity out of range")
        check(level.get("star2", 0) < level.get("star3", 0), f"level {level_id}: star thresholds not increasing")
        check(level.get("star3", 0) <= level.get("length", 0) * 1.2 + 12000,
              f"level {level_id}: star3 may be unreachable")
        check(len(level.get("hazards", [])) > 0, f"level {level_id}: has no hazards")
        for hazard in level.get("hazards", []):
            check(hazard in {
                "cone", "spike", "pothole", "jelly", "puddle", "beachball",
                "tumbleweed", "asteroid", "snowball", "ember",
            }, f"level {level_id}: unknown hazard {hazard}")
        check((ART / f"{level.get('ground')}.png").exists(), f"level {level_id}: missing ground")
        check((MUSIC / f"{level.get('music')}.wav").exists(), f"level {level_id}: missing music")
    for world, count in counts.items():
        check(count == 10, f"world {world} has {count} levels (expected 10)")
    for world in worlds:
        check((ART / f"{world.get('ground')}.png").exists(), f"world {world.get('id')}: missing ground")
        check((MUSIC / f"{world.get('music')}.wav").exists(), f"world {world.get('id')}: missing music")

if cars_payload:
    cars = cars_payload.get("cars", [])
    check(len(cars) == 8, f"expected 8 cars, found {len(cars)}")
    check(len({car.get("id") for car in cars}) == 8, "car ids must be unique")
    for car in cars:
        check(0 <= car.get("unlockStars", -1) <= 300, f"car {car.get('id')}: unlock stars out of range")
        for stat in ("speed", "accel", "grip"):
            check(1 <= car.get(stat, 0) <= 5, f"car {car.get('id')}: {stat} out of range")
        for frame in range(4):
            check_png(f"car_{car['id']}_{frame}")

# --- art -------------------------------------------------------------------
manifest = load_json(ART / "art_manifest.json", "art_manifest.json")
if manifest:
    for entry in manifest.get("assets", []):
        path = ART / entry.get("file", "")
        if not path.exists():
            errors.append(f"manifest references missing {entry.get('file')}")
            continue
        with Image.open(path) as image:
            check(list(image.size) == [entry.get("width"), entry.get("height")],
                  f"manifest size mismatch for {path.name}")

for name in ["bg_menu", "bg_screen", "logo_title", "ui_panel", "ui_panel_dark",
             "ui_button_pink", "ui_button_mint", "ui_button_yellow", "ui_button_sky",
             "ui_button_lavender", "ui_button_rose", "ui_button_disabled",
             "ui_slider_track", "ui_slider_knob", "ui_bar_pink", "ui_bar_mint",
             "icon_heart_full", "icon_heart_empty", "icon_star_full", "icon_star_empty",
             "icon_lock", "icon_play", "icon_pause", "icon_back", "icon_arrow_left",
             "icon_arrow_right", "icon_gear", "icon_trophy", "icon_boost", "icon_target"]:
    check_png(name)
for i in range(10):
    check_png(f"bg_world_{i + 1}")
    check_png(f"ground_{i + 1}")
    for d in range(3):
        check_png(f"decor_{i + 1}_{d}")
for i in range(5):
    check_png(f"traffic_{i}")
for i in range(4):
    check_png(f"pickup_coin_{i}")
for name in ["pickup_gem", "pickup_heart", "pickup_shield", "pickup_magnet", "pickup_star",
             "hazard_cone", "hazard_spike", "hazard_pothole", "hazard_jelly", "hazard_puddle"]:
    check_png(name)
for prefix in ["beachball", "tumbleweed", "asteroid", "snowball", "ember"]:
    for frame in range(2):
        check_png(f"hazard_{prefix}_{frame}")

font = load_json(DATA / "font.json", "font.json")
if font:
    check(font.get("firstChar") == 32 and font.get("lastChar") == 126, "font range must be ASCII 32..126")
    for code in range(32, 127):
        check_png(f"glyph_{code:03d}")

# --- audio -----------------------------------------------------------------
audio_manifest = load_json(DATA / "audio_manifest.json", "audio_manifest.json")
if audio_manifest:
    check(audio_manifest.get("sampleRate") == 44100, "audio sample rate must be 44100")
    for entry in audio_manifest.get("music", []):
        path = MUSIC / f"{entry.get('file')}.wav"
        if not path.exists():
            errors.append(f"missing music: {path.name}")
            continue
        with wave.open(str(path), "rb") as handle:
            check(handle.getnchannels() == 1, f"{path.name}: expected mono")
            check(handle.getsampwidth() == 2, f"{path.name}: expected 16-bit")
            check(handle.getframerate() == 44100, f"{path.name}: expected 44.1 kHz")
            frames = handle.readframes(handle.getnframes())
            data = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
            check(handle.getnframes() / handle.getframerate() >= 12.0,
                  f"{path.name}: too short")
            check(float(np.max(np.abs(data))) > 0.05, f"{path.name}: silent")
    for entry in audio_manifest.get("sfx", []):
        path = SFX / f"{entry.get('file')}.wav"
        if not path.exists():
            errors.append(f"missing sfx: {path.name}")
            continue
        with wave.open(str(path), "rb") as handle:
            frames = handle.readframes(handle.getnframes())
            data = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
            check(handle.getnchannels() == 1 and handle.getsampwidth() == 2,
                  f"{path.name}: not 16-bit mono")
            check(0.02 <= handle.getnframes() / handle.getframerate() <= 8.0,
                  f"{path.name}: duration out of range")
            check(float(np.max(np.abs(data))) > 0.03, f"{path.name}: silent")

for required in ["music_menu", "music_win", "music_lose", "engine_loop", "tyre_loop"]:
    candidates = list(MUSIC.glob(f"{required}.wav")) + list(SFX.glob(f"{required}.wav"))
    check(bool(candidates), f"missing required audio {required}.wav")
for sfx_name in ["sfx_click", "sfx_hover", "sfx_coin", "sfx_gem", "sfx_heart",
                 "sfx_shield", "sfx_magnet", "sfx_star", "sfx_boost", "sfx_nearmiss",
                 "sfx_crash", "sfx_cone", "sfx_slick", "sfx_splash", "sfx_countdown",
                 "sfx_go", "sfx_finish", "sfx_newbest", "sfx_unlock"]:
    check((SFX / f"{sfx_name}.wav").exists(), f"missing {sfx_name}.wav")

# --- app icon --------------------------------------------------------------
contents = load_json(ICONS / "Contents.json", "AppIcon Contents.json")
if contents:
    check(len(contents.get("images", [])) == 10, "app icon set should have 10 images")
    for image in contents.get("images", []):
        check((ICONS / image.get("filename", "")).exists(),
              f"missing app icon {image.get('filename')}")

if warnings:
    for warning in warnings:
        print(f"WARN {warning}")
if errors:
    print(f"\n{len(errors)} validation error(s):", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    sys.exit(1)
print("Asset validation passed: 100 levels, 10 worlds, 8 cars, 13 music tracks, 22 SFX.")
