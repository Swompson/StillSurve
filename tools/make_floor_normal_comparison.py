"""Assemble a diagnostic comparison from the frozen Godot GPU captures."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20)
small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 15)
crop = (425, 405, 815, 695)
width, height = 390, 290
canvas = Image.new("RGB", (width * 3 + 48, height + 90), "#121212")
draw = ImageDraw.Draw(canvas)
for index, (filename, caption) in enumerate([
    ("floor_normal_off.png", "Без карты нормалей"),
    ("floor_normal_on.png", "С картой нормалей"),
    ("floor_normal_difference_x20.png", "Разница ×20"),
]):
    x = 12 + index * (width + 12)
    canvas.paste(Image.open(root / ".godot" / filename).convert("RGB").crop(crop), (x, 44))
    draw.text((x, 10), caption, font=font, fill="#dfd4bc")
draw.text((12, height + 54), "Одинаковые камера, свет и геометрия. Меняется только normal_strength: 0 → 0,6.", font=small, fill="#c2b9a7")
destination = root / "docs/visuals/floor_normals_comparison.png"
destination.parent.mkdir(exist_ok=True)
canvas.save(destination)
print(destination)
