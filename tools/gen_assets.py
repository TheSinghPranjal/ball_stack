"""Generates every original 2D/audio asset for Ball Game : Fire Ball.

All assets are created procedurally here (no third-party art or audio).
Run: python3 tools/gen_assets.py
3D geometry is procedural at runtime (lib/core/render3d/mesh_factory.dart) and therefore not generated here.
"""
import json
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
A = os.path.join(ROOT, 'assets')
FONT = '/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'
SR = 32000

manifest = []


def add(name, path, fmt, dims, usage, deps=None, priority='normal'):
    manifest.append({'name': name, 'path': os.path.relpath(path, ROOT), 'format': fmt, 'dimensions': dims,
                     'usage': usage, 'dependencies': deps or [], 'loadingPriority': priority})


# ---------------------------------------------------------------- images

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def gradient(size, top, bottom):
    w, h = size
    img = Image.new('RGBA', size)
    px = img.load()
    for y in range(h):
        c = lerp(top, bottom, y / max(1, h - 1))
        for x in range(w):
            px[x, y] = c
    return img


def glossy_ball(d, color, hi=(255, 255, 255)):
    s = d * 4
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    cx = cy = s / 2
    r = s / 2 - 2
    nx = (xx - cx) / r
    ny = (yy - cy) / r
    rr = nx * nx + ny * ny
    mask = rr <= 1
    nz = np.sqrt(np.clip(1 - rr, 0, 1))
    L = np.array([-0.45, -0.6, 0.66])
    L /= np.linalg.norm(L)
    diff = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    H = L + np.array([0, 0, 1.0])
    H /= np.linalg.norm(H)
    spec = np.clip(nx * H[0] + ny * H[1] + nz * H[2], 0, 1) ** 40
    base = np.array(color, np.float32) / 255
    rgb = base[None, None, :] * (0.35 + 0.75 * diff[..., None]) + spec[..., None] * 0.95
    rim = (1 - nz) ** 3
    rgb += rim[..., None] * 0.25 * base[None, None, :]
    rgb = np.clip(rgb, 0, 1)
    arr = np.zeros((s, s, 4), np.uint8)
    arr[..., :3] = (rgb * 255).astype(np.uint8)
    arr[..., 3] = (mask * 255).astype(np.uint8)
    return Image.fromarray(arr).resize((d, d), Image.LANCZOS)


def draw_mini_tower(img, cx, top, bottom, rx, ry, colors, danger=(255, 46, 99)):
    d = ImageDraw.Draw(img)
    # pillar
    pw = rx * 0.28
    d.rounded_rectangle([cx - pw, top - ry, cx + pw, bottom], radius=int(pw), fill=(245, 240, 255, 255))
    y = top
    i = 0
    while y <= bottom - ry:
        col = colors[i % len(colors)]
        dark = lerp(col, (20, 10, 40), 0.35)
        # thickness
        d.ellipse([cx - rx, y - ry + ry * 0.45, cx + rx, y + ry + ry * 0.45], fill=dark)
        d.ellipse([cx - rx, y - ry, cx + rx, y + ry], fill=col)
        # gap wedge
        start = 40 + i * 70
        d.pieslice([cx - rx - 2, y - ry - 2, cx + rx + 2, y + ry + 6], start, start + 55, fill=(0, 0, 0, 0))
        if i % 2 == 1:
            d.pieslice([cx - rx, y - ry, cx + rx, y + ry], start + 150, start + 185, fill=danger)
        y += ry * 3.2
        i += 1


