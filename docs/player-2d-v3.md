# 2D player: overhead occlusion

The active player is a 2D scene again. `scenes/actors/player_body.tscn` stores
21 real Sprite2D nodes; the editor and game use those same nodes and textures.
The previous 3D viewport is no longer part of the player scene.
The previous 3D experiment is preserved under `archive/player-3d-experiment`.

`scripts/actors/player_2d_rig.gd` animates the body from movement distance.
Idle, walking and sprinting blend continuously. Directional projected hip,
knee and ankle positions keep the legs connected while the torso covers their
upper sections. Only the cloth and boots outside the torso silhouette appear
during a step. Legs are drawn below the torso; sleeve roots are covered by
the shoulders, and elbows always bend outward. The flashlight follows its hand.
The free arm uses a connected shoulder/elbow/wrist chain with a relaxed idle
bend and a stronger jogging bend. Fixed physical lengths are projected into
the same overhead view; the hand is not moved independently from the elbow.
Only the fully raised flashlight arm uses the full 18/21 pixel planar IK.
Boot collars sit beneath
the trouser hems, and glove wrists and open sleeve ends sit beneath the cuffs
and elbow caps. All those layers are saved in the scene and editor clips.

The new generated source is `assets/characters/player/rig_v3/overhead_parts.png`.
It has genuine alpha transparency. AtlasTexture resources refer directly to
the original pixels; the extraction script does not repaint or remove alpha.
`tools/build_player_2d_atlas.py` detects transparent separators and records the
actual component regions. `tools/build_player_2d.gd` saves the assembled scene.

The complete generation prompt is `docs/player-overhead-v3-prompt.txt`.
It uses the built-in image_gen tool, a 4 × 3 component layout, strict orthographic
overhead anatomy, worn olive cloth, a folded hood and no backpack. For a related
character, replace only the subject/clothing/material palette while preserving
the camera, isolation, component ordering and transparent-background constraints.
The supplied stock image is a reference for pose and occlusion, not a source
texture. No pixels or watermark from it are used in the game.

To preview without running gameplay, open the body scene and set `preview_state`
and `preview_cycle`; enable `preview_animation` to play the selected state.
`preview_direction` controls the local walking direction. In-game movement,
collision, visibility and the shared room audio path are unchanged.
The saved AnimationPlayer also exposes editable `idle`, `walk`, `run` and `RESET`
clips with transform tracks for every sprite, using the same pose solver as
gameplay. Their library is `assets/characters/player/rig_v3/locomotion.tres`.
`stow_flashlight` and `draw_flashlight` are non-looping clips. When switching
off, the left hand moves around the flank, places the flashlight beneath the
jacket, releases it, then follows the same gait as the right arm. Switching
on reverses that motion. `idle_unlit`, `walk_unlit` and `run_unlit` expose both
natural arms in the editor; `preview_flashlight` scrubs the same transition.
The light origin, held sprite and lens marker share the rig's grip and angle.
The held prop uses `flashlight_overhead.svg`: the barrel is viewed from above,
with only a narrow glass edge rather than a face-on glowing disc. The gripping
hand follows its axis. Elbow folds use a small feathered sleeve crop oriented
along the forearm; the original round patch is no longer shown.

Checks: `tests/player_2d_regression.gd`, `tests/polish_regression.gd`,
`tests/overhead_pose_regression.gd`, `tests/gameplay_smoke.gd`.
`tests/player_2d_preview.gd -- --motion` captures an animation preview.
