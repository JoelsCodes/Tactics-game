"""Grade the existing Rock 01 CC0 scan into the kit's packed limestone maps."""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def image_data(path, mode):
    return np.asarray(Image.open(path).convert(mode), dtype=np.float32) / 255


def blur(data, radius):
    # Pad with wrapped image data to preserve the original image's repeat.
    border = int(radius * 3) + 2
    canvas = np.pad(data, border, mode="wrap")
    image = Image.fromarray(np.uint8(np.clip(canvas, 0, 1) * 255))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)[
        border:-border, border:-border
    ] / 255


def save(path, channel):
    data = np.uint8(np.clip(channel, 0, 1) * 255 + .5)
    Image.fromarray(data).save(path, quality=96, subsampling=0)


def bake(source, output):
    output.mkdir(parents=True, exist_ok=True)
    rgb = image_data(source / "rock_01_diff_1k.jpg", "RGB")
    raw_normal = image_data(source / "rock_01_nor_gl_1k.jpg", "RGB") * 2 - 1
    scan_rough = image_data(source / "rock_01_rough_1k.jpg", "L")
    luma = rgb @ np.array([.2126, .7152, .0722], dtype=np.float32)
    coarse = blur(luma, 29)
    medium = blur(luma, 5)
    fine = luma - medium
    # Pull sediment and mineral differences out of the same scan. Keep coarse
    # captured lighting mild, while retaining the medium bands and small pores.
    mineral = np.clip((medium - coarse) * 3.0 + (coarse - np.median(coarse)) * .63, -.24, .24)
    oxide = np.clip((rgb[..., 0] - rgb[..., 2] - .035) * 1.8, -.09, .16)
    body = .497 + mineral * .65 + fine * .74
    color = body[..., None] * np.array([1.087, 1.023, .912])
    color += oxide[..., None] * np.array([.17, .037, -.085])
    save(output / "color.jpg", color)
    save(output / "ochre.jpg", color * np.array([1.018, .995, .968]) + .010)
    save(output / "cool.jpg", color * np.array([.937, .974, 1.025]) - .009)

    roughness = .66 + (scan_rough - .5) * .44 + np.abs(fine) * .24 - mineral * .17
    save(output / "roughness.jpg", np.clip(roughness, .46, .91))

    relief = fine * .67 + mineral * .13
    dx = np.roll(relief, -1, axis=1) - np.roll(relief, 1, axis=1)
    dy = np.roll(relief, -1, axis=0) - np.roll(relief, 1, axis=0)
    normal = raw_normal.copy()
    normal[..., 0] = raw_normal[..., 0] * .78 - dx * .98
    normal[..., 1] = raw_normal[..., 1] * .78 + dy * .98
    normal[..., 2] = np.maximum(raw_normal[..., 2], .12)
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    save(output / "normal.jpg", normal * .5 + .5)

    joint = .42 + (medium - .5) * .22 + fine * .62
    save(output / "mortar.jpg", joint[..., None] * np.array([1.08, 1.015, .90]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    bake(args.source, args.output)
