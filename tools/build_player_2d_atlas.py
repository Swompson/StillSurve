"""Describe the generated 4 x 3 hero atlas without altering source pixels/alpha."""
from pathlib import Path
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "assets/characters/player/rig_v3"
ROWS = (
    ("torso", "head", "upper_arm", "forearm"),
    ("foot", "hand", "elbow", "flashlight"),
    ("thigh", "shin", "knee", "shoulder"),
)


def spans(values, minimum=20):
    edges = np.diff(np.pad(values.astype(np.int8), (1, 1)))
    result = []
    for start, end in zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)):
        if result and start - result[-1][1] < 12:
            result[-1] = (result[-1][0], int(end))
        else:
            result.append((int(start), int(end)))
    return [(start, end) for start, end in result if end - start >= minimum]


def row_separator(alpha, fraction):
    counts = np.count_nonzero(alpha > 20, axis=1)
    center = round(alpha.shape[0] * fraction)
    radius = round(alpha.shape[0] * 0.09)
    candidates = np.flatnonzero(counts[max(0, center - radius):center + radius] < 4)
    assert candidates.size, "The component rows overlap"
    return int(candidates[np.argmin(np.abs(candidates + center - radius - center))] + center - radius)


def main():
    with Image.open(FOLDER / "overhead_parts.png") as atlas:
        assert atlas.mode == "RGBA", "The source must retain generated transparency"
        alpha = np.asarray(atlas.getchannel("A"))
    height, width = alpha.shape
    assert (alpha == 0).any() and (alpha > 240).any(), "Real alpha is required"
    regions = {}
    separators = [0, row_separator(alpha, 1 / 3), row_separator(alpha, 2 / 3), height]
    for row, names in enumerate(ROWS):
        top, bottom = separators[row:row + 2]
        occupied = np.count_nonzero(alpha[top:bottom] > 20, axis=0) > 2
        columns = spans(occupied)
        assert len(columns) == 4, (row, columns)
        for name, (left, right) in zip(names, columns):
            mask = alpha[top:bottom, left:right] > 20
            ys, xs = np.nonzero(mask)
            assert xs.size > 100, f"Missing component: {name}"
            x0, y0 = max(left, left + int(xs.min()) - 2), max(top, top + int(ys.min()) - 2)
            x1 = min(right, left + int(xs.max()) + 3)
            y1 = min(bottom, top + int(ys.max()) + 3)
            regions[name] = [x0, y0, x1 - x0, y1 - y0]
            resource = f'''[gd_resource type="AtlasTexture" format=3]

[ext_resource type="Texture2D" path="res://assets/characters/player/rig_v3/overhead_parts.png" id="atlas"]

[resource]
atlas = ExtResource("atlas")
region = Rect2({x0}, {y0}, {x1 - x0}, {y1 - y0})
filter_clip = true
'''
            (FOLDER / f"{name}.tres").write_text(resource, encoding="utf-8")
            print(name, regions[name])
    (FOLDER / "atlas_regions.json").write_text(
        json.dumps({"source_size": [width, height], "regions": regions}, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
