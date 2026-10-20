"""Describe generated creature cutouts without repainting their pixels or alpha."""
from pathlib import Path
import json
import sys

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
from build_player_2d_atlas import spans, row_separator

ROOT = Path(__file__).resolve().parents[1]
ROWS = (
    ("torso", "head", "upper_arm", "forearm"),
    ("foot", "hand", "elbow", "wrist"),
    ("thigh", "shin", "knee", "shoulder"),
)
TAIL_ROW = (("tail_root", "tail_middle", "tail_tip", "neck_mane"),)


def connected_regions(alpha, rows):
    """Find isolated cutouts when adjacent rows have staggered extremities."""
    parents, boxes, areas = [], [], []

    def find(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    previous = []
    for y, line in enumerate(alpha > 20):
        edges = np.diff(np.pad(line.astype(np.int8), (1, 1)))
        current = []
        cursor = 0
        for left, right in zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)):
            node = len(parents)
            parents.append(node)
            boxes.append([int(left), y, int(right), y + 1])
            areas.append(int(right - left))
            while cursor < len(previous) and previous[cursor][1] < left:
                cursor += 1
            neighbor = cursor
            while neighbor < len(previous) and previous[neighbor][0] <= right:
                a, b = find(node), find(previous[neighbor][2])
                if a != b:
                    parents[a] = b
                neighbor += 1
            current.append((left, right, node))
        previous = current
    groups = {}
    for index, (x0, y0, x1, y1) in enumerate(boxes):
        key = find(index)
        box = groups.setdefault(key, [x0, y0, x1, y1, 0])
        box[0], box[1] = min(box[0], x0), min(box[1], y0)
        box[2], box[3] = max(box[2], x1), max(box[3], y1)
        box[4] += areas[index]
    components = sorted(groups.values(), key=lambda box: box[4], reverse=True)[:len(rows) * 4]
    assert len(components) == len(rows) * 4
    components.sort(key=lambda box: box[1] + box[3])
    regions = {}
    for row, names in enumerate(rows):
        columns = sorted(components[row * 4:row * 4 + 4], key=lambda box: box[0] + box[2])
        for name, (x0, y0, x1, y1, area) in zip(names, columns):
            assert area > 500, f"Missing connected cutout: {name}"
            x0, y0 = max(0, x0 - 2), max(0, y0 - 2)
            x1, y1 = min(alpha.shape[1], x1 + 2), min(alpha.shape[0], y1 + 2)
            regions[name] = [x0, y0, x1 - x0, y1 - y0]
    # Crops must not include a neighboring cutout's tips or fur. Their tight
    # bounding boxes can overlap even when the painted islands do not touch.
    def separate(first, second, axis):
        a, b = regions[first], regions[second]
        end = a[axis] + a[axis + 2]
        start = b[axis]
        other = 1 - axis
        intersects = min(a[other] + a[other + 2], b[other] + b[other + 2]) > max(a[other], b[other])
        if end > start and intersects:
            b_end = b[axis] + b[axis + 2]
            a[axis + 2] = start - a[axis]
            b[axis], b[axis + 2] = end, b_end - end
    for names in rows:
        for first, second in zip(names, names[1:]):
            separate(first, second, 0)
    for upper, lower in zip(rows, rows[1:]):
        for first, second in zip(upper, lower):
            separate(first, second, 1)
    return regions


def describe(kind):
    version = "rig_v5" if kind == "monster" else "rig_v4"
    folder = ROOT / f"assets/characters/{kind}/{version}"
    with Image.open(folder / "overhead_parts.png") as atlas:
        assert atlas.mode == "RGBA", "The source must retain generated transparency"
        alpha = np.asarray(atlas.getchannel("A"))
    height, width = alpha.shape
    assert (alpha == 0).any() and (alpha > 240).any(), "Real alpha is required"
    rows = ROWS + TAIL_ROW if kind == "monster" else ROWS
    if kind == "monster":
        regions = connected_regions(alpha, rows)
    else:
        separators = [0] + [row_separator(alpha, index / len(rows)) for index in range(1, len(rows))] + [height]
        regions = {}
        for row, names in enumerate(rows):
            top, bottom = separators[row:row + 2]
            columns = spans(np.count_nonzero(alpha[top:bottom] > 20, axis=0) > 2)
            assert len(columns) == 4, (kind, row, columns)
            for name, (left, right) in zip(names, columns):
                ys, xs = np.nonzero(alpha[top:bottom, left:right] > 20)
                assert xs.size > 100, f"Missing component: {kind}/{name}"
                x0 = max(left, left + int(xs.min()) - 2)
                y0 = max(top, top + int(ys.min()) - 2)
                x1 = min(right, left + int(xs.max()) + 3)
                y1 = min(bottom, top + int(ys.max()) + 3)
                regions[name] = [x0, y0, x1 - x0, y1 - y0]
    # Keep the dorsal foot only. The source's vertical ankle socket belongs
    # beneath the independently posed shin, as with the hero's boot collar.
    x, y, w, h = regions["foot"]
    regions["foot_source"] = regions["foot"]
    trim = round(h * (0.30 if kind == "monster" else 0.23))
    regions["foot"] = [x, y + trim, w, h - trim]
    # Like the hero, the elbow is a feathered fold of actual sleeve/hide,
    # rather than a circular patch drawn on top of a bent limb.
    x, y, w, h = regions["forearm"]
    regions["elbow_source"] = regions["elbow"]
    regions["elbow"] = [x + round(w * .28), y + round(h * .25), round(w * .44), round(h * .20)]
    for name, (x, y, w, h) in regions.items():
        resource = f'''[gd_resource type="AtlasTexture" format=3]

[ext_resource type="Texture2D" path="res://assets/characters/{kind}/{version}/overhead_parts.png" id="atlas"]

[resource]
atlas = ExtResource("atlas")
region = Rect2({x}, {y}, {w}, {h})
filter_clip = true
'''
        (folder / f"{name}.tres").write_text(resource, encoding="utf-8")
    (folder / "atlas_regions.json").write_text(
        json.dumps({"source_size": [width, height], "regions": regions}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(kind, f"{width}x{height}", "alpha preserved", len(regions), "regions")


if __name__ == "__main__":
    for character in (("monster",) if "--hunter-only" in sys.argv else ("monster", "stalker")):
        describe(character)
