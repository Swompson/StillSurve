# Detection, event audio and immortality

During active play, press physical Q, A, Z in order to toggle immortality. Repeating the code disables it. Key repeats and releases do not count; another letter resets the sequence. A notification confirms the new state. New runs start with immortality disabled. Immortality prevents death without changing stamina, battery or monster perception.

Visual acquisition enters alert for 0.5 seconds. The hunter stops and turns toward the last seen player position, then starts hunting. It cannot attack during the pause, and repeated perception or footsteps cannot reset or bypass the pause.

Original recordings from Downloads are preserved byte-for-byte in assets/audio/user_originals: startgame.mp3 plays on each run, danger.mp3 on visual detection (shared three-second cooldown), heartbeat.mp3 loops during alert/pursuit and fades out when both hunters disengage, screamer.mp3 plays on death. Every source uses Master and the existing building reflection/reverb effects.

The opening howl plays through a dedicated non-positional source at -16 dB so distant randomized spawns cannot make it inaudible. Subsequent howls keep spatial distance attenuation, variant exclusion and the shared 26–40 second schedule.

Validation: detection_audio_cheat_regression.gd covers toggling, repeated keys, interrupted codes, lethal hits, restart, event playback, heartbeat looping/fading, detection turning and timing, close-range grace and victory audio. Existing gameplay, chase, howl schedule, hearing and notice checks also run. No executable export was performed.
