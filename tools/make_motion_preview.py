"""Assemble captured in-engine frames into a loop for visual review."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
frames = [Image.open(path).convert("RGB").crop((340, 160, 970, 560))
          for path in sorted((root / ".godot/rig_frames").glob("*.png"))]
assert len(frames) == 48
palette = frames[0].quantize(colors=160)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
# GIF timing uses 10 ms units: three 20/20/10 ms samples equal 60 Hz.
frames[0].save(root / ".godot/rig_motion_preview.gif", save_all=True,
               append_images=frames[1:], loop=0, duration=[20, 20, 10] * 16,
               optimize=True, disposal=1)
print("Saved .godot/rig_motion_preview.gif")
