# Fixture editor visibility, glass hearing and CPU budget

Five revised fixture models are stored as full native nodes in scenes/world/overhead.tscn. There are no separate fixture PackedScene instances or obsolete fixture templates. The outdated ceiling/wall fixture scenes and generators that could recreate the old layout were removed. world.tscn now instances the canonical scenes/game.tscn, so opening/running the old entry point cannot produce an outdated game. Maze and Overhead instances are editable in the main scene.

The shade uses dark painted steel seen from above, with its suspension nut and cable socket at the center. The detached old ceiling rectangle and wire were removed. The wall fixture shows its upper metal shell, wall mounting plate, cage ribs and a narrow side-facing glass strip. Halos render beneath the dark casing.

Editor verification: tools/editor_fixture_preview.gd runs inside Godot editor, opens the actual authored scene, asserts five visible bodies owned by the edited scene, checks tool processing is off, and saves the editor 2D viewport. Preview files: docs/visuals/editor_fixtures.png, editor_CeilingLamp1.png, editor_WallLamp.png.

Battery pickup: assets/textures/pickups/battery.png, generated through built-in image_gen with transparency. Exact prompt: battery.prompt.txt beside the asset. All five batteries have real BatteryBody Sprite2D children in maze.tscn. Old drawn battery rectangles were removed.

Glass: original recordings are unchanged. Player audio radius is 700 world units with attenuation 1.8, while monster hearing uses 12000 units before existing wall attenuation. A monster crunch alerts other hunters, excluding the hunter that made the step. Playback still passes through Master building reflections/reverb.

CPU: explicit 60 FPS active limit, 30 FPS pause limit and 15 FPS background limit; VSync enabled. Low processor usage mode is enabled while paused/unfocused. Simulation remains 60 Hz. No-op per-frame editor processing is disabled on fixtures, ceiling surfaces, wall height details, pickups and monster controller previews.

Local CPU benchmark, static representative game scene on this machine: unlimited 603.3 rendered frames/s and 1216.3 process CPU ms/s; capped active 60.6 rendered frames/s and 183.1 process CPU ms/s. Pause rendered 30.1 frames/s; background 15.0. The CPU comparison is against deliberately uncapped rendering, not a guarantee about all gameplay or hardware temperatures. No CPU temperature sensor measurement was available.

Validation: editor_glass_budget_regression.gd verifies the canonical legacy scene, fixture ownership, battery nodes, distant AI hearing, own-source exclusion, real glass stepping, shared bus and frame budgets. Gameplay, detection/audio, lamp/fog and map/pickup tests pass. No executable export was performed.