def logo():
    W, H = 1400, 640
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    f1 = ImageFont.truetype(FONT, 150)
    f2 = ImageFont.truetype(FONT, 215)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for text, font, y in [('BALL GAME', f1, 95), ('FIRE BALL', f2, 300)]:
        bbox = d.textbbox((0, 0), text, font=font)
        x = (W - (bbox[2] - bbox[0])) / 2
        # 3D extrusion
        for k in range(18, 0, -1):
            d.text((x + k * 0.6, y + k), text, font=font, fill=(40, 18, 90, 255), stroke_width=22,
                   stroke_fill=(40, 18, 90, 255))
        d.text((x, y), text, font=font, fill=(255, 255, 255, 255), stroke_width=22, stroke_fill=(255, 255, 255, 255))
        # gradient fill via mask
        mask = Image.new('L', (W, H), 0)
        ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
        grad = gradient((W, H), (110, 220, 255, 255), (150, 90, 255, 255)) if text == 'BALL GAME' else \
            gradient((W, H), (255, 236, 90, 255), (255, 60, 30, 255))
        layer.paste(grad, (0, 0), mask)
        # glossy top highlight
        hl = Image.new('L', (W, H), 0)
        ImageDraw.Draw(hl).text((x, y), text, font=font, fill=110)
        hl = Image.composite(hl, Image.new('L', (W, H), 0),
                             Image.fromarray(((np.mgrid[0:H, 0:W][0] < y + 110) * 255).astype(np.uint8)))
        layer.paste(Image.new('RGBA', (W, H), (255, 255, 255, 255)), (0, 0), hl)
    shadow = layer.split()[3].filter(ImageFilter.GaussianBlur(18))
    sh = Image.new('RGBA', (W, H), (10, 5, 30, 0))
    sh.putalpha(shadow.point(lambda v: int(v * 0.6)))
    img = Image.alpha_composite(img, sh)
    img = Image.alpha_composite(img, layer)
    ball = glossy_ball(150, (255, 110, 40))
    img.alpha_composite(ball, (W - 190, 10))
    out = os.path.join(A, 'images', 'logo', 'logo.png')
    img = img.resize((W // 2 * 1, H // 2 * 1), Image.LANCZOS)
    img.save(out, optimize=True)
    add('logo', out, 'png', f'{img.width}x{img.height}', 'Splash + home title logo', priority='critical')


def app_icon():
    S = 1024
    img = gradient((S, S), (66, 40, 160, 255), (20, 12, 56, 255))
    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([200, 160, 820, 780], fill=(255, 120, 200, 110))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(120)))
    tower = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    draw_mini_tower(tower, S / 2, 400, 1000, 340, 80,
                    [(255, 180, 70), (62, 230, 176), (177, 140, 255), (79, 195, 255)])
    img = Image.alpha_composite(img, tower)
    ball = glossy_ball(240, (255, 90, 122))
    img.alpha_composite(ball, (S // 2 - 120, 120))
    out = os.path.join(A, 'images', 'icons', 'app_icon.png')
    rgb = img.convert('RGB')
    rgb.save(out)
    add('app_icon', out, 'png', '1024x1024', 'Store/launcher icon source', priority='build-time')
    # platform icons
    res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
    for folder, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        p = os.path.join(res, f'mipmap-{folder}', 'ic_launcher.png')
        if os.path.isdir(os.path.dirname(p)):
            rgb.resize((px, px), Image.LANCZOS).save(p)
    ios = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    if os.path.isdir(ios):
        for name in os.listdir(ios):
            if name.endswith('.png'):
                sz = name.split('-')[-1].replace('.png', '')  # e.g. 20x20@2x
                base, scale = sz.split('@')
                px = round(float(base.split('x')[0]) * int(scale[0]))
                rgb.resize((px, px), Image.LANCZOS).save(os.path.join(ios, name))


def ui_icons():
    # coin icon
    S = 256
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 18, 248, 252], fill=(196, 128, 0, 255))
    d.ellipse([8, 4, 248, 238], fill=(255, 212, 71, 255))
    d.ellipse([40, 34, 216, 208], fill=(255, 186, 30, 255))
    d.ellipse([52, 44, 204, 196], fill=(255, 222, 100, 255))
    f = ImageFont.truetype(FONT, 120)
    d.text((128, 122), 'S', font=f, fill=(214, 140, 0, 255), anchor='mm')
    d.ellipse([60, 30, 120, 70], fill=(255, 255, 255, 140))
    out = os.path.join(A, 'images', 'icons', 'coin.png')
    img.resize((128, 128), Image.LANCZOS).save(out)
    add('coin_icon', out, 'png', '128x128', 'Coin badge, rewards, prices', priority='critical')
    # star
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(10):
        r = 118 if i % 2 == 0 else 52
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((128 + r * math.cos(a), 136 + r * math.sin(a)))
    d.polygon([(x, y + 10) for x, y in pts], fill=(196, 128, 0, 255))
    d.polygon(pts, fill=(255, 212, 71, 255))
    out = os.path.join(A, 'images', 'icons', 'star.png')
    img.resize((128, 128), Image.LANCZOS).save(out)
    add('star_icon', out, 'png', '128x128', 'Level stars, level complete', priority='normal')
    # shield
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(128, 10), (232, 50), (220, 150), (128, 246), (36, 150), (24, 50)], fill=(30, 120, 220, 255))
    d.polygon([(128, 34), (208, 64), (198, 146), (128, 218), (58, 146), (48, 64)], fill=(79, 195, 255, 255))
    d.polygon([(128, 34), (208, 64), (128, 128)], fill=(140, 220, 255, 255))
    out = os.path.join(A, 'images', 'icons', 'shield.png')
    img.resize((128, 128), Image.LANCZOS).save(out)
    add('shield_icon', out, 'png', '128x128', 'Shield booster', priority='normal')
    # gift (daily)
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([30, 100, 226, 240], 18, fill=(255, 90, 122, 255))
    d.rounded_rectangle([18, 70, 238, 120], 14, fill=(255, 120, 150, 255))
    d.rectangle([110, 70, 146, 240], fill=(255, 212, 71, 255))
    d.ellipse([60, 20, 128, 80], outline=(255, 212, 71, 255), width=18)
    d.ellipse([128, 20, 196, 80], outline=(255, 212, 71, 255), width=18)
    out = os.path.join(A, 'images', 'icons', 'gift.png')
    img.resize((128, 128), Image.LANCZOS).save(out)
    add('gift_icon', out, 'png', '128x128', 'Daily reward', priority='normal')
    # victory / failure illustrations
    for name, col, glyph in [('victory', (62, 230, 176), 'trophy'), ('failure', (255, 46, 99), 'crack')]:
        S2 = 384
        img = Image.new('RGBA', (S2, S2), (0, 0, 0, 0))
        glow = Image.new('RGBA', (S2, S2), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([40, 40, 344, 344], fill=col + (150,))
        img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(40)))
        ball = glossy_ball(220, col)
        img.alpha_composite(ball, (82, 82))
        d = ImageDraw.Draw(img)
        if glyph == 'crack':
            d.line([(150, 110), (190, 180), (160, 220), (210, 290)], fill=(40, 10, 30, 255), width=12)
            d.line([(190, 180), (240, 170)], fill=(40, 10, 30, 255), width=9)
        else:
            f = ImageFont.truetype(FONT, 150)
            d.text((192, 196), '★', font=ImageFont.truetype('/System/Library/Fonts/Apple Symbols.ttf', 170)
                   if os.path.exists('/System/Library/Fonts/Apple Symbols.ttf') else f, fill=(255, 255, 255, 235),
                   anchor='mm')
        out = os.path.join(A, 'images', 'ui', f'{name}.png')
        img.resize((256, 256), Image.LANCZOS).save(out)
        add(f'{name}_illustration', out, 'png', '256x256', f'{name} overlay hero image', priority='normal')


