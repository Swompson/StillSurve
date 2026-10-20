from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "assets/textures/rubble"
# Each outline is shared by the SVG surface and the saved physics shape.
OUTLINES = [
    [(-37, -10), (-24, -22), (13, -21), (33, -9), (36, 3), (26, 16), (5, 20), (-28, 15)],
    [(-35, -12), (-16, -24), (17, -19), (35, -5), (31, 14), (12, 22), (-17, 19), (-36, 6)],
    [(-39, -4), (-28, -18), (-3, -23), (25, -15), (37, 4), (22, 19), (-9, 22), (-34, 12)],
    [(-35, -14), (-8, -23), (22, -17), (37, -1), (26, 18), (1, 23), (-25, 15), (-39, 0)],
]
PALETTES = [("#3e443e", "#292f2b"), ("#46463b", "#30322b"), ("#39443e", "#252f2b"), ("#49463b", "#302f28")]
TARGET.mkdir(parents=True, exist_ok=True)
for variant, outline in enumerate(OUTLINES):
    rng = random.Random(603 + variant)
    points = " ".join(f"{x},{y}" for x, y in outline)
    light, dark = PALETTES[variant]
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="352" height="224" viewBox="-44 -28 88 56"><defs><clipPath id="edge"><polygon points="{points}"/></clipPath><linearGradient id="body" x1="0" y1="0" x2=".3" y2="1"><stop stop-color="{light}"/><stop offset="1" stop-color="{dark}"/></linearGradient></defs>']
    parts.append(f'<polygon points="{points}" fill="url(#body)"/>')
    parts.append('<g clip-path="url(#edge)">')
    # Broad fractured planes stay inside the physical silhouette; no painted shadows.
    parts.append('<path d="M-37 -10L-24 -22L13 -21L25 -8L4 -5L-18 1Z" fill="#666a57" opacity=".055"/>')
    parts.append('<path d="M-39 0L-18 1L4 -5L25 -8L37 4L26 18L1 23L-25 15Z" fill="#18251f" opacity=".10"/>')
    for _ in range(60):
        x, y = rng.uniform(-40, 40), rng.uniform(-24, 24)
        color = rng.choice(["#5a5948", "#19251f", "#484d3e"])
        parts.append(f'<ellipse cx="{x:.2f}" cy="{y:.2f}" rx="{rng.uniform(2, 7):.2f}" ry="{rng.uniform(1, 4):.2f}" fill="{color}" opacity=".045"/>')
    for _ in range(1800):
        x, y = rng.uniform(-42, 42), rng.uniform(-26, 26)
        color = rng.choice(["#656451", "#1b2720", "#4a5243", "#30392e"])
        parts.append(f'<ellipse cx="{x:.2f}" cy="{y:.2f}" rx="{rng.uniform(.18, .8):.2f}" ry="{rng.uniform(.15, .55):.2f}" fill="{color}" opacity="{rng.uniform(.08, .22):.2f}"/>')
    parts.append('<path d="M-24 -22L-16 -13L-18 -5L-8 2L-9 9M-18 -5L-27 1M33 -9L19 -3L15 5L6 9M15 5L22 11" fill="none" stroke="#1f2821" stroke-width=".45" opacity=".35"/>')
    parts.append('<path d="M-23 -21L-15 -13M20 -2L16 5" fill="none" stroke="#62644f" stroke-width=".35" opacity=".18"/>')
    parts.append('</g>')
    parts.append(f'<polygon points="{points}" fill="none" stroke="#283129" stroke-width=".45"/>')
    parts.append('</svg>')
    (TARGET / f"broken_concrete_{variant}.svg").write_text("".join(parts), encoding="utf-8")
    coordinates = ", ".join(str(value) for point in outline for value in point)
    shape = '[gd_resource type="ConvexPolygonShape2D" format=3]\n\n[resource]\npoints = PackedVector2Array(' + coordinates + ')\n'
    (TARGET / f"broken_concrete_{variant}_shape.tres").write_text(shape, encoding="utf-8")
print("Saved four solid concrete surfaces with matching physics silhouettes")