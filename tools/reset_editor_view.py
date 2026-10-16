from pathlib import Path
import hashlib
import re

root = Path.cwd()
editor = root / '.godot/editor'
editor.mkdir(parents=True, exist_ok=True)
layout = editor / 'editor_layout.cfg'
if layout.exists():
    text = layout.read_text(encoding='utf-8-sig').replace('res://world.tscn', 'res://scenes/game.tscn')
    text = re.sub(r'^open_scenes=.*$', 'open_scenes=PackedStringArray("res://scenes/game.tscn", "res://scenes/world/maze.tscn")', text, flags=re.MULTILINE)
    text = re.sub(r'^current_scene=.*$', 'current_scene="res://scenes/game.tscn"', text, flags=re.MULTILINE)
    text = text.replace('selected_paths=PackedStringArray("res://tools/")', 'selected_paths=PackedStringArray("res://scenes/game.tscn")')
    layout.write_text(text, encoding='utf-8')
metadata = editor / 'project_metadata.cfg'
if metadata.exists():
    text = metadata.read_text(encoding='utf-8-sig').replace('res://world.tscn', 'res://scenes/game.tscn')
    text = text.replace('res://player.gd', 'res://scripts/actors/player_controller.gd').replace('res://fog_of_war.gd', 'res://scripts/rendering/visibility_mask.gd')
    text = text.replace('res://wall.gd', 'res://scripts/world/wall.gd')
    metadata.write_text(text, encoding='utf-8')
for scene in ('scenes/game.tscn', 'scenes/world/maze.tscn', 'world.tscn'):
    resource = 'res://' + scene
    name = Path(scene).name + '-editstate-' + hashlib.md5(resource.encode()).hexdigest() + '.cfg'
    text = '''[editor_states]
$selected_nodes=Array[NodePath]([])
2D={
"grid_offset": Vector2(0, 0),
"grid_snap_active": false,
"grid_step": Vector2(320, 320),
"grid_visibility": 1,
"ofs": Vector2(-2200, -2200),
"show_helpers": true,
"show_origin": true,
"show_rulers": true,
"show_viewport": true,
"zoom": 0.14
}
'''
    (editor / name).write_text(text, encoding='utf-8')
