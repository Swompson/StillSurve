from pathlib import Path
import re

TARGET = Path(__file__).resolve().parents[1] / "assets/textures/rubble"

def write_asset(path, content):
    if path.is_file() and path.read_text(encoding="utf-8") == content:
        return
    temporary = path.with_suffix(path.suffix + ".next")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)

assert (TARGET / "user_rock_original.png").is_file()
for variant in range(4):
    # Existing saved shapes are the authoritative silhouette, never a new crop.
    shape = (TARGET / f"broken_concrete_{variant}_shape.tres").read_text(encoding="utf-8")
    values = re.search(r"PackedVector2Array\(([^)]+)\)", shape).group(1).split(",")
    points = " ".join(f"{values[i].strip()},{values[i+1].strip()}" for i in range(0, len(values), 2))
    mask = f'<svg xmlns="http://www.w3.org/2000/svg" width="352" height="224" viewBox="-44 -28 88 56"><polygon points="{points}" fill="white"/></svg>'
    write_asset(TARGET / f"stone_mask_{variant}.svg", mask)
    material = f'''[gd_resource type="ShaderMaterial" load_steps=3 format=3]

[ext_resource type="Shader" path="res://shaders/warehouse_top.gdshader" id="shader"]
[ext_resource type="Texture2D" path="res://assets/textures/rubble/user_rock_original.png" id="texture"]

[resource]
shader = ExtResource("shader")
shader_parameter/use_detail_texture = true
shader_parameter/editor_preview = true
shader_parameter/detail_texture = ExtResource("texture")
shader_parameter/detail_tint = Color(0.68, 0.70, 0.65, 1)
shader_parameter/detail_texels_per_unit = 5.5
shader_parameter/detail_uv_offset = Vector2({variant * 0.17:.2f}, {variant * 0.13:.2f})
shader_parameter/detail_uv_angle = {variant * 0.37:.2f}
shader_parameter/stone_relief = true
shader_parameter/stone_outline = PackedVector2Array({", ".join(value.strip() for value in values)})
'''
    write_asset(TARGET / f"broken_concrete_{variant}_material.tres", material)
print("Saved four materials using the supplied texture and existing stone silhouettes")
