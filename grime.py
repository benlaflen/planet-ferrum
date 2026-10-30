from PIL import Image, ImageEnhance, ImageFilter, ImageOps

# Shared by generate_veins.py and generate_cliffs.py. Strengths are blend weights (0-1).
DESATURATE = 0.35
HIGHLIGHT_KNEE = 140
HIGHLIGHT_SLOPE = 0.3
GRIME_COLOUR = (35, 30, 26)
GRIME_STRENGTH = 0.6
DUST_COLOUR = (118, 110, 98)
DUST_STRENGTH = 0.7
NOISE_BLUR = 1.2


def noise(size, rng):
    raw = Image.frombytes("L", size, bytes(rng.getrandbits(8) for _ in range(size[0] * size[1])))
    return ImageOps.autocontrast(raw.filter(ImageFilter.GaussianBlur(NOISE_BLUR)))


def grime(sprite, rng):
    alpha = sprite.getchannel("A")
    rgb = ImageEnhance.Color(sprite.convert("RGB")).enhance(DESATURATE)
    rgb = rgb.point(lambda v: v if v < HIGHLIGHT_KNEE else int(HIGHLIGHT_KNEE + (v - HIGHLIGHT_KNEE) * HIGHLIGHT_SLOPE))
    dark = noise(sprite.size, rng).point(lambda v: int(v * GRIME_STRENGTH))
    rgb = Image.composite(Image.new("RGB", sprite.size, GRIME_COLOUR), rgb, dark)
    # Dust only where the noise is above its midpoint, so it collects in patches rather than evenly.
    dust = noise(sprite.size, rng).point(lambda v: int(max(0, v - 128) * 2 * DUST_STRENGTH))
    rgb = Image.composite(Image.new("RGB", sprite.size, DUST_COLOUR), rgb, dust)
    return Image.merge("RGBA", (*rgb.split(), alpha))