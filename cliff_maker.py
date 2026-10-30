import argparse
import math
import os
import random

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

from grime import grime

# Fulgora cliff sheets: 256px frames. Shadow sheets are left as vanilla.
FRAME = 256
PIECES = ("sides", "outer", "inner", "entrance")
SOURCE_PREFIX = "cliff-fulgora-"
OUTPUT_PREFIX = "cliff-cinder-"

# Recolour: hue in degrees; saturation is scaled then offset (0-255); value is scaled.
HUE = 225
SATURATION = (0.4, 25)
VALUE = 0.8

# Junk embedded in the upper sheet only. Sizes in sheet pixels (a tile is 64).
ITEMS_PER_FRAME = (2, 6)
ITEM_SIZE = (16, 30)
ITEM_BRIGHTNESS = 0.7
BURIED = (0.2, 0.6)
WIRES_PER_FRAME = (0, 2)
WIRE_LENGTH = (20, 50)
WIRE_SAG = (6, 16)
WIRE_COLOUR = (28, 28, 34, 255)
WIRE_HIGHLIGHT = (85, 85, 100, 255)
# Pixels an item's centre must be inside the cliff silhouette, so nothing floats past the edge.
INSET = 9
SHADOW_OFFSET = (2, 2)
SHADOW_ALPHA = 0.5
PLACEMENT_TRIES = 200


def recolour(image):
    alpha = image.getchannel("A")
    h, s, v = image.convert("RGB").convert("HSV").split()
    h = h.point(lambda _: int(HUE / 360 * 255))
    s = s.point(lambda x: max(0, min(255, int(x * SATURATION[0] + SATURATION[1]))))
    v = v.point(lambda x: int(x * VALUE))
    result = Image.merge("HSV", (h, s, v)).convert("RGB").convert("RGBA")
    result.putalpha(alpha)
    return result


def load_icon(path):
    image = Image.open(path).convert("RGBA")
    return image.crop((0, 0, image.height, image.height))


def position(inside, rng):
    for _ in range(PLACEMENT_TRIES):
        x, y = rng.randrange(FRAME), rng.randrange(FRAME)
        if inside.getpixel((x, y)) > 200:
            return x, y
    return None


def clip(layer, mask, left, top):
    region = mask.crop((left, top, left + layer.width, top + layer.height))
    alpha = Image.composite(layer.getchannel("A"), Image.new("L", layer.size, 0), region)
    layer.putalpha(alpha)
    return layer


def junk(icon, rng):
    size = rng.randint(*ITEM_SIZE)
    sprite = grime(icon.resize((size, size), Image.LANCZOS), rng)
    rgb = ImageEnhance.Brightness(sprite.convert("RGB")).enhance(ITEM_BRIGHTNESS)
    sprite = Image.merge("RGBA", (*rgb.split(), sprite.getchannel("A")))
    # Cut away one side so the item reads as half-buried.
    cut = Image.new("L", (size, size), 0)
    depth = size * rng.uniform(*BURIED)
    ImageDraw.Draw(cut).rectangle((0, 0, size, size - depth), fill=255)
    sprite.putalpha(Image.composite(sprite.getchannel("A"), Image.new("L", sprite.size, 0), cut))
    return sprite.rotate(rng.uniform(0, 360), Image.BICUBIC, expand=True)


def wire(rng):
    length = rng.randint(*WIRE_LENGTH)
    sag = rng.randint(*WIRE_SAG)
    angle = rng.uniform(-0.6, 0.6)
    size = length + 2 * sag + 8
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    points = []
    for i in range(17):
        t = i / 16
        along = (t - 0.5) * length
        droop = sag * 4 * t * (1 - t)
        points.append((size / 2 + along * math.cos(angle), size / 2 + along * math.sin(angle) + droop))
    draw.line(points, fill=WIRE_COLOUR, width=3, joint="curve")
    draw.line([(x, y - 1) for x, y in points], fill=WIRE_HIGHLIGHT, width=1)
    return layer


def place(canvas, sprite, x, y, mask):
    left, top = int(x - sprite.width / 2), int(y - sprite.height / 2)
    padded = Image.new("L", (FRAME + 2 * sprite.width, FRAME + 2 * sprite.height), 0)
    padded.paste(mask, (sprite.width, sprite.height))
    sprite = clip(sprite, padded, left + sprite.width, top + sprite.height)
    shadow = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    shadow.putalpha(sprite.getchannel("A").point(lambda a: int(a * SHADOW_ALPHA)).filter(ImageFilter.GaussianBlur(1)))
    canvas.alpha_composite(shadow, (left + SHADOW_OFFSET[0], top + SHADOW_OFFSET[1]))
    canvas.alpha_composite(sprite, (left, top))


def decorate(frame, icons, rng):
    mask = frame.getchannel("A")
    inside = mask.filter(ImageFilter.MinFilter(2 * INSET + 1))
    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    for _ in []:#range(rng.randint(*ITEMS_PER_FRAME)):
        spot = position(inside, rng)
        if spot:
            place(canvas, junk(rng.choice(icons), rng), *spot, mask)
    for _ in []:#range(rng.randint(*WIRES_PER_FRAME)):
        spot = position(inside, rng)
        if spot:
            place(canvas, wire(rng), *spot, mask)
    frame.alpha_composite(canvas)
    return frame


def process(source, output, icons, rng):
    sheet = recolour(Image.open(source).convert("RGBA"))
    if icons:
        for top in range(0, sheet.height, FRAME):
            for left in range(0, sheet.width, FRAME):
                box = (left, top, left + FRAME, top + FRAME)
                sheet.paste(decorate(sheet.crop(box), icons, rng), box)
    sheet.save(output)


def main():
    parser = argparse.ArgumentParser(description="Recolour Fulgora's cliffs and embed item junk in them.")
    parser.add_argument("source_dir", help="Folder holding cliff-fulgora-*.png")
    parser.add_argument("output_dir")
    parser.add_argument("icons", nargs="+", help="Item icons to embed, e.g. iron-gear-wheel.png flying-robot-frame.png")
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    icons = [load_icon(path) for path in args.icons]
    os.makedirs(args.output_dir, exist_ok=True)
    for piece in PIECES:
        for suffix, decorated in (("", True), ("-lower", False)):
            source = os.path.join(args.source_dir, SOURCE_PREFIX + piece + suffix + ".png")
            if not os.path.exists(source):
                print("missing", source)
                continue
            output = os.path.join(args.output_dir, OUTPUT_PREFIX + piece + suffix + ".png")
            process(source, output, icons if decorated else None, rng)
            print("wrote", output)


if __name__ == "__main__":
    main()