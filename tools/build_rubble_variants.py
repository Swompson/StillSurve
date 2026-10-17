from pathlib import Path
import random
import math

target = Path(__file__).resolve().parents[1] / "assets/textures/rubble"
target.mkdir(parents=True, exist_ok=True)
for variant in range(4):
    rng = random.Random(603 + variant)
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="112" height="80" viewBox="-56 -40 112 80">']
    palettes = [('#73766b', '#4d5149'), ('#777263', '#535246'), ('#69716b', '#414d48'), ('#827b6c', '#55564b')]
    light, dark = palettes[variant]
    parts.append(f'<defs><linearGradient id="stone" x2=".5" y2="1"><stop stop-color="{light}"/><stop offset="1" stop-color="{dark}"/></linearGradient></defs>')
    for index in range(19):
        x, y = rng.uniform(-44, 44), rng.uniform(-24, 25)
        radius = rng.uniform(2, 7) if index < 14 else rng.uniform(10, 21)
        if index >= 14:
            x, y = (index - 16) * 15 + rng.uniform(-8, 8), rng.uniform(-12, 12)
        count, rotation = rng.randint(5, 9), rng.uniform(0, math.tau)
        points = [(x + math.cos(rotation + a * math.tau / count) * radius * rng.uniform(.55, 1.25), y + math.sin(rotation + a * math.tau / count) * radius * rng.uniform(.45, .95)) for a in range(count)]
        polygon = ' '.join(f'{px:.1f},{py:.1f}' for px, py in points)
        shadow = ' '.join(f'{px+2:.1f},{py+4:.1f}' for px, py in points)
        parts.append(f'<polygon points="{shadow}" fill="#101612" opacity=".65"/><polygon points="{polygon}" fill="url(#stone)" stroke="#373f36" stroke-width=".7"/>')
        for face in range(count):
            a, b = points[face], points[(face + 1) % count]
            facet = f'{a[0]:.1f},{a[1]:.1f} {b[0]:.1f},{b[1]:.1f} {x:.1f},{y:.1f}'
            parts.append(f'<polygon points="{facet}" fill="{rng.choice(["#c0b8a1", "#202b22"])}" opacity="{rng.uniform(.05,.18):.2f}"/>')
        parts.append(f'<path d="M{points[0][0]:.1f} {points[0][1]:.1f}L{x:.1f} {y:.1f}L{points[3][0]:.1f} {points[3][1]:.1f}" fill="none" stroke="#30392f" stroke-width=".8"/>')
        for grain in range(18):
            gx, gy = x + rng.uniform(-.55, .55) * radius, y + rng.uniform(-.3, .3) * radius
            parts.append(f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="{rng.uniform(.25,.7):.2f}" fill="{rng.choice(["#b2afa0", "#252f27"])}" opacity=".35"/>')
    if variant % 2:
        parts.append('<path d="M-25 16Q-10 9 3 19T32 16" fill="none" stroke="#503f2d" stroke-width="2"/><path d="M-25 15Q-10 8 3 18T32 15" fill="none" stroke="#8b6844" stroke-width=".7"/>')
    parts.append('</svg>')
    (target / f"broken_concrete_{variant}.svg").write_text(''.join(parts), encoding='utf-8')
print('Saved four textured concrete rubble variants')
