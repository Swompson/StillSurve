"""Irregular throaty snarls, ragged inhalations and quiet room echoes."""
from array import array
from pathlib import Path
import math
import random
import wave

rate = 24000
rng = random.Random(741)
duration = 3.4
samples = []
phase = low = air = previous = 0.0
resonators = [(530, 125, 0.0, 0.0), (1380, 210, 0.0, 0.0), (2410, 330, 0.0, 0.0)]
for index in range(int(rate * duration)):
    time = index / rate
    noise = rng.uniform(-1, 1)
    low += .025 * (noise - low)
    air += .24 * (noise - air)
    first = math.exp(-((time - .58) / .27) ** 2)
    second = math.exp(-((time - 1.34) / .22) ** 2)
    third = math.exp(-((time - 2.05) / .38) ** 2)
    inhale = math.exp(-((time - 2.8) / .24) ** 2)
    envelope = .8 * first + .65 * second + third
    frequency = 87 + 19 * math.sin(time * 7.1) + 9 * math.sin(time * 29) + 25 * low
    phase += math.tau * frequency / rate
    pulse = max(0, math.sin(phase)) ** 9 - .12
    irregular = .55 + .45 * math.sin(time * 67 + 4 * math.sin(time * 13)) ** 2
    excitation = (pulse * .45 + air * .9) * irregular
    voice = 0.0
    for number, (center, bandwidth, y1, y2) in enumerate(resonators):
        radius = math.exp(-math.pi * bandwidth / rate)
        value = (1 - radius) * excitation + 2 * radius * math.cos(math.tau * center / rate) * y1 - radius * radius * y2
        resonators[number] = (center, bandwidth, value, y1)
        voice += value * (1, .65, .3)[number]
    output = math.tanh(voice * 4) * envelope + .22 * air * inhale
    previous += .4 * (output - previous)
    fade = min(1, time / .12) * min(1, (duration - time) / .25)
    samples.append(previous * fade)
original = samples.copy()
for delay, gain in ((.13, .17), (.27, .10), (.43, .06)):
    offset = int(delay * rate)
    for index in range(offset, len(samples)):
        samples[index] += original[index - offset] * gain
peak = max(abs(value) for value in samples)
pcm = array('h', (round(value / peak * .58 * 32767) for value in samples))
path = Path(__file__).resolve().parents[1] / 'assets/audio/monster/nearby_growl.wav'
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as sound:
    sound.setnchannels(1)
    sound.setsampwidth(2)
    sound.setframerate(rate)
    sound.writeframes(pcm.tobytes())
