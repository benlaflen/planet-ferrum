import argparse
import math
import random

from PIL import Image, ImageEnhance, ImageFilter

from grime import grime

# Matches the vanilla ore sheet: stages across (richest first), variations down, 128px frames at scale 0.5.
FRAME = 128
STAGES = 8
VARIATIONS = 8
TILE = 64

# Tuning. Radii and sizes are in sheet pixels; a tile is 64.
MAX_LAYERS = 4
RADIUS = (24, 56)
COUNT = (5, 55)
LAYER_SHRINK = 0.22
LAYER_LIFT = 7
LAYER_SHADE = (0.55, 1.0)
ITEM_SIZE = (22, 38)
SQUASH = 0.72
SHADOW_OFFSET = (3, 3)
SHADOW_ALPHA = 0.55
SHADOW_BLUR = 2
BRIGHTNESS_JITTER = 0.12


def load_icon(path):
    image = Image.open(path).convert("RGBA")
    size = image.height
    return image.crop((0, 0, size, size))


def item(icon, rng, shade):
    size = rng.randint(*ITEM_SIZE)
    sprite = grime(icon.resize((size, size), Image.LANCZOS), rng).rotate(rng.uniform(0, 360), Image.BICUBIC, expand=True)
    factor = shade * (1 + rng.uniform(-BRIGHTNESS_JITTER, BRIGHTNESS_JITTER))
    rgb = ImageEnhance.Brightness(sprite.convert("RGB")).enhance(factor)
    sprite = Image.merge("RGBA", (*rgb.split(), sprite.getchannel("A")))
    shadow = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    shadow.putalpha(sprite.getchannel("A").point(lambda a: int(a * SHADOW_ALPHA)))
    return sprite, shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))


def frame(icon, stage, rng):
    fullness = 1 - stage / (STAGES - 1)
    layers = 1 + round((MAX_LAYERS - 1) * fullness)
    radius = RADIUS[0] + (RADIUS[1] - RADIUS[0]) * fullness
    count = COUNT[0] + (COUNT[1] - COUNT[0]) * fullness
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    centre = FRAME / 2

    for layer in range(layers):
        layer_radius = radius * (1 - LAYER_SHRINK * layer)
        shade = LAYER_SHADE[0] + (LAYER_SHADE[1] - LAYER_SHADE[0]) * (layer + 1) / MAX_LAYERS
        placed = []
        for _ in range(max(1, round(count * (1 - 0.25 * layer)))):
            distance = layer_radius * math.sqrt(rng.random())
            angle = rng.uniform(0, 2 * math.pi)
            x = centre + distance * math.cos(angle)
            y = centre + distance * math.sin(angle) * SQUASH - LAYER_LIFT * layer
            placed.append((y, x))
        for y, x in sorted(placed):
            sprite, shadow = item(icon, rng, shade)
            left, top = int(x - sprite.width / 2), int(y - sprite.height / 2)
            canvas.alpha_composite(shadow, (left + SHADOW_OFFSET[0], top + SHADOW_OFFSET[1]))
            canvas.alpha_composite(sprite, (left, top))
    return canvas


def preview(sheet, path, rng, size=6):
    # One size x size patch per stage, drawn the way the game overlaps neighbouring resource tiles.
    patch = size * TILE + FRAME
    image = Image.new("RGBA", (patch * STAGES, patch), (70, 70, 80, 255))
    for stage in range(STAGES):
        for row in range(size):
            for column in range(size):
                variation = rng.randrange(VARIATIONS)
                cell = sheet.crop((stage * FRAME, variation * FRAME, (stage + 1) * FRAME, (variation + 1) * FRAME))
                image.alpha_composite(cell, (stage * patch + column * TILE + TILE // 2, row * TILE + TILE // 2))
    image.save(path)


def main():
    parser = argparse.ArgumentParser(description="Generate a resource stage sheet from an item icon.")
    parser.add_argument("icon")
    parser.add_argument("output")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--preview")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    icon = load_icon(args.icon)
    sheet = Image.new("RGBA", (FRAME * STAGES, FRAME * VARIATIONS), (0, 0, 0, 0))
    for variation in range(VARIATIONS):
        for stage in range(STAGES):
            sheet.alpha_composite(frame(icon, stage, rng), (stage * FRAME, variation * FRAME))
    sheet.save(args.output)
    if args.preview:
        preview(sheet, args.preview, rng)


if __name__ == "__main__":
    main()