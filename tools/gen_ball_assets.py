"""Renders the realistic ball skins and their flame trails for Ball Game : Fire Ball.

Every ball is ray-cast per pixel (supersampled) with a physically-inspired shading model — hemisphere ambient,
key light, Blinn-Phong specular, Fresnel reflections of a neon-city environment, coloured rim lights and
emissive detail — the same ingredients a Unity standard shader uses, baked into sprites so the game can draw a
"real-time" looking ball for the cost of one textured quad.

Outputs (assets/images/balls/):
  <id>_ball.png   12 roll frames, 4x3 grid of 160 px cells (the ball rotates about a tilted axis)
  <id>_flame.png  6 flicker frames, one row of 160x256 cells; the plume points UP, its root is at
                  FLAME_ROOT (fraction of the cell height from the top) where the ball centre sits
  <id>_icon.png   256 px shop icon: ball + flame streaming to the upper right

Run: python3 tools/gen_ball_assets.py
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT = os.path.join(ROOT, 'assets', 'images', 'balls')

CELL = 160          # ball frame size (px)
BALL_R = 0.46       # ball radius as a fraction of the cell
FRAMES = 12
SS = 3              # supersampling factor
FLAME_W, FLAME_H, FLAME_FRAMES = 160, 256, 6
FLAME_ROOT = 0.80   # ball centre position in the flame cell (fraction of height from the top)

# ------------------------------------------------------------------ noise


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h &= 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFF) / 65535.0


def vnoise(p, seed=0):
    """3D value noise in [0,1]; p has shape (..., 3)."""
    i = np.floor(p).astype(np.int64)
    f = p - i
    u = f * f * (3 - 2 * f)
    x, y, z = i[..., 0], i[..., 1], i[..., 2]
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[..., 0] if dx else 1 - u[..., 0]) * (u[..., 1] if dy else 1 - u[..., 1]) * \
                    (u[..., 2] if dz else 1 - u[..., 2])
                out = out + w * _hash(x + dx, y + dy, z + dz, seed)
    return out


def fbm(p, octaves=5, seed=0):
    s, amp, norm = 0, 0.5, 0
    for o in range(octaves):
        s = s + amp * vnoise(p * (2 ** o), seed + o * 17)
        norm += amp
        amp *= 0.5
    return s / norm


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def hexc(h):
    return np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], dtype=np.float64) / 255.0


def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a + (b - a) * t


def normalize(v):
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


# ------------------------------------------------------------------ sphere helpers


def voronoi(n, pts):
    """Returns (index of nearest point, edge factor: 0 on a cell border .. larger inside)."""
    d = n @ pts.T
    order = np.argsort(-d, axis=-1)
    d1 = np.take_along_axis(d, order[..., :1], -1)[..., 0]
    d2 = np.take_along_axis(d, order[..., 1:2], -1)[..., 0]
    return order[..., 0], d1 - d2


def fib_points(k, seed):
    rng = np.random.default_rng(seed)
    i = np.arange(k) + 0.5
    phi = np.arccos(1 - 2 * i / k)
    th = math.pi * (1 + 5 ** 0.5) * i
    p = np.stack([np.cos(th) * np.sin(phi), np.cos(phi), np.sin(th) * np.sin(phi)], -1)
    p += rng.normal(0, 0.12, p.shape)
    return normalize(p)


def truncated_icosa():
    g = (1 + 5 ** 0.5) / 2
    pts = []
    for a in (-1, 1):
        for b in (-1, 1):
            pts += [(0, a, b * g), (a, b * g, 0), (b * g, 0, a)]
    pent = len(pts)
    for a in (-1, 1):
        for b in (-1, 1):
            for c in (-1, 1):
                pts.append((a, b, c))
            pts += [(0, a / g, b * g), (a / g, b * g, 0), (b * g, 0, a / g)]
    return normalize(np.array(pts, dtype=np.float64)), pent


def tangent_frame(center):
    c = normalize(np.array(center, dtype=np.float64))
    up = np.array([0, 1, 0.0]) if abs(c[1]) < 0.9 else np.array([1, 0, 0.0])
    t = normalize(np.cross(up, c))
    b = np.cross(c, t)
    return c, t, b


def decal_coords(n, center, scale):
    """Local 2D coords of points on the sphere around [center] (only valid on the facing side)."""
    c, t, b = tangent_frame(center)
    u = (n @ t) / scale
    v = (n @ b) / scale
    facing = (n @ c) > 0.3
    return u, v, facing


def crown_mask(u, v):
    # Crown in [-1,1] box: base band + three spikes.
    base = (np.abs(u) < 0.8) & (v > -0.75) & (v < -0.35)
    body = (np.abs(u) < 0.8) & (v >= -0.35) & (v < 0.15)
    spikes = np.zeros_like(u, dtype=bool)
    for cx, h in ((-0.62, 0.7), (0.0, 0.95), (0.62, 0.7)):
        w = 0.32 * (1 - np.clip((v - 0.15) / (h - 0.15), 0, 1))
        spikes |= (np.abs(u - cx) < w) & (v >= 0.15) & (v < h)
    gems = np.zeros_like(u, dtype=bool)
    for cx, cy in ((-0.62, 0.8), (0.0, 1.05), (0.62, 0.8)):
        gems |= (u - cx) ** 2 + (v - cy) ** 2 < 0.02
    return base | body | spikes | gems


def snowflake_mask(u, v):
    r = np.sqrt(u * u + v * v)
    a = np.arctan2(v, u)
    m = np.zeros_like(u, dtype=bool)
    for k in range(6):
        ang = k * math.pi / 3
        # distance from the arm line
        ca, sa = math.cos(ang), math.sin(ang)
        along = u * ca + v * sa
        across = np.abs(-u * sa + v * ca)
        arm = (along > 0) & (along < 0.95) & (across < 0.07)
        m |= arm
        for pos in (0.45, 0.7):
            for side in (-1, 1):
                bang = ang + side * 0.8
                bx, by = pos * ca, pos * sa
                cb, sb = math.cos(bang), math.sin(bang)
                du, dv = u - bx, v - by
                al = du * cb + dv * sb
                ac = np.abs(-du * sb + dv * cb)
                m |= (al > 0) & (al < 0.28 * (1.1 - pos)) & (ac < 0.055)
    m |= r < 0.14
    return m & (r < 1.0)


# ------------------------------------------------------------------ environment + lighting

LIGHT = normalize(np.array([-0.55, 0.7, 0.55]))
FILL = normalize(np.array([0.7, -0.35, 0.45]))   # pink neon bounce from the lower right
VIEW = np.array([0, 0, 1.0])


def env(r):
    """Neon-city environment map (used for reflections)."""
    y = r[..., 1]
    az = np.arctan2(r[..., 0], r[..., 2])
    horizon = hexc(0xD8C8FF)
    sky = mix(horizon, hexc(0x4A30A8), np.clip(y, 0, 1) ** 0.6)
    ground = mix(horizon * 0.85, hexc(0x2A1A60), smoothstep(0.0, 0.7, -y))
    col = np.where((y >= 0)[..., None], sky, ground)
    # Neon signage strips around the horizon.
    band = np.exp(-((y - 0.12) / 0.06) ** 2)
    cyan = band * (0.5 + 0.5 * np.cos(az * 3 + 0.5)) ** 6
    pink = band * (0.5 + 0.5 * np.cos(az * 3 + 2.6)) ** 6
    col = col + cyan[..., None] * hexc(0x3FE0FF) * 1.4 + pink[..., None] * hexc(0xFF4FD8) * 1.4
    # Big soft window behind the viewer, upper left (the key light's source).
    win = np.clip(r @ LIGHT, 0, 1) ** 24
    return col + win[..., None] * 1.6


class Mat:
    def __init__(self, albedo, rough=0.3, metal=0.0, spec=0.6, emissive=None, normal=None):
        self.albedo = albedo
        self.rough = rough
        self.metal = metal
        self.spec = spec
        self.emissive = emissive
        self.normal = normal  # optional shading normal (faceted crystals)


def shade(n, m):
    ns = m.normal if m.normal is not None else n
    ndl = np.clip(ns @ LIGHT, 0, 1)
    ndf = np.clip(ns @ FILL, 0, 1)
    nv = np.clip(ns @ VIEW, 0, 1)
    hemi = mix(hexc(0x2A1A55), hexc(0xC8C0FF), ns[..., 1] * 0.5 + 0.5)
    alb = m.albedo
    diffuse = alb * (hemi * 0.42 + ndl[..., None] * 0.85 * hexc(0xFFF4E8) + ndf[..., None] * 0.35 * hexc(0xFF5AD0))
    rvec = 2 * (ns @ VIEW)[..., None] * ns - VIEW
    refl = env(rvec)
    f0 = alb * m.metal + 0.04 * (1 - m.metal)
    fres = f0 + (1 - f0) * ((1 - nv) ** 5)[..., None]
    rough = m.rough
    refl_amt = fres * (1 - rough) ** 1.5
    metal = m.metal
    col = diffuse * (1 - metal * 0.75) + refl * refl_amt * (1 + 0.4 * metal)
    h = normalize(LIGHT + VIEW)
    shin = 8 + (1 - rough) ** 2 * 300
    specv = np.clip(ns @ h, 0, 1) ** shin * m.spec * (1 + 2 * (1 - rough))
    col = col + specv[..., None] * mix(np.ones(3), alb, metal * 0.7)
    # Coloured neon rim lights: cyan from the left, pink from the right.
    rim = (1 - nv) ** 3
    left = np.clip(-ns[..., 0], 0, 1)
    right = np.clip(ns[..., 0], 0, 1)
    col = col + rim[..., None] * (left[..., None] * hexc(0x3FE0FF) * 0.55 + right[..., None] * hexc(0xFF4FD8) * 0.45)
    if m.emissive is not None:
        col = col + m.emissive
    # Soft filmic shoulder.
    return 1 - np.exp(-col * 1.35)


# ------------------------------------------------------------------ skins


def skin_material(sid, n):
    """n: object-space normals (rotated with the ball). Returns Mat."""
    lat = np.arccos(np.clip(n[..., 1], -1, 1)) / math.pi
    lon = np.arctan2(n[..., 0], n[..., 2]) / (2 * math.pi) + 0.5
    if sid == 'bubblegum':
        base = hexc(0xFF3D78)
        band = smoothstep(0.075, 0.06, np.abs(lat - 0.52))
        grain = fbm(n * 6, 3, 1)[..., None] * 0.06
        alb = mix(base, hexc(0xFFF2F6), band) + grain - 0.03
        return Mat(alb, rough=0.18, spec=0.9)
    if sid == 'chrome':
        alb = np.broadcast_to(hexc(0xB8C0D8), n.shape).copy()
        brushed = fbm(n * np.array([2, 40, 2]), 2, 3)[..., None] * 0.08
        return Mat(alb * 0.55 + brushed, rough=0.06, metal=1.0, spec=1.4)
    if sid == 'neon':
        pts, pent = truncated_icosa()
        idx, edge = voronoi(n, pts)
        line = smoothstep(0.022, 0.004, edge)
        is_pent = (idx < pent)[..., None]
        cell = np.where(is_pent, hexc(0x061030), hexc(0x0A2050))
        alb = cell * (0.8 + 0.4 * fbm(n * 5, 3, 4)[..., None])
        glow = line[..., None] * hexc(0x3FF0FF) * 1.8 + smoothstep(0.07, 0.0, edge)[..., None] * hexc(0x1A8CFF) * 0.45
        alb = mix(alb, hexc(0xBFFBFF), line * 0.5)
        return Mat(alb, rough=0.4, spec=0.7, emissive=glow)
    if sid == 'ember':
        pts = fib_points(46, 11)
        warp = n + (fbm(n * 3, 3, 7)[..., None] - 0.5) * 0.35
        idx, edge = voronoi(normalize(warp), pts)
        crack = smoothstep(0.05, 0.0, edge)
        heat = fbm(n * 4, 4, 9)
        rock = mix(hexc(0x1A0A06), hexc(0x4A1A0C), heat) * (0.7 + 0.5 * fbm(n * 14, 3, 5))[..., None]
        lava = mix(hexc(0xFF3A00), hexc(0xFFE45A), crack ** 2)
        glow = crack[..., None] * lava * 2.2 + smoothstep(0.14, 0.0, edge)[..., None] * hexc(0xFF4A00) * 0.5
        return Mat(rock, rough=0.65, spec=0.25, emissive=glow)
    if sid == 'glacier':
        pts = fib_points(40, 21)
        idx, edge = voronoi(n, pts)
        facet = normalize(n * 0.35 + pts[idx] * 0.65)
        frost = fbm(n * 7, 4, 13)
        alb = mix(hexc(0x3AA8F0), hexc(0xCFF0FF), frost * 0.75)
        edges = smoothstep(0.03, 0.006, edge)
        u, v, facing = decal_coords(n, (0.15, 0.1, 1.0), 0.42)
        flake = (snowflake_mask(u, v) & facing).astype(np.float64)
        alb = mix(alb, np.ones(3), np.maximum(edges * 0.7, flake))
        inner = smoothstep(0.6, 1.0, frost)[..., None] * hexc(0x60C8FF) * 0.25 + flake[..., None] * hexc(0xD8F6FF) * 0.6
        return Mat(alb, rough=0.08, spec=1.2, emissive=inner, normal=facet)
    if sid == 'prism':
        swirl = lon * 2 + lat * 1.6 + 0.25 * np.sin(lat * 9 + lon * 6.28 * 2)
        h = np.mod(swirl, 1.0)
        k = np.mod(np.stack([h * 6 + 5, h * 6 + 3, h * 6 + 1], -1), 6)
        rgb = 1 - np.clip(np.minimum(k, 4 - k), 0, 1)  # HSV hue -> rgb (s=1, v=1)
        alb = rgb * 0.88 + 0.08
        return Mat(alb, rough=0.12, spec=1.0)
    if sid == 'nebula':
        cloud = fbm(n * 2.5, 5, 31)
        cloud2 = fbm(n * 4 + 7, 4, 37)
        alb = mix(hexc(0x0A0624), hexc(0x4A1A9A), smoothstep(0.4, 0.75, cloud))
        alb = mix(alb, hexc(0xFF5AC8), smoothstep(0.62, 0.85, cloud2) * 0.6)
        star = (vnoise(n * 90, 41) > 0.93).astype(np.float64) * (vnoise(n * 13, 43) > 0.4)
        # Glowing orbit band along a tilted great circle.
        axis = normalize(np.array([0.35, 1.0, -0.25]))
        band = np.exp(-((n @ axis) / 0.035) ** 2)
        emis = star[..., None] * 1.6 + band[..., None] * hexc(0xB8A0FF) * 1.2 + \
            smoothstep(0.55, 0.9, cloud)[..., None] * hexc(0x6A3AFF) * 0.35
        return Mat(alb, rough=0.2, spec=0.9, emissive=emis)
    if sid == 'royal':
        alb = np.broadcast_to(hexc(0xFFC23A), n.shape).copy()
        u, v, facing = decal_coords(n, (0.1, 0.15, 1.0), 0.36)
        cm = crown_mask(u, v) & facing
        # Engraved outline around the crown.
        cmx = crown_mask(u * 0.86, v * 0.86) & facing
        outline = cmx & ~cm
        alb = np.where(outline[..., None], hexc(0x8A5A08), alb)
        alb = np.where(cm[..., None], hexc(0xFFE27A), alb)
        emis = cm[..., None] * hexc(0xFFD050) * 0.35
        return Mat(alb, rough=0.12, metal=1.0, spec=1.3, emissive=emis)
    raise ValueError(sid)


SKINS = {
    # id: trail colour (matches lib/features/shop/data/skin_catalog.dart)
    'bubblegum': 0xFF5AA8,
    'chrome': 0x6AB8FF,
    'neon': 0x26F0FF,
    'ember': 0xFF7A1A,
    'glacier': 0x5AC8FF,
    'prism': 0xFFB23A,
    'nebula': 0xB06BFF,
    'royal': 0xFFA41A,
}


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def render_ball(sid, frame):
    n_px = CELL * SS
    ys, xs = np.mgrid[0:n_px, 0:n_px]
    x = (xs + 0.5) / n_px * 2 - 1
    y = 1 - (ys + 0.5) / n_px * 2
    x, y = x / (BALL_R * 2), y / (BALL_R * 2)
    rr = x * x + y * y
    inside = rr < 1
    z = np.sqrt(np.clip(1 - rr, 0, 1))
    n = np.stack([x, y, z], -1)
    # Object-space normal: the ball rolls about a tilted axis.
    m = rot_x(0.4) @ rot_y(2 * math.pi * frame / FRAMES)
    n_obj = n @ m
    mat = skin_material(sid, n_obj)
    if mat.normal is not None:
        mat.normal = mat.normal @ m.T  # back to view space
    rgb = shade(n, mat)
    # Ambient occlusion-ish darkening toward the lower silhouette.
    ao = 1 - 0.25 * smoothstep(0.2, 1.0, rr) * smoothstep(0.0, -1.0, y)
    rgb = rgb * ao[..., None]
    a = inside.astype(np.float64)
    img = np.concatenate([np.clip(rgb, 0, 1) * a[..., None], a[..., None]], -1)
    # Box-filter downsample (premultiplied), then un-premultiply.
    img = img.reshape(CELL, SS, CELL, SS, 4).mean(axis=(1, 3))
    alpha = img[..., 3:4]
    rgb = np.where(alpha > 0, img[..., :3] / np.maximum(alpha, 1e-6), 0)
    return Image.fromarray((np.concatenate([rgb, alpha], -1) * 255 + 0.5).astype(np.uint8))


def render_flame(color, frame):
    """Upward plume with its root at FLAME_ROOT; noise scrolls upward between frames."""
    h, w = FLAME_H * 2, FLAME_W * 2
    ys, xs = np.mgrid[0:h, 0:w]
    x = (xs + 0.5) / w * 2 - 1                     # -1..1
    yy = (ys + 0.5) / h                            # 0 top .. 1 bottom
    t = 1 - (yy / FLAME_ROOT)                      # 0 at root .. 1 at top, <0 below the root
    t_c = np.clip(t, 0, 1)
    width = 0.95 * (1 - t_c) ** 0.55 + 0.02
    # Below the root the plume wraps round the ball (rounded base).
    below = np.clip(-t, 0, 1) / (1 - FLAME_ROOT) * FLAME_ROOT
    base_round = np.sqrt(np.clip(1 - (below / 0.55) ** 2, 0, 1))
    width = np.where(t < 0, 0.95 * base_round, width)
    phase = frame / FLAME_FRAMES
    sway = 0.08 * np.sin(t_c * 7 - phase * 2 * math.pi) * t_c
    d = np.abs(x - sway) / np.maximum(width, 1e-3)
    p = np.stack([x * 2.4, yy * 4.2 + phase * 1.4, np.full_like(x, phase * 0.9)], -1)
    turb = fbm(p, 5, 77)
    body = np.clip(1 - d, 0, 1) ** 0.7
    inten = body * (0.45 + 0.85 * turb) - t_c * 0.42
    # Licking tongues near the tip.
    tongues = fbm(np.stack([x * 5, yy * 6 + phase * 2.5, np.full_like(x, 3.0)], -1), 3, 91)
    inten = inten + (tongues - 0.5) * 0.35 * t_c * body
    inten = np.clip(inten, 0, 1)
    c = hexc(color)
    hot = np.ones(3)
    ramp = np.where((inten < 0.45)[..., None], mix(c * 0.55, c, inten / 0.45),
                    np.where((inten < 0.75)[..., None], mix(c, c * 0.5 + hot * 0.6, (inten - 0.45) / 0.3),
                             mix(c * 0.5 + hot * 0.6, hot, (inten - 0.75) / 0.25)))
    ramp = np.clip(ramp, 0, 1)
    alpha = smoothstep(0.06, 0.4, inten)
    img = np.concatenate([ramp * alpha[..., None], alpha[..., None]], -1)
    img = img.reshape(FLAME_H, 2, FLAME_W, 2, 4).mean(axis=(1, 3))
    a = img[..., 3:4]
    rgb = np.where(a > 0, img[..., :3] / np.maximum(a, 1e-6), 0)
    return Image.fromarray((np.concatenate([rgb, a], -1) * 255 + 0.5).astype(np.uint8))


def glow(size, color, radius_frac, strength):
    ys, xs = np.mgrid[0:size, 0:size]
    d = np.hypot(xs - size / 2, ys - size / 2) / (size * radius_frac)
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    c = hexc(color)
    arr = np.zeros((size, size, 4))
    arr[..., :3] = c
    arr[..., 3] = a
    return Image.fromarray((arr * 255).astype(np.uint8))


def make_icon(sid, ball0, flame0):
    S = 256
    icon = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ball_d = int(S * 0.54)
    bc = (int(S * 0.38), int(S * 0.64))
    # Flame: scale so its width ~ 1.25x the ball, rotate to point up-right, root on the ball centre.
    # Root half-width (0.95 of half the cell) ~ 1.15x the ball radius so fire wraps round the silhouette.
    sx = (ball_d / 2 * 1.15) / (FLAME_W / 2 * 0.95)
    fl = flame0.resize((int(FLAME_W * sx), int(FLAME_H * sx * 0.92)), Image.LANCZOS)
    root = (fl.width / 2, fl.height * FLAME_ROOT)
    # Rotate about the root: pad so the root is the image centre, then rotate.
    pad = int(max(fl.width, fl.height) * 2)
    canvas = Image.new('RGBA', (pad, pad), (0, 0, 0, 0))
    canvas.paste(fl, (int(pad / 2 - root[0]), int(pad / 2 - root[1])))
    canvas = canvas.rotate(-40, resample=Image.BICUBIC)
    halo = glow(int(ball_d * 1.7), SKINS[sid], 0.5, 0.55)
    icon.alpha_composite(halo, (bc[0] - halo.width // 2, bc[1] - halo.height // 2))
    tmp = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    tmp.paste(canvas, (int(bc[0] - pad / 2), int(bc[1] - pad / 2)), canvas)
    icon = Image.alpha_composite(icon, tmp)
    b = ball0.resize((int(ball_d / (BALL_R * 2)), int(ball_d / (BALL_R * 2))), Image.LANCZOS)
    icon.alpha_composite(b, (bc[0] - b.width // 2, bc[1] - b.height // 2))
    return icon


def main():
    os.makedirs(OUT, exist_ok=True)
    for sid, trail in SKINS.items():
        frames = [render_ball(sid, f) for f in range(FRAMES)]
        sheet = Image.new('RGBA', (CELL * 4, CELL * 3), (0, 0, 0, 0))
        for i, fimg in enumerate(frames):
            sheet.paste(fimg, ((i % 4) * CELL, (i // 4) * CELL))
        sheet.save(os.path.join(OUT, f'{sid}_ball.png'), optimize=True)
        flames = [render_flame(trail, f) for f in range(FLAME_FRAMES)]
        fsheet = Image.new('RGBA', (FLAME_W * FLAME_FRAMES, FLAME_H), (0, 0, 0, 0))
        for i, fimg in enumerate(flames):
            fsheet.paste(fimg, (i * FLAME_W, 0))
        fsheet.save(os.path.join(OUT, f'{sid}_flame.png'), optimize=True)
        make_icon(sid, frames[0], flames[0]).save(os.path.join(OUT, f'{sid}_icon.png'), optimize=True)
        print('rendered', sid)


if __name__ == '__main__':
    main()
