"""Derive a subtle tangent-space normal map from the existing floor texture."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

textures = Path(__file__).resolve().parents[1] / "assets/textures"
height_image = Image.open(textures / "concrete_floor.png").convert("L")
height = np.asarray(height_image.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255
dy, dx = np.gradient(height)
normal = np.dstack((-dx * 2.5, -dy * 2.5, np.ones_like(height)))
normal /= np.linalg.norm(normal, axis=2, keepdims=True)
Image.fromarray(np.uint8((normal * 0.5 + 0.5) * 255)).save(textures / "concrete_floor_normal.png")
