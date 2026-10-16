"""Soft boot contacts, voiced breath cycles and one seamless abandoned-building bed."""
from pathlib import Path
from array import array
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 24000


def save(relative, channels, peak):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    maximum = max(max(abs(x) for x in channel) for channel in channels)
    gain = peak / max(maximum, 1e-6)
    pcm = array('h')
    for index in range(len(channels[0])):
        for channel in channels:
            pcm.append(round(max(-.98, min(.98, channel[index] * gain)) * 32767))
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(len(channels))
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


for variant in range(6):
    rng = random.Random(3310 + variant)
    duration = rng.uniform(.29, .34)
    samples = []
    low = mid = output = 0.0
    for n in range(int(duration * RATE)):
        t = n / RATE
        noise = rng.uniform(-1, 1)
        low += .025 * (noise - low)
        mid += .12 * (noise - mid)
        # A rounded sole landing, with an 11ms attack instead of a sharp click.
        attack = (1 - math.exp(-t / .011))**2
        body = 2.6 * low * math.exp(-t / .045)
        sole = .13 * mid * math.exp(-t / .07)
        output += .2 * (body + sole - output)
        fade = min(1, (duration - t) / .045)
        samples.append(output * attack * fade)
    save(f'assets/audio/footsteps/boot_concrete_{variant+1:02}.wav', [samples], .38)


class Formant:
    def __init__(self, frequency, bandwidth):
        self.r = math.exp(-math.pi * bandwidth / RATE)
        self.a = 2 * self.r * math.cos(math.tau * frequency / RATE)
        self.b = self.r * self.r
        self.y1 = self.y2 = 0.0

    def sample(self, value):
        output = (1 - self.r) * value + self.a * self.y1 - self.b * self.y2
        self.y2, self.y1 = self.y1, output
        return output


for tired in (False, True):
    rng = random.Random(2558 + tired)
    duration = 1.5 if tired else 1.45
    formants = [Formant(480, 155), Formant(1120, 240), Formant(1850, 380)]
    smooth = air = low = 0.0
    samples = []
    phase = 0.0
    for n in range(int(duration * RATE)):
        t = n / RATE
        noise = rng.uniform(-1, 1)
        air += .16 * (noise - air)
        low += .028 * (noise - low)
        inhale = math.exp(-((t - .31) / .19)**2)
        exhale = math.exp(-((t - .97) / .28)**2)
        frequency = 102 + 6 * math.sin(t * 4) + (4 if tired else 0)
        phase += math.tau * frequency / RATE
        # A faint chest/natural vocal component plus aspirated, formant-shaped air.
        voice = (.6 * math.sin(phase) + .18 * math.sin(phase * 2) + .06 * math.sin(phase * 3))
        excitation = .58 * air + voice * (.07 if tired else .04) * exhale
        shaped = .55 * formants[0].sample(excitation) + .3 * formants[1].sample(excitation) + .15 * formants[2].sample(excitation)
        texture = .65 * shaped + .07 * low
        envelope = .45 * inhale + (.95 if tired else .65) * exhale
        smooth += .26 * (texture * envelope - smooth)
        fade = min(1, t / .07) * min(1, (duration-t) / .1)
        samples.append(smooth * fade)
    name = 'exhausted_breath' if tired else 'running_breath'
    save(f'assets/audio/breathing/{name}.wav', [samples], .32 if tired else .25)

# One restrained stereo ambient loop: low air, distant structure hum and room rumble.
rng = random.Random(9816)
duration = 33.0
count = int(RATE * duration)
left, right = array('f'), array('f')
low_l = low_r = deep_l = deep_r = 0.0
for n in range(count):
    t = n / RATE
    low_l += .011 * (rng.uniform(-1, 1) - low_l)
    low_r += .011 * (rng.uniform(-1, 1) - low_r)
    deep_l += .0015 * (low_l - deep_l)
    deep_r += .0015 * (low_r - deep_r)
    swell = .7 + .17 * math.sin(math.tau*t/duration) + .1 * math.sin(math.tau*3*t/duration + .7)
    hum = .027*math.sin(math.tau*43.03125*t) + .013*math.sin(math.tau*64.0625*t + .8)
    distant = .009 * math.sin(math.tau*98.09375*t + .1 * math.sin(math.tau*t/duration))
    left.append(swell * (1.8*deep_l + .2*low_l + hum + distant))
    right.append(swell * (1.8*deep_r + .2*low_r + .92*hum - .7*distant))
# Overlap the last and first seconds, then keep 32 seconds. The loop boundary
# joins consecutive original samples rather than forcing a one-sample jump.
blend = RATE
for channel in (left, right):
    for n in range(blend):
        weight = n / (blend - 1)
        index = count - blend + n
        channel[n] = channel[index]*(1-weight) + channel[n]*weight
    del channel[count-blend:]
save('assets/audio/ambience/abandoned_building.wav', [left, right], .32)
