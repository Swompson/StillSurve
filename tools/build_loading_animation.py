"""Keep the original GIF and extract its frames with their original timing for Godot."""
from pathlib import Path
import shutil
import sys
from PIL import Image, ImageSequence

root = Path(__file__).resolve().parents[1]
target = root / "assets/ui/loading"
target.mkdir(parents=True, exist_ok=True)
source = Path(sys.argv[1]) if len(sys.argv) > 1 else target / "basement_flicker_balanced_new.gif"
original = target / source.name
if source.resolve() != original.resolve():
    shutil.copy2(source, original)
with Image.open(original) as animation:
    frames = []
    for index, frame in enumerate(ImageSequence.Iterator(animation)):
        name = f"{original.stem}_{index:02}.png"
        frame.convert("RGB").save(target / name, optimize=True)
        frames.append((name, frame.info.get("duration", 100) / 1000))
lines = ['[gd_resource type="AnimatedTexture" format=3]', '']
for index, (name, _) in enumerate(frames):
    lines.append(f'[ext_resource type="Texture2D" path="res://assets/ui/loading/{name}" id="f{index}"]')
lines += ['', '[resource]', f'frames = {len(frames)}', 'fps = 0.0']
for index, (_, duration) in enumerate(frames):
    lines += [f'frame_{index}/texture = ExtResource("f{index}")', f'frame_{index}/duration = {duration}']
(target / "basement_animation.tres").write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f"Converted {len(frames)} frames; loop duration: {sum(d for _, d in frames):.2f}s")
