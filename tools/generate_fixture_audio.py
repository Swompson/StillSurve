"""Create shared dry ballast, failed-contact and arc recordings for fixtures.

Room reflections are applied by the game's Master bus, never baked into clips.
The deterministic source stays in the project for regeneration.
"""
from pathlib import Path
import math
import random
import struct
import wave

DESTINATION = Path(__file__).resolve().parents[1] / "assets/audio/fixtures"
RATE = 22050


def save(name, samples):
    DESTINATION.mkdir(parents=True, exist_ok=True)
    peak = max(abs(value) for value in samples) or 1.0
    gain = min(1.0, 0.84 / peak)
    with wave.open(str(DESTINATION / name), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(struct.pack("<h", round(value * gain * 32767)) for value in samples))


def hum():
    # All oscillators complete integer cycles for a seamless loop.
    samples = []
    for index in range(RATE * 4):
        time = index / RATE
        flutter = 0.92 + 0.055 * math.sin(math.tau * 0.5 * time) + 0.025 * math.sin(math.tau * 1.25 * time)
        body = (0.23 * math.sin(math.tau * 100 * time)
                + 0.10 * math.sin(math.tau * 200 * time + 0.4)
                + 0.050 * math.sin(math.tau * 300 * time + 0.7)
                + 0.022 * math.sin(math.tau * 600 * time))
        thin_buzz = 0.012 * math.sin(math.tau * 1200 * time + 0.35 * math.sin(math.tau * 50 * time))
        samples.append(body * flutter + thin_buzz)
    return samples


def contacts(arcing=False):
    rng = random.Random(10620 if arcing else 10619)
    duration = 0.42 if arcing else 0.25
    bursts = [(0.012, 0.8), (0.061, 0.54), (0.139, 0.4), (0.218, 0.25)] if arcing else [(0.012, 0.36), (0.079, 0.22)]
    samples = []
    low_noise = 0.0
    for index in range(round(RATE * duration)):
        time = index / RATE
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.31 * (noise - low_noise)
        value = 0.0
        for delay, gain in bursts:
            age = time - delay
            if age < 0:
                continue
            attack = min(age / 0.0018, 1.0)
            envelope = attack * math.exp(-age * (45.0 if arcing else 80.0))
            texture = (noise - low_noise) * 0.65 + low_noise * 0.35 if arcing else low_noise
            resonance = math.sin(math.tau * (740 if arcing else 430) * age) * math.exp(-age * 95.0)
            value += gain * envelope * (texture + 0.12 * resonance)
        value += 0.025 * math.sin(math.tau * 100 * time) * math.exp(-time * 15.0) * min(time / 0.004, 1.0)
        samples.append(value)
    return samples


if __name__ == "__main__":
    save("ballast_hum.wav", hum())
    save("contact_flicker.wav", contacts())
    save("electrical_arc.wav", contacts(arcing=True))
    print("Created three shared mono fixture sounds at 22050 Hz")
