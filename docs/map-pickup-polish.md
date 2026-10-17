# Five fixtures, straw figurines and directional clues

Five editor-authored light fixtures are distributed as two metal shades (northwest and southeast), two fluorescents (northeast and center), and one bunker wall fixture (southwest). Origins were checked against actual physics geometry; the former nearby lamps were removed. All five shadow-map rows and all five floor/fog contributions are supported. Bodies and light pools remain visible without the flashlight, subject to wall occlusion.

All twelve figurines now use the generated transparent straw_figurine.png sprite, saved directly under each pickup in maze.tscn. The old line-drawn figurine and ochre arrows were removed. Built-in image_gen was used; the exact prompt is in assets/textures/pickups/straw_figurine.prompt.txt. Original generated PNG is preserved, including alpha.

Twelve authored blood-footprint trails follow the maze graph for the final roughly 450 units of a route toward each figurine. Alternating footprints point along the route, turn at corridor bends, end beside the real pickup, and disappear when it is collected.

Optimization: reject zero-contribution lamp pixels before polar-angle/shadow sampling; retain a reference shader mode for image equality tests; skip observer rays for wholly offscreen lamp pools; cache ceiling materials, camera uniform updates and lamp shadow geometry revisions; avoid redundant world-uniform writes and per-frame halo visibility raycasts. Visible shadow quality, the 1024 shadow samples, actor textures and atmospheric settings are retained.

Local overhead benchmark (RTX 3050 Laptop, median frame time, lamps enabled): before 2.588 / 2.289 ms, after 1.982 / 2.141 ms. This is a local comparison, not a general FPS guarantee. Map test confirms pixel-identical optimized/full shadow sampling in the same frozen scene. Gameplay, five-fixture, cheat/audio, flashlight-off lamp, and inner-corner GPU shadow tests pass.
