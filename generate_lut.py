import os
import sys

from PIL import Image

# usage: generate_lut.py <factorio data dir>
SOURCE = "space-age/graphics/lut/fulgora-{}.png"
TARGET = "graphics/lut/ferrum-{}.png"
# Night darkness already comes from min_brightness in control.lua.
FACTORS = {
    "1-noon": 0.6,
    "2-afternoon": 0.6,
    "3-after-sunset": 1.0,
    "4-before-dawn": 1.0,
    "5-morning": 0.6,
}

for name, factor in FACTORS.items():
    image = Image.open(os.path.join(sys.argv[1], SOURCE.format(name))).convert("RGB")
    image.point(lambda v: round(v * factor)).save(TARGET.format(name))