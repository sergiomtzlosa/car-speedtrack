#!/usr/bin/env python3
"""Generate the 100-level campaign and the eight-car catalogue.

The road itself is built procedurally at runtime from each level's seed and
parameters. This script provides the deterministic level metadata, names,
star targets, world themes, and car stats.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "CarSpeedtrack" / "Resources" / "Data"
DATA.mkdir(parents=True, exist_ok=True)

WORLDS = [
    {
        "id": 1, "name": "Sunny Meadows", "accent": "#8EDB78", "music": "music_world_1",
        "mechanic": "warmup",
        "blurb": "Warm sunshine, friendly cones, and a first taste of the open road.",
        "hazards": ["cone", "pothole"],
        "names": ["First Gear", "Buttercup Bend", "Picnic Run", "Daisy Dash", "Honeybee Hop",
                  "Meadow Sway", "Clover Cruise", "Sunny Sprint", "Breeze Boulevard", "Meadow Finale"],
    },
    {
        "id": 2, "name": "Candy Coast", "accent": "#FF9FC6", "music": "music_world_2",
        "mechanic": "slick",
        "blurb": "Bubblegum beaches, jelly slicks, and beach balls with a mind of their own.",
        "hazards": ["cone", "jelly", "beachball"],
        "names": ["Gumdrop Getaway", "Taffy Turn", "Sundae Drive", "Sherbet Shores", "Bubblegum Bay",
                  "Lollipop Loop", "Marshmallow Marina", "Jellybean Jaunt", "Sugar Sand Sprint", "Candy Coast Finale"],
    },
    {
        "id": 3, "name": "Citrus Canyon", "accent": "#F7A85C", "music": "music_world_3",
        "mechanic": "crosswind",
        "blurb": "Zesty canyon gusts, tumbling weeds, and sun-baked switchbacks.",
        "hazards": ["cone", "tumbleweed", "pothole"],
        "names": ["Orange You Fast", "Tangerine Twist", "Cactus Canyon", "Lemon Drop Lane", "Sunset Salsa",
                  "Grapefruit Gulch", "Citrus Circuit", "Prickly Pear Pass", "Zesty Zigzag", "Canyon Finale"],
    },
    {
        "id": 4, "name": "Bubblegum City", "accent": "#6FD8D2", "music": "music_world_4",
        "mechanic": "traffic",
        "blurb": "Neon lights, busy lanes, and taxis that apparently have somewhere to be.",
        "hazards": ["cone", "pothole", "spike"],
        "names": ["Neon Welcome", "Taxi Tango", "Skyline Shuffle", "Bubble Boulevard", "Downtown Dash",
                  "Plaza Parade", "Metro Merge", "Rooftop Run", "Confetti Crossing", "City Finale"],
    },
    {
        "id": 5, "name": "Rainbow Ridge", "accent": "#C5A4FF", "music": "music_world_5",
        "mechanic": "crosswind",
        "blurb": "Pastel peaks and strong breezes. Hold the wheel and enjoy the view.",
        "hazards": ["cone", "spike", "tumbleweed"],
        "names": ["Over The Rainbow", "Puffy Cloud Pass", "Lavender Loop", "Sunbeam Summit", "Candy Floss Curve",
                  "Breezy Ridge", "Prism Path", "Pastel Peak", "Starlight Slope", "Ridge Finale"],
    },
    {
        "id": 6, "name": "Tropic Tides", "accent": "#69D7E8", "music": "music_world_6",
        "mechanic": "waves",
        "blurb": "Turquoise water, rolling waves, and a boardwalk made of seashells.",
        "hazards": ["puddle", "beachball", "jelly"],
        "names": ["Seashell Start", "Turquoise Tube", "Palm Breeze", "Wave Rider", "Coral Cove",
                  "Tiki Turn", "Lagoon Loop", "Splash Street", "Mermaid Mile", "Tropic Finale"],
    },
    {
        "id": 7, "name": "Starfruit Space", "accent": "#B790FF", "music": "music_world_7",
        "mechanic": "lowgrip",
        "blurb": "Moon-dust drifting, friendly planets, and a whole lot of stars.",
        "hazards": ["asteroid", "pothole"],
        "names": ["Lift Off!", "Comet Cruise", "Moon Dust", "Asteroid Alley", "Star Fruit Sprint",
                  "Galaxy Groove", "Nebula Nine", "Cosmic Curve", "Rocket Road", "Starfruit Finale"],
    },
    {
        "id": 8, "name": "Frosty Peaks", "accent": "#BFEFFF", "music": "music_world_8",
        "mechanic": "ice",
        "blurb": "Mittens on, everyone. Snowballs bounce and the road has other plans.",
        "hazards": ["snowball", "pothole", "cone"],
        "names": ["Snowflake Start", "Mittens Mile", "Frosty Bend", "Snowball Scramble", "Polar Pass",
                  "Cocoa Curve", "Icicle Avenue", "Penguin Parade", "Glacier Glide", "Frosty Finale"],
    },
    {
        "id": 9, "name": "Marshmallow Volcano", "accent": "#FFB18F", "music": "music_world_9",
        "mechanic": "bounce",
        "blurb": "A warm, gooey volcano that somehow smells like toasted marshmallows.",
        "hazards": ["ember", "jelly", "pothole"],
        "names": ["Mallow March", "Toasty Turn", "Cocoa Canyon", "Flamingo Flow", "Smore Sprint",
                  "Ember Avenue", "Warm Fuzzies", "Lava Lamp Lane", "Campfire Cruise", "Mallow Finale"],
    },
    {
        "id": 10, "name": "Aurora Finale", "accent": "#8BE8C8", "music": "music_world_10",
        "mechanic": "aurora",
        "blurb": "Under the dancing lights, every trick you have learned comes together.",
        "hazards": ["cone", "spike", "pothole", "jelly", "beachball", "tumbleweed", "asteroid", "snowball", "ember"],
        "names": ["Northern Lights", "Shooting Star", "Aurora Avenue", "Twilight Tango", "Starlit Sprint",
                  "Galaxy Gateway", "Rainbow Comet", "Night Bloom", "Skybound", "CarSpeedtrack Forever"],
    },
]

CARS = [
    {"id": "sunny-bug", "name": "Sunny Bug", "speed": 3, "accel": 3, "grip": 3,
     "unlockStars": 0, "tagline": "A cheerful all-rounder for every road."},
    {"id": "mint-mini", "name": "Mint Mini", "speed": 2, "accel": 4, "grip": 5,
     "unlockStars": 20, "tagline": "Tiny, tidy, and impossible to fluster."},
    {"id": "coral-cruiser", "name": "Coral Cruiser", "speed": 4, "accel": 2, "grip": 4,
     "unlockStars": 50, "tagline": "A relaxed cruiser with a surprisingly big heart."},
    {"id": "tangerine-turbo", "name": "Tangerine Turbo", "speed": 5, "accel": 3, "grip": 2,
     "unlockStars": 80, "tagline": "Fast, loud, and always first to the picnic."},
    {"id": "berry-bolt", "name": "Berry Bolt", "speed": 3, "accel": 5, "grip": 3,
     "unlockStars": 120, "tagline": "Zippy starts and sweet corner exits."},
    {"id": "lemon-lightning", "name": "Lemon Lightning", "speed": 5, "accel": 4, "grip": 1,
     "unlockStars": 160, "tagline": "A dragster with absolutely no chill."},
    {"id": "aqua-ace", "name": "Aqua Ace", "speed": 3, "accel": 3, "grip": 5,
     "unlockStars": 200, "tagline": "Glued to the road, even when the road is ice."},
    {"id": "rainbow-rocket", "name": "Rainbow Rocket", "speed": 5, "accel": 4, "grip": 5,
     "unlockStars": 250, "tagline": "The final car. The final confetti. The final lap."},
]


def stable_seed(level_id: int) -> int:
    """A deterministic 48-bit seed that differs for every level."""
    x = (0xC0FFEE + level_id * 0x9E3779B1) & ((1 << 64) - 1)
    x ^= x >> 33
    x = (x * 0xFF51AFD7ED558CCD) & ((1 << 64) - 1)
    x ^= x >> 33
    x = (x * 0xC4CEB9FE1A85EC53) & ((1 << 64) - 1)
    x ^= x >> 33
    return 1 + (x % ((1 << 48) - 1))


def build_levels():
    levels = []
    seen_names = set()
    seen_seeds = set()
    for i in range(100):
        world = WORLDS[i // 10]
        within = i % 10
        t = i / 99.0
        name = world["names"][within]
        seed = stable_seed(i + 1)
        assert seed not in seen_seeds
        seen_seeds.add(seed)
        assert name not in seen_names
        seen_names.add(name)
        length = int(8600 + t * 9400 + (within == 9) * 900)
        curviness = round(0.18 + t * 0.62 + (0.05 if within in (4, 9) else 0), 3)
        road_width = int(round(428 - t * 44))
        # A smooth ramp; world finales are slightly busier.
        traffic = round(min(1.35, 0.28 + t * 0.62 + (0.08 if within >= 7 else 0)), 3)
        hazards = round(min(1.35, 0.25 + t * 0.60 + (0.10 if within >= 8 else 0)), 3)
        pickups = round(max(0.55, 1.05 - t * 0.18), 3)
        traffic_speed = round(0.34 + t * 0.22, 3)
        # Projected score thresholds. Tuned later against real runs.
        star2 = int(round(length * 0.21 + 1200 + i * 9))
        star3 = int(round(length * 0.33 + 2400 + i * 13))
        levels.append({
            "id": i + 1,
            "world": world["id"],
            "name": name,
            "seed": seed,
            "length": length,
            "roadWidth": road_width,
            "curviness": curviness,
            "trafficDensity": traffic,
            "hazardDensity": hazards,
            "pickupDensity": pickups,
            "trafficSpeed": traffic_speed,
            "baseLives": 3,
            "star2": star2,
            "star3": star3,
            "hazards": world["hazards"],
            "mechanic": world["mechanic"],
            "ground": f"ground_{world['id']}",
            "music": world["music"],
        })
    return levels


def main() -> None:
    levels = build_levels()
    worlds = []
    for w in WORLDS:
        worlds.append({
            "id": w["id"], "name": w["name"], "accent": w["accent"],
            "mechanic": w["mechanic"], "blurb": w["blurb"],
            "music": w["music"], "ground": f"ground_{w['id']}",
        })
    payload = {
        "version": 1,
        "worlds": worlds,
        "levels": levels,
    }
    path = DATA / "levels.json"
    path.write_text(json.dumps(payload, indent=2) + "\n")
    (DATA / "cars.json").write_text(json.dumps({"version": 1, "cars": CARS}, indent=2) + "\n")
    print(f"Wrote {len(levels)} levels across {len(worlds)} worlds to {path}")
    print(f"Wrote {len(CARS)} cars")


if __name__ == "__main__":
    main()