# ---------------------------------------------------------------- audio

def env(n, a=0.004, r=None, curve=4.0):
    t = np.linspace(0, 1, n, endpoint=False)
    att = np.clip(np.arange(n) / max(1, int(a * SR)), 0, 1)
    return att * (1 - t) ** curve


def tone(freq0, freq1, dur, kind='sine', vol=0.6, curve=3.0):
    n = int(dur * SR)
    f = np.geomspace(max(freq0, 1), max(freq1, 1), n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if kind == 'sine':
        w = np.sin(ph)
    elif kind == 'tri':
        w = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == 'square':
        w = np.sign(np.sin(ph)) * 0.6
    else:
        w = 2 * ((ph / (2 * np.pi)) % 1) - 1
    return w * env(n, curve=curve) * vol


def noise(dur, vol=0.5, lp=0.2, curve=3):
    n = int(dur * SR)
    rng = np.random.default_rng(7)
    x = rng.uniform(-1, 1, n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += lp * (x[i] - acc)
        y[i] = acc
    y /= max(1e-6, np.abs(y).max())
    return y * env(n, curve=curve) * vol


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def delay(x, sec):
    pad = np.zeros(int(sec * SR))
    return np.concatenate([pad, x])


def write(name, x, usage, folder='sfx', priority='critical'):
    x = np.asarray(x, np.float64)
    peak = np.abs(x).max()
    if peak > 0.95:
        x = x / peak * 0.95
    fade = min(len(x), int(0.004 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    path = os.path.join(A, 'audio', folder, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    add(name, path, 'wav (PCM16 mono 32 kHz)', f'{len(x) / SR:.2f}s', usage, priority=priority)


def audio():
    write('bounce', mix(tone(420, 180, 0.14, 'sine', 0.8, 5), noise(0.03, 0.15, 0.5, 6)), 'Ball bounces on platform')
    write('land', mix(tone(160, 70, 0.22, 'sine', 0.9, 4), noise(0.08, 0.3, 0.12, 5)), 'Ball lands on base')
    notes = [0, 2, 4, 7, 9, 12, 14, 16]
    for i, semi in enumerate(notes):
        f = 523.25 * 2 ** (semi / 12)
        write(f'pass_{i + 1}', mix(tone(f, f * 1.02, 0.16, 'tri', 0.45, 3), tone(f * 2, f * 2, 0.08, 'sine', 0.15, 4)),
              f'Floor passed, combo step {i + 1}')
    write('break', mix(noise(0.35, 0.8, 0.35, 2.5), tone(220, 60, 0.3, 'sine', 0.5, 3)), 'Platform shatter')
    write('smash', mix(noise(0.5, 0.9, 0.25, 2), tone(140, 40, 0.45, 'sine', 0.9, 2.5),
                       delay(tone(880, 1760, 0.18, 'tri', 0.25, 3), 0.02)), 'Smash through a floor')
    write('fireball', mix(tone(200, 900, 0.5, 'saw', 0.25, 1.5), noise(0.6, 0.35, 0.08, 1.5),
                          delay(tone(660, 1320, 0.3, 'tri', 0.3, 2), 0.15)), 'Fireball / smash mode activation')
    arp = [mix(delay(tone(523 * 2 ** (s / 12), 523 * 2 ** (s / 12), 0.14, 'tri', 0.4, 3), k * 0.06))
           for k, s in enumerate([0, 4, 7, 12])]
    write('combo', mix(*arp), 'Combo milestone')
    write('coin', mix(tone(1318, 1318, 0.08, 'square', 0.25, 3), delay(tone(1760, 1760, 0.22, 'square', 0.25, 3), 0.07)),
          'Coin collected / reward')
    write('click', mix(tone(900, 700, 0.05, 'sine', 0.5, 6), noise(0.01, 0.1, 0.6, 5)), 'UI button press')
    write('near_miss', mix(tone(1200, 1500, 0.12, 'sine', 0.3, 2), delay(tone(1500, 1800, 0.12, 'sine', 0.25, 2), 0.06)),
          'Close-call bonus')
    fan = [delay(tone(392 * 2 ** (s / 12), 392 * 2 ** (s / 12), 0.5 if k == 4 else 0.18, 'tri', 0.45, 2), k * 0.11)
           for k, s in enumerate([0, 4, 7, 12, 16])]
    write('level_complete', mix(*fan, delay(noise(0.6, 0.15, 0.05, 2), 0.44)), 'Level complete fanfare')
    write('game_over', mix(tone(440, 110, 0.7, 'saw', 0.35, 1.6), noise(0.4, 0.5, 0.3, 3),
                           delay(tone(330, 82, 0.6, 'tri', 0.3, 2), 0.12)), 'Ball shatters / game over')
    write('shield', mix(tone(600, 1200, 0.25, 'tri', 0.4, 2), delay(tone(900, 1800, 0.2, 'sine', 0.3, 2), 0.08)),
          'Shield absorbs a hazard')
    music()


def music():
    bpm = 112
    beat = 60 / bpm
    bars = 8
    total = int(bars * 4 * beat * SR)
    out = np.zeros(total + SR)
    prog = [(0, [0, 4, 7]), (-3, [0, 3, 7]), (-7, [0, 4, 7]), (-5, [0, 4, 7])] * 2  # I vi IV V in C
    root = 261.63
    for bar, (r, chord) in enumerate(prog):
        t0 = bar * 4 * beat
        # bass
        for b in range(4):
            f = root / 4 * 2 ** (r / 12)
            s = tone(f, f, beat * 0.9, 'tri', 0.35, 1.2)
            i = int((t0 + b * beat) * SR)
            out[i:i + len(s)] += s
        # arpeggio 8ths
        for k in range(8):
            semi = r + chord[k % 3] + (12 if k >= 4 else 0)
            f = root * 2 ** (semi / 12)
            s = mix(tone(f, f, beat * 0.45, 'tri', 0.12, 2.5), tone(f * 2, f * 2, beat * 0.3, 'sine', 0.04, 3))
            i = int((t0 + k * beat / 2) * SR)
            out[i:i + len(s)] += s
        # pad
        for semi in chord:
            f = root * 2 ** ((r + semi) / 12)
            n = int(4 * beat * SR)
            tt = np.arange(n) / SR
            pad = np.sin(2 * np.pi * f * tt) * 0.035 * np.sin(np.pi * np.arange(n) / n)
            i = int(t0 * SR)
            out[i:i + n] += pad
        # drums
        for b in range(4):
            i = int((t0 + b * beat) * SR)
            k = tone(120, 45, 0.18, 'sine', 0.55, 3)
            out[i:i + len(k)] += k
            hh = noise(0.05, 0.08, 0.9, 6)
            j = int((t0 + b * beat + beat / 2) * SR)
            out[j:j + len(hh)] += hh
            if b % 2 == 1:
                sn = noise(0.15, 0.22, 0.45, 3)
                out[i:i + len(sn)] += sn
    out = out[:total]
    write('music_loop', out, 'Background music (seamless 8-bar loop)', folder='music', priority='deferred')


if __name__ == '__main__':
    for sub in ['images/logo', 'images/icons', 'images/ui', 'images/backgrounds', 'audio/sfx', 'audio/music']:
        os.makedirs(os.path.join(A, sub), exist_ok=True)
    logo()
    app_icon()
    ui_icons()
    audio()
    procedural = [
        ('ball_mesh', 'lib/core/render3d/mesh_factory.dart#sphere', 'procedural mesh', 'UV sphere r=0.3, 10-24 stacks by quality', 'Player ball (all skins)'),
        ('platform_segment_mesh', 'lib/features/gameplay/engine/platform_controller.dart', 'procedural mesh', 'annular wedge 22.5°, r 0.8-2.6, h 0.45', 'Safe/danger/breakable/bonus/blink segments'),
        ('pillar_mesh', 'lib/features/gameplay/engine/platform_controller.dart', 'procedural mesh', 'cylinder r=0.72 per floor', 'Central tower column'),
        ('sweeper_mesh', 'lib/features/gameplay/engine/platform_controller.dart', 'procedural mesh', 'arc arm 28°', 'Rotating hazard'),
        ('base_mesh', 'lib/features/gameplay/engine/platform_controller.dart', 'procedural mesh', 'disc r=3.2', 'Finish platform'),
        ('fragment_mesh', 'lib/features/gameplay/engine/destruction_system.dart', 'procedural mesh', 'wedge shard', 'Destruction debris (pooled)'),
        ('skins', 'lib/features/shop/data/skin_catalog.dart', 'material definitions', '8 skins', 'Ball materials and trails'),
        ('themes', 'lib/app/theme/colors.dart', 'palette definitions', '6 themes', 'Environment + platform colours'),
    ]
    for name, path, fmt, dims, usage in procedural:
        manifest.append({'name': name, 'path': path, 'format': fmt, 'dimensions': dims, 'usage': usage,
                         'dependencies': [], 'loadingPriority': 'runtime-generated'})
    with open(os.path.join(A, 'asset_manifest.json'), 'w') as f:
        json.dump({'game': 'Ball Game : Fire Ball', 'generatedBy': 'tools/gen_assets.py', 'assets': manifest}, f, indent=2)
    print(len(manifest), 'assets written')
