"""Generate warm damped switch taps with a low-pass mechanical texture."""
from pathlib import Path
import math
import random
import struct
import wave

DESTINATION = Path(__file__).resolve().parents[1] / "assets/audio/flashlight"
DESTINATION.mkdir(parents=True, exist_ok=True)
RATE = 44100
for enabled in (True, False):
    rng = random.Random(2002 if enabled else 2003)
    samples = []
    filtered_noise = 0.0
    for index in range(int(RATE * 0.24)):
        time = index / RATE
        sample = 0.0
        filtered_noise += 0.065 * (rng.uniform(-1, 1) - filtered_noise)
        for delay, gain in ((0.0, 0.65), (0.046 if enabled else 0.057, 0.17)):
            t = time - delay
            if t < 0:
                continue
            attack = min(t / 0.006, 1.0)
            envelope = (0.5 - 0.5 * math.cos(math.pi * attack)) * math.exp(-t * 60)
            resonance = math.sin(math.tau * (310 if enabled else 245) * t) * math.exp(-t * 45)
            sample += gain * envelope * (0.72 * filtered_noise + 0.28 * resonance)
        samples.append(struct.pack("<h", int(max(-1, min(1, sample)) * 28000)))
    with wave.open(str(DESTINATION / ("switch_on.wav" if enabled else "switch_off.wav")), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(samples))
