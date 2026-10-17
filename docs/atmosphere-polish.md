# Atmosphere polish

- Monster growls: near -3 dB, far -38 dB before spatial attenuation; walls add 6 dB damping. Howls use the same distance curve over 2800 units and spatial attenuation out to 4200 units.
- Four authored fixtures: two swaying metal shades, a fluorescent suspended on one side, and a caged wall lamp. Upper-left shade at (-1280, -1280).
- All four fixtures feed the floor and visibility shaders with 245-unit light pools. Pools and halos remain visible without the flashlight. A cached 1024-ray polar shadow map per lamp clips both floor illumination and halos against walls and rubble. Halos render under the observer visibility mask.
- Ceiling spans and sockets share a reduced elevation projection (0.035–0.048, capped at 20 units); fixtures use 0.032, capped at 14 units. Player visuals render below ceiling details. Brightness dips and recovers smoothly.
- Twelve additional authored rubble piles occupy closed inside corners and block both movement and sight. Monster glass footsteps play original recordings without entering the player alert path; player glass still alerts hunters.
- Nine authored blood stain clusters include pools, smears and small splashes.
- Three spatial waterdrop sources are located along ceiling pipes. Original recording copied without conversion from Downloads/waterdrop.mp3 to assets/audio/user_originals/waterdrop.mp3. All sources use Master with the building reflection/reverb effects.

Validation: gameplay_smoke.gd, overhead_hunters_regression.gd and lamp_cover_regression.gd report zero failures; inner_corner_shadow_regression.gd passes with no GPU light leaks. Lamp regression checks flashlight-off pools, lamp shadows, hidden halos, ceiling order, source-specific glass alerts and authored cover. Rendered fixture previews: docs/visuals/atmosphere_*.png. Restricted user:// storage causes logger/cache warnings; shutdown can also report retained resources. No executable export was run.
