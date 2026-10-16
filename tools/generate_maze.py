"""Build the editable maze scene. Fixed layout; runtime spawn is random."""
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
N, CELL = 11, 320
rng = random.Random(161026)
masks = [0] * (N*N)
dirs = [(0,-1,1,4), (1,0,2,8), (0,1,4,1), (-1,0,8,2)]
visited = {60}
stack = [60]
while stack:
    cell = stack[-1]
    x, y = cell % N, cell // N
    choices = [(x+dx, y+dy, bit, opposite) for dx,dy,bit,opposite in dirs
               if 0 <= x+dx < N and 0 <= y+dy < N and (y+dy)*N+x+dx not in visited]
    if not choices:
        stack.pop()
        continue
    nx, ny, bit, opposite = rng.choice(choices)
    other = ny*N+nx
    masks[cell] |= bit
    masks[other] |= opposite
    visited.add(other)
    stack.append(other)
# Extra loops give the hunted player escape routes instead of only dead ends.
closed = [(i, i+1, 2, 8) for i in range(N*N) if i%N < N-1 and not masks[i]&2]
closed += [(i, i+N, 4, 1) for i in range(N*(N-1)) if not masks[i]&4]
for a,b,bit,opposite in rng.sample(closed, 18):
    masks[a] |= bit
    masks[b] |= opposite


def pos(cell):
    return ((cell%N - N//2)*CELL, (cell//N - N//2)*CELL)


def spread(candidates, count, occupied):
    chosen = []
    for _ in range(count):
        candidate = max(candidates, key=lambda c: min((pos(c)[0]-pos(o)[0])**2 +
                        (pos(c)[1]-pos(o)[1])**2 for o in occupied+chosen))
        chosen.append(candidate)
        candidates.remove(candidate)
    return chosen


dead_ends = [i for i,m in enumerate(masks) if m.bit_count() <= 2 and i != 60]
figurines = spread(dead_ends, 12, [60])
batteries = spread([i for i in range(N*N) if i not in figurines and i != 60], 3, [60]+figurines)
wall_segments = []
for line in range(N+1):
    blocked = [line in (0,N) or not masks[(line-1)*N+x]&4 for x in range(N)]
    start = 0
    while start < N:
        if not blocked[start]:
            start += 1
            continue
        end = start+1
        while end < N and blocked[end]: end += 1
        wall_segments.append(((start+end)*CELL/2-N*CELL/2, line*CELL-N*CELL/2,
                              (end-start)*CELL+24, 24))
        start = end
for line in range(N+1):
    blocked = [line in (0,N) or not masks[y*N+line-1]&2 for y in range(N)]
    start = 0
    while start < N:
        if not blocked[start]:
            start += 1
            continue
        end = start+1
        while end < N and blocked[end]: end += 1
        wall_segments.append((line*CELL-N*CELL/2, (start+end)*CELL/2-N*CELL/2,
                              24, (end-start)*CELL+24))
        start = end

scene = ['[gd_scene load_steps=5 format=3]',
    '[ext_resource type="Script" path="res://scripts/world/maze.gd" id="1"]',
    '[ext_resource type="PackedScene" path="res://scenes/world/wall.tscn" id="2"]',
    '[ext_resource type="Script" path="res://scripts/world/pickup.gd" id="3"]',
    '[ext_resource type="Texture2D" path="res://assets/textures/concrete_floor.png" id="4"]',
    '[node name="Maze" type="Node2D"]', 'script = ExtResource("1")',
    'connections = PackedInt32Array('+', '.join(map(str,masks))+')',
    '[node name="Floor" type="Sprite2D" parent="."]', 'z_index = -20',
    'texture_repeat = 2', 'texture = ExtResource("4")', 'region_enabled = true',
    'region_rect = Rect2(0, 0, 4096, 4096)',
    '[node name="Walls" type="Node2D" parent="."]', 'z_index = 5']
for index,(x,y,w,h) in enumerate(wall_segments):
    scene += [f'[node name="Wall{index:03}" parent="Walls" instance=ExtResource("2")]',
              f'position = Vector2({x:g}, {y:g})', f'wall_size = Vector2({w:g}, {h:g})']
    if max(w, h) == CELL + 24 and index % 3 == 2:
        scene += ['damaged = true']
scene += ['[node name="Pickups" type="Node2D" parent="."]', 'z_index = 3']
for kind, cells in [('figurine',figurines),('battery',batteries)]:
    for index,cell in enumerate(cells):
        x,y = pos(cell)
        scene += [f'[node name="{kind.title()}{index+1:02}" type="Node2D" parent="Pickups"]',
                  f'position = Vector2({x}, {y})', 'script = ExtResource("3")', f'kind = "{kind}"']
(ROOT/'scenes/world/maze.tscn').write_text('\n\n'.join(scene)+'\n', encoding='utf-8')
print(f'Maze: {N}x{N}, {len(wall_segments)} merged walls, 12 figurines, 3 batteries; all {len(visited)} cells connected')
