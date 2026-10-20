# Breathing and lighting update

Current playback uses the complete original `dihanie_beg2.mp3` and
`vinoslivosti_net.mp3` directly. Only playback gain is adjusted (+10 dB run,
-9 dB recovery), with volume fades at state changes. Pitch is 1.0; the extra
Breathing low-pass and reverb are disabled. Shared Master room acoustics remain.
The PCM preparation described below is historical and is not used by the scene.

Original `dihanie_beg.mp3`, `dihanie_beg2.mp3` and `vinoslivosti_net.mp3` are preserved under
`assets/audio/user_originals`. `tools/prepare_user_breathing.gd` decodes the
0.25–11.75 second phrase from `dihanie_beg2` and the 1.9–9.1 second recovery
phrase to stereo PCM. These omit silent endings and begin in similar breath
registers (roughly 1.3–1.6 kHz energy centroids at the join). The tool
normalizes to -23 dBFS RMS with a -1 dBFS peak ceiling, and adds 80 ms edge fades.
Both runtime voices share the same -5 dB target gain to avoid a loudness jump.
The saved Breathing/Recovery players crossfade in linear amplitude. Recovery
begins only after empty stamina and continues until full stamina or renewed
sprinting. Both voices use Breathing → Master and the existing room effects.

The switch engages at 72% of drawing the flashlight. Beam onset and playback
share one physics update; playback skips the recording's 120 ms leading pause.
Switching off extinguishes the beam on the off click.

Marked fixtures retain their original supports: CeilingLamp1 moves along
Beams/Span05 to (-1390, -297), CeilingLamp2 along Beams/Span00 to (1440, -1541),
CeilingLamp5 along Pipes/Span11 to (-59, 370). Other fixtures are unchanged.

Drums use saved circular collision and sixteen-point visibility outlines rather
than rectangular shadows. Storage texture colors are 30% brighter, ambient top
shading is lighter, and top shaders sample texture color only once.

Wall contact strips exclude storage props, preventing shifted highlights and
short stripes on curved lids. Storage visibility updates every rendered frame
without the previous 125 ms polling delay or temporal fade-in. The gate accepts
a partially exposed object; its shader clips individual top pixels against
cached wall rectangles and circular props while ignoring its own collision.

The saved pause and main-menu scenes expose separate sliders for Music,
Environment, StepsRoom, Breathing, Heartbeat and Effects, in addition to Master.
Settings persist in `settings.cfg`; zero mutes the selected bus. Ambience sends
to Environment, and every category ultimately reaches Master room effects.
