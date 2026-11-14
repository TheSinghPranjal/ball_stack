"""Generates low-fidelity wireframes for every screen into docs/wireframes/.

Run: python3 tools/gen_wireframes.py
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), '..', 'docs', 'wireframes')
W, H = 390, 844
S = 2  # supersample
INK = (40, 44, 60)
MID = (150, 156, 175)
LIGHT = (228, 231, 240)
ACCENT = (255, 122, 69)
BG = (250, 250, 253)


def font(size, bold=False):
    for p in ['/System/Library/Fonts/SFNSRounded.ttf', '/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf',
              '/System/Library/Fonts/Helvetica.ttc']:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size * S)
            except Exception:
                pass
    return ImageFont.load_default()


class WF:
    def __init__(self, title):
        self.img = Image.new('RGB', (W * S, H * S), BG)
        self.d = ImageDraw.Draw(self.img)
        self.title = title
        # safe areas
        self.box(0, 0, W, 47, fill=LIGHT, outline=None)
        self.text(W / 2, 24, 'status bar / notch (safe area)', 10, MID, anchor='mm')
        self.box(0, H - 34, W, H, fill=LIGHT, outline=None)
        self.text(W / 2, H - 17, 'home indicator (safe area)', 10, MID, anchor='mm')

    def r(self, *v):
        return [x * S for x in v]

    def box(self, x0, y0, x1, y1, fill=None, outline=INK, radius=12, width=2, dash=False):
        self.d.rounded_rectangle(self.r(x0, y0, x1, y1), radius * S, fill=fill, outline=outline, width=width * S)

    def text(self, x, y, t, size=14, color=INK, anchor='la', bold=False):
        self.d.text((x * S, y * S), t, fill=color, font=font(size, bold), anchor=anchor)

    def button(self, x0, y0, x1, y1, label, primary=False, size=16):
        self.box(x0, y0, x1, y1, fill=ACCENT if primary else (255, 255, 255), outline=INK, radius=(y1 - y0) / 2)
        self.text((x0 + x1) / 2, (y0 + y1) / 2, label, size, (255, 255, 255) if primary else INK, 'mm')

    def icon_btn(self, cx, cy, label, r=22):
        self.d.ellipse(self.r(cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255), outline=INK, width=2 * S)
        self.text(cx, cy, label, 12, INK, 'mm')

    def tower(self, cx, top, bottom, rx=95, ball=True):
        self.box(cx - 14, top, cx + 14, bottom, fill=LIGHT, radius=6)
        y = top + 20
        i = 0
        while y < bottom - 10:
            gap = (i * 70) % 360
            self.d.arc(self.r(cx - rx, y - 16, cx + rx, y + 16), 200 + gap * 0.1, 160 + 360, fill=INK, width=6 * S)
            self.d.arc(self.r(cx - rx, y - 16, cx + rx, y + 16), 20 + i * 25, 60 + i * 25, fill=BG, width=8 * S)
            if i % 3 == 2:
                self.d.arc(self.r(cx - rx, y - 16, cx + rx, y + 16), 100, 125, fill=ACCENT, width=7 * S)
            y += 70
            i += 1
        if ball:
            by = top + 6
            self.d.ellipse(self.r(cx - 12, by - 12 - 20, cx + 12, by + 12 - 20), fill=(90, 120, 255), outline=INK, width=2 * S)

    def note(self, x, y, t):
        self.text(x, y, '> ' + t, 10, (120, 90, 200))

    def save(self, name):
        self.text(16, 24, self.title.upper(), 11, INK, 'lm')
        img = self.img.resize((W, H), Image.LANCZOS)
        img.save(os.path.join(OUT, name))


def splash():
    w = WF('splash')
    w.tower(W / 2, 250, 560)
    w.box(70, 150, 320, 220, fill=(255, 255, 255))
    w.text(W / 2, 185, 'BALL GAME : FIRE BALL logo', 20, INK, 'mm')
    w.box(95, 640, 295, 654, fill=LIGHT, radius=7)
    w.box(95, 640, 210, 654, fill=ACCENT, radius=7)
    w.text(W / 2, 675, 'Building tower… 58%', 12, MID, 'mm')
    w.note(20, 590, 'live 3D: rotating tower + bouncing ball')
    w.note(20, 700, 'auto-advance to Home when assets + profile loaded')
    w.save('splash.png')


def home():
    w = WF('home')
    w.box(16, 64, 130, 98, fill=(255, 255, 255), radius=17)
    w.text(30, 81, '● 1,240', 14, INK, 'lm')
    w.icon_btn(300, 81, 'SND')
    w.icon_btn(352, 81, 'SET')
    w.box(55, 120, 335, 190, fill=(255, 255, 255))
    w.text(W / 2, 155, 'FIRE BALL', 24, INK, 'mm')
    w.tower(W / 2, 230, 520)
    w.box(90, 528, 300, 562, fill=(255, 255, 255), radius=17)
    w.text(W / 2, 545, 'SPIN  |  SMASH   (control mode)', 12, INK, 'mm')
    w.text(W / 2, 585, 'LEVEL 12   ·   BEST 4,380', 14, INK, 'mm')
    w.button(70, 610, 320, 676, 'PLAY', primary=True, size=26)
    w.icon_btn(105, 730, 'Balls', 30)
    w.icon_btn(195, 730, 'Levels', 30)
    w.icon_btn(285, 730, 'Daily', 30)
    w.note(20, 210, 'animated 3D background (attract mode)')
    w.save('home.png')


def level_select():
    w = WF('level selection')
    w.icon_btn(40, 81, '<')
    w.text(W / 2, 81, 'LEVELS', 20, INK, 'mm')
    w.box(270, 66, 374, 96, fill=(255, 255, 255), radius=15)
    w.text(322, 81, '● 1,240', 12, INK, 'mm')
    w.text(20, 118, '1–20  ·  Sunset Soda', 12, MID)
    n = 1
    for row in range(6):
        for col in range(4):
            x = 26 + col * 88
            y = 145 + row * 102
            locked = n > 13
            cur = n == 13
            w.box(x, y, x + 74, y + 84, fill=ACCENT if cur else ((236, 238, 244) if locked else (255, 255, 255)),
                  outline=INK, radius=16, width=3 if cur else 2)
            w.text(x + 37, y + 34, 'LOCK' if locked else str(n), 20, (255, 255, 255) if cur else INK, 'mm')
            if not locked and not cur:
                w.text(x + 37, y + 64, '* * -', 12, INK, 'mm')
            n += 1
    w.note(20, 770, 'scrollable grid, 300+ levels; tap unlocked → Game')
    w.save('level_selection.png')


def gameplay():
    w = WF('gameplay')
    w.icon_btn(36, 84, '| |')
    w.text(W / 2, 74, 'LEVEL 12', 13, MID, 'mm')
    w.text(W / 2, 100, '1,280', 30, INK, 'mm')
    w.box(286, 70, 374, 98, fill=(255, 255, 255), radius=14)
    w.text(330, 84, '● 42', 12, INK, 'mm')
    w.box(60, 124, 330, 136, fill=LIGHT, radius=6)
    w.box(60, 124, 170, 136, fill=ACCENT, radius=6)
    w.text(44, 130, '12', 10, INK, 'mm')
    w.text(346, 130, '13', 10, INK, 'mm')
    w.tower(W / 2, 200, 760)
    w.text(W / 2, 300, '×4 DROP', 24, ACCENT, 'mm')
    w.note(220, 340, 'combo / SMASH popups')
    w.box(80, 740, 310, 784, fill=(255, 255, 255), radius=22)
    w.text(W / 2, 762, '<  drag to spin  >', 14, INK, 'mm')
    w.note(16, 160, 'progress: floors passed / total')
    w.save('gameplay.png')


def overlay_base(title):
    w = WF(title)
    w.tower(W / 2, 200, 760, ball=False)
    ov = Image.new('RGBA', w.img.size, (20, 22, 40, 150))
    w.img.paste(ov, (0, 0), ov)
    w.d = ImageDraw.Draw(w.img)
    return w


def pause():
    w = overlay_base('pause')
    w.box(45, 220, 345, 640, fill=(255, 255, 255), radius=28)
    w.text(W / 2, 260, 'PAUSED', 26, INK, 'mm')
    w.button(80, 300, 310, 352, 'RESUME', primary=True)
    w.button(80, 366, 310, 412, 'RESTART')
    w.button(80, 426, 310, 472, 'HOME')
    for i, l in enumerate(['Music', 'Sound', 'Haptics']):
        x = 95 + i * 100
        w.box(x - 35, 505, x + 35, 585, fill=LIGHT, radius=16)
        w.text(x, 535, 'ON', 14, INK, 'mm')
        w.text(x, 565, l, 12, MID, 'mm')
    w.note(55, 610, 'world frozen; loop stopped')
    w.save('pause.png')


def game_over():
    w = overlay_base('game over')
    w.box(40, 170, 350, 700, fill=(255, 255, 255), radius=28)
    w.d.ellipse(w.r(155, 195, 235, 275), outline=INK, width=3 * S)
    w.text(W / 2, 235, 'X', 30, INK, 'mm')
    w.text(W / 2, 305, 'CRASHED!', 28, INK, 'mm')
    w.text(W / 2, 352, '1,280', 34, INK, 'mm')
    w.text(W / 2, 384, 'SCORE', 11, MID, 'mm')
    for i, (k, v) in enumerate([('BEST', '4,380'), ('MAX COMBO', '×6'), ('FLOORS', '23/40')]):
        x = 85 + i * 110
        w.text(x, 425, v, 18, INK, 'mm')
        w.text(x, 448, k, 10, MID, 'mm')
    w.button(70, 480, 320, 534, 'REVIVE  ● 60', primary=False)
    w.button(70, 548, 320, 604, 'RETRY', primary=True)
    w.button(70, 618, 320, 664, 'HOME')
    w.save('game_over.png')


def level_complete():
    w = overlay_base('level complete')
    w.box(40, 150, 350, 720, fill=(255, 255, 255), radius=28)
    w.text(W / 2, 200, '*  *  *', 40, ACCENT, 'mm')
    w.text(W / 2, 265, 'LEVEL 12 CLEAR!', 26, INK, 'mm')
    w.text(W / 2, 320, '3,940', 36, INK, 'mm')
    w.text(W / 2, 352, 'SCORE', 11, MID, 'mm')
    rows = [('Coins earned', '+ 157'), ('Combo bonus', '+ 6'), ('First clear', '+ 37')]
    for i, (k, v) in enumerate(rows):
        y = 395 + i * 34
        w.text(70, y, k, 14, INK, 'lm')
        w.text(320, y, '● ' + v, 14, INK, 'rm')
    w.button(70, 520, 320, 580, 'NEXT LEVEL  >', primary=True, size=18)
    w.button(70, 596, 320, 644, 'REPLAY')
    w.button(70, 656, 320, 700, 'HOME')
    w.note(48, 735, 'confetti + coin fly-to-counter animation')
    w.save('level_complete.png')


def shop():
    w = WF('ball shop')
    w.icon_btn(40, 81, '<')
    w.text(W / 2, 81, 'BALLS', 20, INK, 'mm')
    w.box(270, 66, 374, 96, fill=(255, 255, 255), radius=15)
    w.text(322, 81, '● 1,240', 12, INK, 'mm')
    w.box(30, 115, 360, 345, fill=(255, 255, 255), radius=24)
    w.d.ellipse(w.r(140, 160, 250, 270), fill=(120, 160, 255), outline=INK, width=2 * S)
    w.text(W / 2, 295, 'NEON PULSE', 18, INK, 'mm')
    w.text(W / 2, 322, 'live 3D preview, spinning', 10, MID, 'mm')
    for i in range(8):
        col, row = i % 4, i // 4
        x = 26 + col * 88
        y = 370 + row * 112
        sel = i == 2
        w.box(x, y, x + 74, y + 96, fill=(255, 255, 255), outline=ACCENT if sel else INK, width=4 if sel else 2, radius=16)
        w.d.ellipse(w.r(x + 20, y + 12, x + 54, y + 46), fill=LIGHT, outline=INK, width=2 * S)
        w.text(x + 37, y + 74, 'OWNED' if i < 3 else ('● %d' % (200 * i)), 12, INK, 'mm')
    w.text(20, 612, 'BOOSTERS', 12, MID)
    w.box(26, 630, 364, 690, fill=(255, 255, 255), radius=16)
    w.text(44, 660, 'Shield ×1  · absorbs one hazard', 13, INK, 'lm')
    w.button(266, 640, 352, 680, '● 120', size=13)
    w.button(70, 720, 320, 774, 'SELECT / BUY ● 600', primary=True, size=16)
    w.save('ball_shop.png')


def settings():
    w = WF('settings')
    w.icon_btn(40, 81, '<')
    w.text(W / 2, 81, 'SETTINGS', 20, INK, 'mm')
    rows = ['Music', 'Sound effects', 'Haptics', 'Reduce shake & flash']
    y = 120
    for r_ in rows:
        w.box(20, y, 370, y + 54, fill=(255, 255, 255), radius=16)
        w.text(38, y + 27, r_, 15, INK, 'lm')
        w.box(300, y + 15, 350, y + 39, fill=ACCENT, radius=12)
        y += 64
    w.box(20, y, 370, y + 74, fill=(255, 255, 255), radius=16)
    w.text(38, y + 22, 'Graphics quality', 15, INK, 'lm')
    for i, l in enumerate(['Low', 'Medium', 'High']):
        w.box(38 + i * 108, y + 38, 134 + i * 108, y + 64, fill=ACCENT if i == 2 else LIGHT, radius=12)
        w.text(86 + i * 108, y + 51, l, 12, INK, 'mm')
    y += 84
    w.box(20, y, 370, y + 74, fill=(255, 255, 255), radius=16)
    w.text(38, y + 22, 'Drag sensitivity   1.0×', 15, INK, 'lm')
    w.box(38, y + 48, 352, y + 54, fill=LIGHT, radius=3)
    w.d.ellipse(w.r(180, y + 41, 200, y + 61), fill=ACCENT)
    y += 84
    w.box(20, y, 370, y + 74, fill=(255, 255, 255), radius=16)
    w.text(38, y + 22, 'Control mode', 15, INK, 'lm')
    for i, l in enumerate(['Spin (drag)', 'Smash (hold)']):
        w.box(38 + i * 160, y + 38, 190 + i * 160, y + 64, fill=ACCENT if i == 0 else LIGHT, radius=12)
        w.text(114 + i * 160, y + 51, l, 12, INK, 'mm')
    y += 100
    w.button(70, y, 320, y + 50, 'RESET PROGRESS', size=15)
    w.note(70, y + 62, 'confirmation dialog before wiping')
    w.save('settings.png')


def flow():
    img = Image.new('RGB', (1200 * S // 2, 520 * S // 2), BG)
    d = ImageDraw.Draw(img)
    f = font(9)
    nodes = {'Splash': (60, 230), 'Home': (210, 230), 'Levels': (360, 110), 'Game': (380, 260), 'Pause': (530, 140),
             'Game Over': (540, 260), 'Complete': (540, 380), 'Shop': (210, 400), 'Settings': (210, 70),
             'Daily': (60, 400)}
    edges = [('Splash', 'Home'), ('Home', 'Game'), ('Home', 'Levels'), ('Levels', 'Game'), ('Home', 'Shop'),
             ('Home', 'Settings'), ('Home', 'Daily'), ('Game', 'Pause'), ('Pause', 'Game'), ('Game', 'Game Over'),
             ('Game', 'Complete'), ('Complete', 'Game'), ('Game Over', 'Game'), ('Pause', 'Home'), ('Game Over', 'Home'),
             ('Complete', 'Home')]
    for a, b in edges:
        (x0, y0), (x1, y1) = nodes[a], nodes[b]
        d.line([x0, y0, x1, y1], fill=MID, width=2)
        ang = math.atan2(y1 - y0, x1 - x0)
        mx, my = x0 + (x1 - x0) * 0.6, y0 + (y1 - y0) * 0.6
        d.polygon([(mx, my), (mx - 9 * math.cos(ang - 0.4), my - 9 * math.sin(ang - 0.4)),
                   (mx - 9 * math.cos(ang + 0.4), my - 9 * math.sin(ang + 0.4))], fill=MID)
    for n, (x, y) in nodes.items():
        d.rounded_rectangle([x - 48, y - 18, x + 48, y + 18], 10, fill=(255, 255, 255), outline=INK, width=2)
        d.text((x, y), n, fill=INK, font=f, anchor='mm')
    img.save(os.path.join(OUT, 'navigation_flow.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for fn in [splash, home, level_select, gameplay, pause, game_over, level_complete, shop, settings, flow]:
        fn()
    print('wireframes written to', os.path.abspath(OUT))
