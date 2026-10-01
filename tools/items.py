"""Generátor předmětů z vody z dílů (pro Rojo jako .model.json do assets/Items).

Spuštění:  python3 tools/items.py
Předmět je vycentrovaný, přední strana (oči, nápis) míří na -Z. Hra si ho sama zmenší (cca 3,8 studu).
"""

from __future__ import annotations

import math
import os

from modelkit import Build, along, angles, mat_mul, rgb, write_all, yaw_tilt

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "Items")

WHITE = rgb(255, 255, 255)
BLACK = rgb(22, 22, 28)
GOLD = rgb(255, 200, 45)
RAINBOW = [rgb(255, 80, 80), rgb(255, 170, 40), rgb(255, 230, 60), rgb(80, 210, 90), rgb(60, 150, 255), rgb(170, 80, 255)]


def eyes(b: Build, y, z, spread, d, x0=0.0, blush=None):
    for side in (-1, 1):
        b.ball(d, (x0 + side * spread, y, z), WHITE)
        b.ball(d * 0.55, (x0 + side * spread, y + d * 0.05, z - d * 0.32), BLACK)
        b.ball(d * 0.18, (x0 + side * spread - d * 0.1, y + d * 0.2, z - d * 0.5), WHITE)
        if blush:
            b.ell((d * 0.7, d * 0.35, d * 0.2), (x0 + side * spread * 1.7, y - d * 0.7, z + 0.02), blush)


def smile(b: Build, y, z, w, color=BLACK):
    for i in range(5):
        t = (i - 2) / 2
        b.ball(w * 0.18, (t * w * 0.5, y - (1 - t * t) * w * 0.18, z), color)


def curve(p0, p1, p2, n):
    return [tuple((1 - t) ** 2 * p0[k] + 2 * (1 - t) * t * p1[k] + t * t * p2[k] for k in range(3)) for t in (i / (n - 1) for i in range(n))]


def arc(cx, cy, cz, r, a0, a1, n, plane="xy"):
    pts = []
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / (n - 1))
        if plane == "xy":
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, cz))
        else:
            pts.append((cx + math.cos(a) * r, cy, cz + math.sin(a) * r))
    return pts


def wave(x0, y0, z0, x1, y1, z1, amp, n, phase=0.0, axis="x"):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        off = math.sin(t * math.pi * 2 + phase) * amp
        p = [x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t]
        p[0 if axis == "x" else 2] += off
        pts.append(tuple(p))
    return pts


def star(b: Build, pos, d, color, material="Neon"):
    b.gem(d, pos, color, material, rot=(0, 45, 45))
    b.gem(d * 0.8, pos, color, material, rot=(45, 0, 0))


def ring_y(b: Build, r, y, n, seg, h, thick, color, material="Smooth", z0=0.0):
    """Kruh ležící vodorovně (kolem svislé osy)."""
    for i in range(n):
        a = i / n * math.tau
        b.ell((seg, h, thick), (math.cos(a) * r, y, z0 + math.sin(a) * r), color, material, rot=(0, -(math.degrees(a) + 90), 0))


def ring_z(b: Build, r, center, n, d, colors, material="Smooth"):
    """Kruh stojící čelem k hráči (kolem osy Z) – torus z protáhlých elipsoidů."""
    cx, cy, cz = center
    for i in range(n):
        a0, a1 = i / n * math.tau, (i + 1) / n * math.tau
        p0 = (cx + math.cos(a0) * r, cy + math.sin(a0) * r, cz)
        p1 = (cx + math.cos(a1) * r, cy + math.sin(a1) * r, cz)
        seg = [p1[k] - p0[k] for k in range(3)]
        length = math.sqrt(sum(c * c for c in seg))
        mid = tuple((p0[k] + p1[k]) / 2 for k in range(3))
        b.add("ellipsoid", (d, length * 1.35 + d * 0.2, d), mid, colors[i % len(colors)], material, along(seg))


def bottle(b: Build, glass, length=2.6, d=1.1, cork=rgb(170, 120, 70), clear=0.5):
    """Průhledná láhev ležící na boku, hrdlo míří na +X."""
    b.add("cylinder", (length * 0.62, d, d), (-0.25, 0, 0), glass, "Glass", (0, 0, 0), clear)
    b.add("ellipsoid", (length * 0.35, d, d), (length * 0.08, 0, 0), glass, "Glass", (0, 0, 0), clear)
    b.add("ellipsoid", (length * 0.2, d, d), (-0.25 - length * 0.31, 0, 0), glass, "Glass", (0, 0, 0), clear)
    b.add("cylinder", (length * 0.25, d * 0.38, d * 0.38), (length * 0.38, 0, 0), glass, "Glass", (0, 0, 0), clear * 0.6)
    b.cyl((length * 0.06, d * 0.45, d * 0.45), (length * 0.5, 0, 0), glass, "Glass")
    b.cyl((length * 0.12, d * 0.32, d * 0.32), (length * 0.56, 0, 0), cork, "Wood")


def pedestal(b: Build, y, color=rgb(235, 235, 240), material="Marble", w=1.8):
    b.cyl((0.35, w, w), (0, y, 0), color, material, rot=(0, 0, 90))
    b.cyl((0.2, w * 1.12, w * 1.12), (0, y - 0.25, 0), color, material, rot=(0, 0, 90))


# ===================== Common =====================

def seashell():
    b = Build("Seashell")
    pink, light = rgb(255, 205, 185), rgb(255, 235, 225)
    for i in range(9):
        a = math.radians(20 + i * 17.5)
        tip = (math.cos(a) * 1.5, math.sin(a) * 1.5 - 0.6, 0)
        b.tube([(0, -0.7, 0), (tip[0] * 0.5, tip[1] * 0.5 - 0.3, -0.05), tip], 0.32, 0.5, pink if i % 2 == 0 else light, c1=light if i % 2 == 0 else pink)
    b.ell((2.6, 1.7, 0.32), (0, 0.05, 0.06), rgb(250, 190, 170))
    for side in (-1, 1):
        b.wedge((0.25, 0.4, 0.35), (side * 0.3, -0.85, 0), pink, rot=(0, 90 * side, 0))
    b.ball(0.3, (0.0, 0.0, -0.3), rgb(250, 245, 240))
    eyes(b, 0.15, -0.3, 0.32, 0.26, blush=rgb(255, 160, 170))
    return b


def pebble():
    b = Build("Pebble")
    gray = rgb(150, 150, 155)
    b.ell((2.4, 1.3, 1.8), (0, -0.3, 0), gray, "Smooth")
    b.ell((1.6, 1.0, 1.3), (0.15, 0.55, 0.05), rgb(175, 175, 180))
    b.ell((0.8, 0.55, 0.7), (-0.2, 1.2, 0.05), rgb(130, 130, 138))
    eyes(b, 0.6, -0.6, 0.25, 0.26, x0=0.15, blush=rgb(255, 160, 170))
    smile(b, 0.35, -0.62, 0.5)
    for x, z in ((-0.8, -0.5), (0.9, 0.3)):
        b.ball(0.15, (x, -0.3, z), rgb(120, 120, 125))
    return b


def plastic_shovel():
    b = Build("PlasticShovel")
    orange, blue = rgb(255, 120, 40), rgb(60, 160, 255)
    b.cyl((2.2, 0.28, 0.28), (0, 0.6, 0), orange, rot=(0, 0, 90))
    b.ell((0.8, 0.3, 0.3), (0, 1.75, 0), orange, rot=(0, 0, 90))
    b.ell((1.4, 1.7, 0.45), (0, -1.15, 0), blue)
    b.ell((1.2, 1.4, 0.3), (0, -1.1, -0.12), rgb(90, 190, 255))
    b.ell((0.6, 0.4, 0.2), (0, -0.4, 0), blue)
    b.ell((0.9, 0.35, 0.4), (0, -1.55, -0.2), rgb(240, 210, 140))
    star(b, (0.0, -1.0, -0.3), 0.25, rgb(255, 230, 60), "Smooth")
    return b


def old_sock():
    b = Build("OldSock")
    sock, red = rgb(225, 222, 205), rgb(220, 70, 70)
    b.tube([(0, 1.4, 0), (0, 0.4, 0), (0.1, -0.5, 0.05)], 1.0, 1.05, sock, "Fabric")
    b.tube([(0.1, -0.6, 0.05), (0.7, -1.0, -0.05), (1.5, -1.0, -0.1)], 1.0, 0.95, sock, "Fabric")
    b.ell((1.05, 0.25, 1.05), (0, 1.25, 0), red, "Fabric")
    b.ell((1.06, 0.2, 1.06), (0, 0.95, 0), red, "Fabric")
    b.ell((0.8, 0.8, 0.95), (0.0, -0.75, 0.15), rgb(200, 170, 140), "Fabric")
    b.ell((0.7, 0.8, 0.9), (1.55, -1.0, -0.1), rgb(200, 170, 140), "Fabric")
    b.ball(0.32, (1.9, -1.0, -0.1), rgb(255, 205, 170))
    # smradlavé obláčky
    for x, y, d in ((0.6, 1.5, 0.4), (0.95, 1.85, 0.32)):
        b.ball(d, (x, y, 0), rgb(160, 210, 90), transparency=0.3)
    return b


def seaweed():
    b = Build("Seaweed")
    greens = [rgb(60, 150, 70), rgb(80, 180, 80), rgb(40, 120, 60)]
    for i, (x, h, ph) in enumerate(((-0.6, 3.2, 0), (0.0, 3.8, 1.5), (0.6, 2.9, 3.0), (-0.25, 2.4, 4.0), (0.35, 2.2, 0.7))):
        pts = wave(x, -1.6, (i % 2) * 0.3, x, -1.6 + h, (i % 2) * 0.3, 0.25, 9, ph)
        b.tube(pts, 0.4, 0.15, greens[i % 3], c1=rgb(120, 210, 110))
    b.ell((2.2, 0.4, 1.2), (0, -1.65, 0.1), rgb(200, 180, 130))
    for x, y in ((0.9, 0.5), (1.1, 1.2), (-1.0, 1.0)):
        b.ball(0.25, (x, y, -0.2), rgb(200, 240, 255), "Glass", transparency=0.3)
    return b


# ===================== Uncommon =====================

def starfish():
    b = Build("Starfish")
    orange, light = rgb(255, 120, 80), rgb(255, 180, 140)
    for i in range(5):
        a = math.radians(90 + i * 72)
        tip = (math.cos(a) * 1.7, math.sin(a) * 1.7, 0.1)
        b.tube([(0, 0, 0), (tip[0] * 0.55, tip[1] * 0.55, 0), tip], 1.0, 0.35, orange)
        for j in (0.4, 0.65, 0.85):
            b.ball(0.15, (math.cos(a) * 1.7 * j, math.sin(a) * 1.7 * j, -0.32 + j * 0.15), light)
    b.ell((1.3, 1.3, 0.8), (0, 0, 0), orange)
    eyes(b, 0.15, -0.35, 0.25, 0.3, blush=rgb(255, 90, 110))
    smile(b, -0.15, -0.4, 0.45)
    return b


def rubber_duck(name="RubberDuck", body=rgb(255, 220, 40), scale=1.0, extra=None):
    b = Build(name)
    orange = rgb(255, 140, 20)
    s = scale
    b.ell((2.2 * s, 1.6 * s, 2.6 * s), (0, -0.4 * s, 0.2 * s), body)
    b.ball(1.5 * s, (0, 0.8 * s, -0.45 * s), body)
    b.ell((0.9 * s, 0.25 * s, 0.7 * s), (0, 0.6 * s, -1.2 * s), orange)
    b.ell((0.7 * s, 0.15 * s, 0.55 * s), (0, 0.45 * s, -1.15 * s), rgb(235, 110, 10))
    eyes(b, 1.0 * s, -1.05 * s, 0.32 * s, 0.32 * s, blush=rgb(255, 150, 120))
    b.wedge((0.6 * s, 0.6 * s, 0.6 * s), (0, 0.05 * s, 1.5 * s), body, rot=(-20, 0, 0))
    for side in (-1, 1):
        b.ell((0.3 * s, 0.8 * s, 1.3 * s), (side * 1.0 * s, -0.25 * s, 0.25 * s), body, rot=(-10, 0, side * 15))
    for i in range(3):
        b.ell((0.08 * s, 0.35 * s, 0.14 * s), ((-0.1 + i * 0.1) * s, 1.6 * s, -0.4 * s), body, rot=(0, 0, -20 + i * 20))
    if extra:
        extra(b, s)
    return b


def sand_bucket():
    b = Build("SandBucket")
    blue, sand = rgb(60, 160, 255), rgb(240, 210, 140)
    for i in range(6):
        d = 2.0 + i * 0.12
        b.cyl((0.42, d, d), (0, -1.0 + i * 0.4, 0), blue, rot=(0, 0, 90))
    b.cyl((0.18, 2.75, 2.75), (0, 1.25, 0), rgb(40, 130, 230), rot=(0, 0, 90))
    b.ell((2.5, 0.9, 2.5), (0, 1.35, 0), sand, "Fabric")
    b.tube(arc(0, 1.3, 0, 1.35, 0, 180, 9), 0.14, 0.14, rgb(255, 230, 60))
    # bábovka a mušle v písku
    b.cyl((0.4, 0.8, 0.8), (0.3, 1.85, 0.1), sand, "Fabric", rot=(0, 0, 90))
    b.ell((0.5, 0.25, 0.4), (-0.6, 1.65, -0.4), rgb(255, 200, 190))
    for i in range(5):
        a = math.radians(90 + i * 72)
        b.ell((0.12, 0.35, 0.08), (math.cos(a) * 0.18, -0.2 + math.sin(a) * 0.18, -1.27), rgb(255, 230, 60), rot=(0, 0, i * 72))
    return b


def swim_ring():
    b = Build("SwimRing")
    ring_z(b, 1.25, (0, 0, 0), 16, 0.85, [rgb(255, 80, 90), rgb(255, 80, 90), WHITE, WHITE])
    b.cyl((0.3, 0.2, 0.2), (0, 1.3, -0.45), rgb(255, 240, 240), rot=(0, 90, 0))
    return b


def beach_umbrella():
    b = Build("BeachUmbrella")
    red = rgb(255, 90, 90)
    b.cyl((3.4, 0.16, 0.16), (0, -0.4, 0), WHITE, rot=(0, 0, 90))
    b.ell((3.2, 1.1, 3.2), (0, 1.0, 0), red, "Fabric")
    for i in range(4):
        a = i * 45
        b.ell((0.4, 1.13, 3.24), (0, 1.0, 0), WHITE, "Fabric", rot=(0, a, 0))
    b.ell((3.0, 0.4, 3.0), (0, 0.72, 0), rgb(240, 70, 70), "Fabric")
    b.ball(0.3, (0, 1.6, 0), WHITE)
    # ozdobné třásně
    for i in range(16):
        a = i / 16 * math.tau
        b.ball(0.16, (math.cos(a) * 1.55, 0.55, math.sin(a) * 1.55), WHITE if i % 2 else rgb(255, 220, 60))
    b.ell((1.6, 0.25, 1.2), (0, -2.05, 0), rgb(240, 210, 140), "Fabric")
    return b


# ===================== Rare =====================

def message_in_a_bottle():
    b = Build("MessageInABottle")
    bottle(b, rgb(120, 200, 150))
    b.cyl((1.4, 0.55, 0.55), (-0.3, 0, 0), rgb(245, 230, 190), "Fabric")
    b.cyl((0.12, 0.58, 0.58), (-0.3, 0, 0), rgb(220, 60, 60), "Fabric")
    for i in range(3):
        b.box((0.9, 0.03, 0.03), (-0.3, 0.12 - i * 0.12, -0.28), rgb(120, 90, 60))
    star(b, (0.9, 0.55, -0.3), 0.18, WHITE)
    return b


def pearl():
    b = Build("Pearl")
    shell, inside = rgb(190, 170, 220), rgb(255, 225, 240)
    b.ell((2.6, 0.6, 2.2), (0, -0.8, 0), shell)
    b.ell((2.3, 0.3, 1.9), (0, -0.55, -0.02), inside)
    b.ell((2.6, 0.6, 2.2), (0, 0.3, 0.75), shell, rot=(-55, 0, 0))
    b.ell((2.3, 0.3, 1.9), (0, 0.2, 0.62), inside, rot=(-55, 0, 0))
    for i in range(5):
        x = -0.8 + i * 0.4
        b.ell((0.15, 0.62, 2.0), (x, -0.85, 0), rgb(170, 150, 205))
    b.ball(1.15, (0, -0.15, -0.2), rgb(250, 245, 240), "Glass")
    b.ball(0.3, (-0.25, 0.1, -0.65), WHITE, "Neon", transparency=0.3)
    return b


def crab_in_a_hat():
    b = Build("CrabInAHat")
    red, dark = rgb(240, 70, 50), rgb(190, 40, 35)
    b.ell((2.4, 1.2, 1.7), (0, -0.4, 0), red)
    for side in (-1, 1):
        # oči na stopkách
        b.cyl((0.6, 0.12, 0.12), (side * 0.35, 0.4, -0.45), dark, rot=(0, 0, 90))
        b.ball(0.38, (side * 0.35, 0.75, -0.5), WHITE)
        b.ball(0.2, (side * 0.35, 0.78, -0.66), BLACK)
        # klepeta
        b.tube([(side * 1.0, -0.4, -0.3), (side * 1.4, -0.1, -0.6), (side * 1.45, 0.3, -0.75)], 0.3, 0.3, red)
        b.ell((0.6, 0.5, 0.5), (side * 1.5, 0.45, -0.8), red)
        b.wedge((0.2, 0.45, 0.35), (side * 1.38, 0.85, -0.8), red, rot=(0, 0, side * 20))
        b.wedge((0.2, 0.4, 0.35), (side * 1.68, 0.8, -0.8), dark, rot=(0, 0, side * -20))
        for j in range(3):
            b.tube([(side * 0.9, -0.7, -0.2 + j * 0.4), (side * 1.4, -0.8, -0.1 + j * 0.45), (side * 1.55, -1.2, j * 0.45)], 0.18, 0.12, dark)
    smile(b, -0.45, -0.85, 0.6)
    # cylindr
    b.cyl((0.08, 1.2, 1.2), (0, 0.22, 0.1), BLACK, rot=(0, 0, 90))
    b.cyl((0.9, 0.8, 0.8), (0, 0.65, 0.1), BLACK, rot=(0, 0, 90))
    b.cyl((0.16, 0.82, 0.82), (0, 0.35, 0.1), rgb(220, 50, 70), rot=(0, 0, 90))
    return b


def goldfish_in_a_bag():
    b = Build("GoldfishInABag")
    water, orange = rgb(150, 215, 255), rgb(255, 150, 40)
    b.ell((2.3, 2.5, 2.1), (0, -0.4, 0), water, "Glass", transparency=0.55)
    b.ell((2.1, 1.7, 1.9), (0, -0.75, 0), rgb(90, 180, 255), "Glass", transparency=0.6)
    b.tube([(0, 0.8, 0), (0, 1.25, 0), (0, 1.5, 0)], 0.5, 0.25, water, "Glass")
    b.ell((0.45, 0.2, 0.45), (0, 1.35, 0), rgb(230, 60, 60), "Fabric")
    for side in (-1, 1):
        b.ell((0.5, 0.15, 0.2), (side * 0.3, 1.38, 0), rgb(230, 60, 60), "Fabric", rot=(0, 0, side * 30))
    # rybička
    b.ell((1.0, 0.65, 0.5), (-0.1, -0.5, 0), orange)
    b.wedge((0.12, 0.55, 0.5), (0.55, -0.5, 0), orange, rot=(0, 90, 0))
    b.wedge((0.08, 0.3, 0.3), (-0.1, -0.08, 0), rgb(255, 120, 30))
    b.ball(0.2, (-0.45, -0.38, -0.2), WHITE)
    b.ball(0.11, (-0.48, -0.37, -0.28), BLACK)
    for x, y in ((-0.6, 0.0), (-0.5, 0.35)):
        b.ball(0.12, (x, y, -0.1), WHITE, "Glass", transparency=0.3)
    b.ell((1.7, 0.2, 1.5), (0, -1.6, 0), rgb(240, 210, 140))
    return b


def compass():
    b = Build("Compass")
    brass = rgb(200, 160, 80)
    b.cyl((0.45, 2.7, 2.7), (0, 0, 0), brass, "Metal", rot=(0, 90, 0))
    b.cyl((0.5, 2.3, 2.3), (0, 0, -0.02), rgb(250, 245, 230), rot=(0, 90, 0))
    b.cyl((0.52, 0.25, 0.25), (0, 0, -0.03), brass, "Metal", rot=(0, 90, 0))
    b.box((0.22, 0.95, 0.06), (0, 0.5, -0.29), rgb(230, 50, 50), rot=(0, 0, 0))
    b.box((0.22, 0.95, 0.06), (0, -0.5, -0.29), rgb(60, 90, 200))
    for i in range(8):
        a = i / 8 * math.tau
        size = 0.18 if i % 2 == 0 else 0.1
        b.box((size, size, 0.05), (math.sin(a) * 0.95, math.cos(a) * 0.95, -0.27), BLACK, rot=(0, 0, 45))
    b.cyl((0.25, 0.35, 0.35), (0, 1.45, 0), brass, "Metal", rot=(0, 0, 90))
    ring_z(b, 0.28, (0, 1.85, 0), 10, 0.1, [brass], "Metal")
    b.ell((2.3, 2.3, 0.1), (0, 0, -0.3), rgb(200, 240, 255), "Glass", transparency=0.6)
    return b


# ===================== Epic =====================

def coin_chest():
    b = Build("CoinChest")
    wood, dark, gold = rgb(150, 90, 40), rgb(100, 60, 30), GOLD
    b.box((2.6, 1.4, 1.7), (0, -0.6, 0), wood, "Wood")
    b.cyl((2.6, 1.6, 1.7), (0, 0.4, 0.85), wood, "Wood", rot=(0, 0, 0))
    for x in (-1.0, 0, 1.0):
        b.box((0.18, 1.45, 1.75), (x, -0.6, 0), gold, "Metal")
    b.box((2.65, 0.12, 0.12), (0, 0.08, -0.85), gold, "Metal")
    b.box((0.35, 0.45, 0.12), (0, -0.2, -0.88), gold, "Metal")
    # hromada mincí
    b.ell((2.3, 0.7, 1.4), (0, 0.15, -0.1), gold, "Metal")
    for i in range(12):
        a = i * 2.4
        r = 0.2 + (i % 4) * 0.25
        b.cyl((0.08, 0.38, 0.38), (math.cos(a) * r * 1.4, 0.45 + (i % 3) * 0.08, math.sin(a) * r * 0.6 - 0.1), gold, "Metal", rot=(i * 13, 0, 90 + i * 17))
    for x, c in ((-0.6, rgb(255, 60, 90)), (0.5, rgb(60, 220, 120)), (0.0, rgb(80, 160, 255))):
        b.gem(0.3, (x, 0.65, -0.2), c, "Glass")
    # mince padající ven
    for i, (x, y) in enumerate(((1.4, -0.9), (1.7, -1.2), (-1.5, -1.2))):
        b.cyl((0.08, 0.38, 0.38), (x, y, -0.5), gold, "Metal", rot=(0, 0, 90 if i % 2 else 20))
    return b


def ship_in_a_bottle():
    b = Build("ShipInABottle")
    bottle(b, rgb(160, 220, 240), length=2.9, d=1.35)
    b.ell((2.0, 0.35, 1.0), (-0.3, -0.45, 0), rgb(60, 140, 220), "Glass")
    b.ell((1.3, 0.45, 0.5), (-0.3, -0.25, 0), rgb(130, 80, 40), "Wood")
    b.box((0.06, 0.9, 0.06), (-0.3, 0.2, 0), rgb(110, 70, 35), "Wood")
    b.ell((0.12, 0.7, 0.6), (-0.3, 0.25, -0.05), WHITE, "Fabric")
    b.ell((0.1, 0.5, 0.45), (-0.65, 0.12, -0.05), WHITE, "Fabric")
    b.box((0.25, 0.14, 0.02), (-0.3, 0.68, 0), rgb(230, 50, 50))
    return b


def octopus(name, color, glasses=False, plush=False):
    b = Build(name)
    light = tuple(min(1, c * 1.25) for c in color)
    mat = "Fabric" if plush else "Smooth"
    b.ell((2.0, 1.9, 1.9), (0, 0.6, 0.05), color, mat)
    b.ell((1.5, 1.2, 1.4), (0, 1.15, 0.25), color, mat)
    for i in range(8):
        a = i / 8 * math.tau
        cx, cz = math.cos(a), math.sin(a)
        pts = [(cx * 0.6, -0.1, cz * 0.6), (cx * 1.2, -0.6, cz * 1.2), (cx * 1.45, -1.05, cz * 1.45), (cx * 1.2 + cz * 0.3, -1.25, cz * 1.2 - cx * 0.3)]
        b.tube(pts, 0.5, 0.2, color, mat)
        b.ball(0.2, (cx * 1.05 + cz * 0.4, -1.2, cz * 1.05 - cx * 0.4), light, mat)
    eyes(b, 0.6, -0.85, 0.38, 0.45, blush=rgb(255, 150, 190))
    smile(b, 0.1, -0.92, 0.5)
    if glasses:
        for side in (-1, 1):
            ring_z(b, 0.3, (side * 0.38, 0.62, -1.08), 10, 0.07, [BLACK])
        b.box((0.2, 0.05, 0.05), (0, 0.65, -1.08), BLACK)
        b.ball(0.2, (0.9, 1.4, -0.3), rgb(255, 230, 80))
    if plush:
        for i in range(5):
            b.box((0.04, 0.12, 0.04), (0, 1.75 - i * 0.18, 0.75 - i * 0.05), rgb(255, 230, 240), "Fabric", rot=(-20, 0, 0))
        b.box((0.55, 0.3, 0.05), (0.75, 0.55, -0.62), rgb(255, 240, 200), "Fabric", rot=(0, -30, 0))
    return b


def dolphin_statue():
    b = Build("DolphinStatue")
    blue, belly = rgb(110, 170, 230), rgb(210, 235, 255)
    pedestal(b, -1.6)
    b.ell((1.4, 0.35, 1.4), (0, -1.3, 0), rgb(90, 180, 255), "Glass", transparency=0.2)
    # skákající delfín do oblouku: ocas dole u podstavce, hlava nahoře vpravo
    tail = curve((-0.9, -1.1, 0), (-1.2, -0.2, 0), (-0.6, 0.5, 0), 5)
    head = curve((-0.6, 0.5, 0), (0.1, 1.15, 0), (0.95, 0.75, 0), 5)
    b.tube(tail, 0.3, 0.8, blue)
    b.tube(head, 0.85, 0.6, blue)
    b.tube(curve((-0.75, 0.2, -0.1), (-0.1, 0.85, -0.25), (0.75, 0.55, -0.15), 5), 0.55, 0.4, belly)
    b.ell((0.6, 0.28, 0.3), (1.25, 0.6, 0), blue, rot=(0, 0, -25))
    b.wedge((0.1, 0.55, 0.5), (-0.1, 1.45, 0), blue, rot=(0, 90, 0))
    for side in (-1, 1):
        b.ell((0.7, 0.14, 0.4), (-0.95, -1.15, side * 0.25), blue, rot=(0, side * 30, 0))
        b.ell((0.45, 0.12, 0.3), (0.35, 0.5, side * 0.4), blue, rot=(side * 30, 0, -30))
        b.ball(0.2, (0.85, 0.9, side * 0.24), WHITE)
        b.ball(0.12, (0.9, 0.92, side * 0.29), BLACK)
    for x, y in ((0.6, -0.9), (0.9, -0.5), (0.4, -0.3)):
        b.ball(0.2, (x, y, -0.3), belly, "Glass")
    return b


def trident():
    b = Build("Trident")
    teal, gold = rgb(80, 220, 210), GOLD
    b.cyl((3.6, 0.22, 0.22), (0, -0.6, 0), gold, "Metal", rot=(0, 0, 90))
    b.tube(arc(0, 1.15, 0, 0.6, 180, 360, 9), 0.2, 0.2, teal, "Metal")
    b.box((0.2, 0.9, 0.2), (0, 1.45, 0), teal, "Metal")
    for x in (-0.6, 0, 0.6):
        h = 0.8 if x else 1.1
        b.box((0.18, h, 0.18), (x, 1.15 + h / 2 + (0.3 if not x else 0), 0), teal, "Metal")
        b.wedge((0.3, 0.45, 0.3), (x, 1.15 + h + 0.22 + (0.3 if not x else 0), 0), teal, "Metal")
    b.gem(0.45, (0, 0.9, -0.05), rgb(255, 80, 140), "Neon")
    for y in (-1.0, -1.6, -2.2):
        b.cyl((0.12, 0.3, 0.3), (0, y, 0), teal, "Metal", rot=(0, 0, 90))
    return b


# ===================== Legendary =====================

def pirate_map():
    b = Build("PirateMap")
    paper, ink, red = rgb(235, 210, 160), rgb(110, 70, 40), rgb(220, 40, 40)
    tilt = yaw_tilt(0, -60)  # mapa nakloněná k hráči

    def at(u, v, w=0.05):
        return tuple(tilt[k][0] * u + tilt[k][2] * v + tilt[k][1] * w for k in range(3))

    b.add("block", (2.6, 0.06, 2.0), (0, 0, 0), paper, "Fabric", tilt)
    # svinuté okraje
    for side in (-1, 1):
        b.add("cylinder", (2.1, 0.45, 0.45), at(side * 1.4, 0, 0), paper, "Fabric", mat_mul(tilt, angles(0, 90, 0)))
        b.add("cylinder", (2.16, 0.2, 0.2), at(side * 1.4, 0, 0), rgb(200, 170, 120), "Fabric", mat_mul(tilt, angles(0, 90, 0)))
    # ostrovy, cestička a křížek
    b.add("ellipsoid", (0.7, 0.06, 0.55), at(-0.55, -0.45, 0.03), rgb(110, 190, 90), "Smooth", tilt)
    b.add("ellipsoid", (0.55, 0.06, 0.45), at(0.65, 0.4, 0.03), rgb(110, 190, 90), "Smooth", tilt)
    for k in range(7):
        s = k / 6
        b.ball(0.1, at(-0.55 + s * 1.2, -0.45 + s * 0.85 + math.sin(s * 3.2) * 0.25, 0.06), ink)
    for r in (45, -45):
        b.add("block", (0.5, 0.1, 0.12), at(0.65, 0.4, 0.08), red, "Smooth", mat_mul(tilt, angles(0, r, 0)))
    # růžice
    b.add("block", (0.08, 0.06, 0.4), at(-0.95, 0.65, 0.04), ink, "Smooth", tilt)
    b.add("block", (0.4, 0.06, 0.08), at(-0.95, 0.65, 0.04), ink, "Smooth", tilt)
    return b


def golden_anchor():
    b = Build("GoldenAnchor")
    gold = GOLD
    b.box((0.35, 3.0, 0.35), (0, 0.1, 0), gold, "Foil")
    b.box((1.6, 0.3, 0.3), (0, 1.0, 0), gold, "Foil")
    for side in (-1, 1):
        b.ball(0.42, (side * 0.85, 1.0, 0), gold, "Foil")
    ring_z(b, 0.35, (0, 1.95, 0), 12, 0.2, [gold], "Foil")
    b.tube(arc(0, -0.3, 0, 1.15, 200, 340, 9), 0.35, 0.35, gold, "Foil")
    for side in (-1, 1):
        b.wedge((0.3, 0.55, 0.5), (side * 1.1, -0.6, 0), gold, "Foil", rot=(0, 90 * side, 0))
    b.ball(0.4, (0, -1.45, 0), gold, "Foil")
    b.gem(0.35, (0, 1.0, -0.2), rgb(80, 200, 255), "Glass")
    b.tube(wave(-0.18, 1.6, -0.25, 0.18, -1.0, -0.25, 0.25, 10), 0.12, 0.12, rgb(200, 60, 60), "Fabric")
    return b


def glowing_jellyfish():
    b = Build("GlowingJellyfish")
    cyan, pink = rgb(120, 230, 255), rgb(255, 150, 230)
    b.ell((2.4, 1.6, 2.4), (0, 0.8, 0), cyan, "Glass", transparency=0.3)
    b.ell((1.6, 1.0, 1.6), (0, 0.7, 0), pink, "Neon", transparency=0.3)
    b.ell((2.5, 0.35, 2.5), (0, 0.1, 0), cyan, "Neon", transparency=0.35)
    for i in range(8):
        a = i / 8 * math.tau
        cx, cz = math.cos(a) * 0.75, math.sin(a) * 0.75
        pts = wave(cx, 0.0, cz, cx * 1.1, -2.2, cz * 1.1, 0.18, 8, i)
        b.tube(pts, 0.2, 0.08, cyan if i % 2 else pink, "Neon")
    eyes(b, 0.65, -1.1, 0.35, 0.35, blush=rgb(255, 150, 200))
    smile(b, 0.3, -1.15, 0.4)
    return b


def fish_king_crown():
    b = Build("FishKingCrown")
    gold, aqua, pearl = rgb(255, 210, 60), rgb(60, 200, 230), rgb(250, 245, 240)
    b.cyl((1.0, 2.4, 2.4), (0, -0.5, 0), gold, "Foil", rot=(0, 0, 90))
    b.cyl((0.2, 2.55, 2.55), (0, -1.0, 0), gold, "Metal", rot=(0, 0, 90))
    b.cyl((0.2, 2.55, 2.55), (0, 0.0, 0), gold, "Metal", rot=(0, 0, 90))
    for i in range(6):
        a = i / 6 * math.tau - math.pi / 2
        x, z = math.cos(a) * 1.15, math.sin(a) * 1.15
        # rybička jako hrot koruny (hlavou dolů, ocas nahoru)
        b.ell((0.4, 0.8, 0.25), (x, 0.55, z), gold, "Foil", rot=(0, -math.degrees(a) - 90, 0))
        b.wedge((0.4, 0.4, 0.15), (x, 1.1, z), gold, "Foil", rot=(0, -math.degrees(a) - 90, 0))
        b.ball(0.14, (x * 1.12, 0.45, z * 1.12), BLACK)
        b.gem(0.22, (x * 1.06, -0.5, z * 1.06), aqua if i % 2 else rgb(255, 80, 120), "Glass")
    for i in range(12):
        a = i / 12 * math.tau
        b.ball(0.16, (math.cos(a) * 1.25, -1.0, math.sin(a) * 1.25), pearl)
    b.ell((2.2, 0.3, 2.2), (0, -0.95, 0), rgb(140, 20, 40), "Fabric")
    return b


def mermaid_statue():
    b = Build("MermaidStatue")
    teal, skin, hair, rock = rgb(80, 210, 180), rgb(255, 210, 175), rgb(230, 80, 120), rgb(150, 145, 140)
    b.ell((2.6, 1.0, 2.0), (0, -1.6, 0), rock)
    b.ell((1.4, 0.6, 1.2), (0.6, -1.0, 0.2), rgb(170, 165, 160))
    b.tube(curve((0.1, -0.2, 0), (0.2, -1.0, -0.2), (1.2, -0.9, -0.5), 6), 0.75, 0.35, teal, c1=rgb(60, 180, 200))
    b.wedge((0.12, 0.6, 0.6), (1.45, -0.7, -0.6), teal, rot=(0, 90, 30))
    b.wedge((0.12, 0.6, 0.6), (1.45, -1.15, -0.6), teal, rot=(0, 90, 150))
    b.ell((0.8, 1.0, 0.6), (0, 0.4, 0), skin)
    b.ball(0.75, (0, 1.25, 0), skin)
    b.ell((0.9, 0.95, 0.9), (0, 1.35, 0.15), hair)
    b.tube(curve((0.3, 1.4, 0.2), (0.6, 0.8, 0.3), (0.4, 0.2, 0.35), 6), 0.35, 0.2, hair)
    b.tube(curve((-0.3, 1.4, 0.2), (-0.6, 0.8, 0.3), (-0.45, 0.2, 0.35), 6), 0.35, 0.2, hair)
    eyes(b, 1.3, -0.33, 0.14, 0.17, blush=rgb(255, 150, 160))
    smile(b, 1.1, -0.36, 0.25)
    for side in (-1, 1):
        b.ell((0.3, 0.25, 0.2), (side * 0.18, 0.55, -0.28), rgb(255, 150, 200))
        b.tube([(side * 0.4, 0.6, 0), (side * 0.6, 0.3, -0.2), (side * 0.4, 0.1, -0.4)], 0.2, 0.17, skin)
    b.ell((0.3, 0.3, 0.3), (0, 0.1, -0.5), rgb(255, 230, 240))
    for i in range(5):
        a = math.radians(30 + i * 30)
        b.ell((0.07, 0.25, 0.05), (math.cos(a) * 0.15, 1.75 + math.sin(a) * 0.12, -0.05), GOLD, "Metal", rot=(0, 0, math.degrees(a) - 90))
    return b


# ===================== Mythic =====================

def sea_dragon_egg():
    b = Build("SeaDragonEgg")
    teal, dark = rgb(60, 200, 170), rgb(30, 130, 120)
    b.ell((2.2, 3.0, 2.2), (0, 0.2, 0), teal, "Smooth")
    for i in range(16):
        a = i * 2.39996
        y = -1.0 + (i / 15) * 2.3
        r = 1.1 * math.sqrt(max(0.05, 1 - ((y - 0.2) / 1.5) ** 2))
        b.ell((0.4, 0.35, 0.12), (math.cos(a) * r, y, math.sin(a) * r), dark, rot=(0, -math.degrees(a) - 90, 0))
    for x, y, rz in ((-0.4, 0.9, 40), (-0.1, 0.75, -30), (0.2, 0.95, 35), (0.45, 0.8, -40)):
        b.box((0.35, 0.07, 0.07), (x, y, -1.02), rgb(255, 250, 200), "Neon", rot=(0, 0, rz))
    b.ell((1.8, 0.5, 1.8), (0, -1.35, 0), rgb(240, 210, 140), "Fabric")
    for i in range(6):
        a = i / 6 * math.tau
        b.ball(0.3, (math.cos(a) * 1.1, -1.25, math.sin(a) * 1.1), rgb(250, 245, 240))
    return b


def rainbow_pearl():
    b = Build("RainbowPearl")
    for i, c in enumerate(RAINBOW):
        a = i * 30
        b.ell((2.25, 2.25, 0.4), (0, 0.3, 0), c, "Glass", rot=(0, a, 0))
    b.ball(2.15, (0, 0.3, 0), rgb(255, 225, 245), "Glass")
    b.ball(0.5, (-0.45, 0.85, -0.75), WHITE, "Neon", transparency=0.3)
    shell = rgb(255, 160, 230)
    for i in range(9):
        a = math.radians(-160 + i * 17.5)
        b.ell((0.45, 0.25, 1.6), (math.sin(a) * 1.0, -1.05, -math.cos(a) * 0.3 + 0.3), shell, rot=(0, math.degrees(a), 0))
    b.ell((2.6, 0.35, 1.8), (0, -1.2, 0.2), rgb(230, 130, 210))
    return b


def plush_kraken():
    return octopus("PlushKraken", rgb(190, 70, 160), plush=True)


# ===================== Secret =====================

def water_unicorn():
    b = Build("WaterUnicorn")
    body, light = rgb(150, 220, 255), rgb(220, 245, 255)
    b.ell((1.4, 1.2, 2.0), (0, -0.3, 0.3), body, "Glass")
    b.tube([(0, 0.0, -0.4), (0, 0.6, -0.7), (0, 1.0, -0.8)], 0.8, 0.7, body, "Glass")
    b.ell((0.8, 0.75, 1.1), (0, 1.15, -1.05), body, "Glass")
    b.ell((0.6, 0.5, 0.4), (0, 1.0, -1.5), light)
    for side in (-1, 1):
        b.ball(0.08, (side * 0.12, 1.0, -1.7), rgb(80, 120, 160))
        b.ball(0.28, (side * 0.33, 1.3, -1.35), WHITE)
        b.ball(0.16, (side * 0.36, 1.32, -1.45), BLACK)
        b.wedge((0.12, 0.3, 0.15), (side * 0.25, 1.62, -0.85), body, "Glass")
        for z in (-0.3, 0.8):
            b.tube([(side * 0.45, -0.6, z), (side * 0.5, -1.2, z - 0.1), (side * 0.5, -1.55, z)], 0.35, 0.3, body, "Glass")
            b.ell((0.4, 0.2, 0.4), (side * 0.5, -1.62, z), GOLD, "Metal")
    # zlatý roh do spirály
    for i in range(6):
        t = i / 5
        b.ell((0.25 - t * 0.15, 0.22, 0.25 - t * 0.15), (0, 1.55 + t * 0.7, -1.15 - t * 0.3), GOLD if i % 2 else rgb(255, 240, 160), "Foil")
    # duhová hříva a ocas
    for i, c in enumerate(RAINBOW):
        b.ell((0.18, 0.5, 0.35), (0.08 * (1 if i % 2 else -1), 1.5 - i * 0.18, -0.65 + i * 0.12), c, rot=(-30, 0, 0))
        b.tube([(0, 0.0, 1.2 + i * 0.02), (0.1 * (i - 2.5), -0.2, 1.7), (0.15 * (i - 2.5), -0.9, 1.9)], 0.18, 0.12, c)
    # vlna pod kopyty
    b.ell((2.4, 0.4, 3.0), (0, -1.75, 0.2), rgb(60, 160, 255), "Glass", transparency=0.2)
    for i in range(6):
        a = i / 6 * math.tau
        b.ball(0.35, (math.cos(a) * 1.2, -1.6, 0.2 + math.sin(a) * 1.5), WHITE, transparency=0.2)
    return b


def deep_sea_ufo():
    b = Build("DeepSeaUFO")
    metal, green = rgb(180, 190, 205), rgb(120, 255, 170)
    b.ell((3.6, 0.8, 3.6), (0, 0, 0), metal, "Metal")
    b.ell((2.6, 0.5, 2.6), (0, -0.4, 0), rgb(120, 130, 150), "Metal")
    b.ell((1.7, 1.5, 1.7), (0, 0.45, 0), rgb(160, 230, 255), "Glass", transparency=0.35)
    # mimozemšťánek
    b.ball(0.8, (0, 0.5, 0), green)
    b.ell((0.45, 0.6, 0.45), (0, 0.0, 0), green)
    for side in (-1, 1):
        b.ell((0.28, 0.35, 0.15), (side * 0.18, 0.6, -0.35), BLACK, rot=(0, 0, side * -25))
        b.cyl((0.4, 0.05, 0.05), (side * 0.15, 1.0, 0), green, rot=(0, 0, 90 - side * 20))
        b.ball(0.12, (side * 0.22, 1.2, 0), rgb(255, 230, 60), "Neon")
    for i in range(10):
        a = i / 10 * math.tau
        b.ball(0.22, (math.cos(a) * 1.6, -0.05, math.sin(a) * 1.6), [rgb(255, 80, 120), rgb(255, 230, 60), rgb(80, 220, 255)][i % 3], "Neon")
    # paprsek
    b.add("cylinder", (1.3, 1.0, 1.0), (0, -1.2, 0), green, "Neon", [[0, -1, 0], [1, 0, 0], [0, 0, 1]], 0.6)
    b.ball(0.45, (0, -1.6, 0), rgb(255, 200, 60))
    return b


def mega_splash_duck():
    def extra(b: Build, s):
        # sluneční brýle a koruna z vody
        for side in (-1, 1):
            b.ell((0.45 * s, 0.3 * s, 0.1 * s), (side * 0.32 * s, 1.05 * s, -1.25 * s), BLACK, "Glass")
        b.box((0.3 * s, 0.06 * s, 0.06 * s), (0, 1.1 * s, -1.28 * s), BLACK)
        for i in range(12):
            a = i / 12 * math.tau
            h = 0.6 if i % 2 else 0.9
            b.ell((0.35 * s, h * s, 0.35 * s), (math.cos(a) * 1.6 * s, -1.0 * s + h * 0.3 * s, 0.2 * s + math.sin(a) * 1.8 * s), rgb(90, 190, 255), "Glass", transparency=0.15)
            b.ball(0.22 * s, (math.cos(a) * 1.7 * s, -1.0 * s + h * 0.85 * s, 0.2 * s + math.sin(a) * 1.9 * s), rgb(200, 240, 255), "Glass")
        b.ell((3.6 * s, 0.25 * s, 4.0 * s), (0, -1.15 * s, 0.2 * s), rgb(60, 160, 255), "Glass", transparency=0.25)
        for i in range(5):
            a = i / 5 * math.tau
            b.wedge((0.12 * s, 0.35 * s, 0.2 * s), (math.cos(a) * 0.3 * s, 1.7 * s, -0.45 * s + math.sin(a) * 0.3 * s), GOLD, "Foil", rot=(0, -math.degrees(a), 0))
        b.cyl((0.2 * s, 0.75 * s, 0.75 * s), (0, 1.5 * s, -0.45 * s), GOLD, "Foil", rot=(0, 0, 90))

    return rubber_duck("MegaSplashDuck", rgb(255, 230, 60), 1.0, extra)


def golden_splash():
    b = Build("GoldenSplash")
    gold, deep = rgb(255, 205, 40), rgb(220, 160, 20)
    pedestal(b, -1.6, gold, "Foil", w=2.4)
    b.ell((2.2, 0.5, 2.2), (0, -1.15, 0), gold, "Foil")
    # koruna ze šplouchnutí
    for i in range(12):
        a = i / 12 * math.tau
        h = 1.2 if i % 2 else 0.8
        x, z = math.cos(a) * 1.0, math.sin(a) * 1.0
        b.tube([(x * 0.8, -1.0, z * 0.8), (x * 1.05, -1.0 + h * 0.5, z * 1.05), (x * 1.25, -1.0 + h, z * 1.25)], 0.35, 0.18, gold, "Foil")
        b.ball(0.26, (x * 1.35, -0.85 + h, z * 1.35), deep, "Foil")
    # vystřelující sloupec a kapky
    b.tube([(0, -1.0, 0), (0, 0.2, 0), (0, 1.2, 0)], 0.7, 0.35, gold, "Foil")
    b.ball(0.7, (0, 1.55, 0), gold, "Foil")
    for x, y, z, d in ((0.6, 1.9, 0.0, 0.3), (-0.55, 2.0, 0.2, 0.25), (0.1, 2.3, -0.3, 0.22), (-0.2, 1.1, -0.6, 0.2)):
        b.ell((d, d * 1.3, d), (x, y, z), deep, "Foil")
    for x, y, z in ((1.0, 1.2, -0.4), (-1.1, 0.6, -0.3), (0.5, 2.6, 0.2)):
        b.gem(0.18, (x, y, z), WHITE, "Neon", rot=(0, 45, 45))
    return b


ITEMS = [
    seashell, pebble, plastic_shovel, old_sock, seaweed,
    starfish, rubber_duck, sand_bucket, swim_ring, beach_umbrella,
    message_in_a_bottle, pearl, crab_in_a_hat, goldfish_in_a_bag, compass,
    coin_chest, ship_in_a_bottle, lambda: octopus("OctopusWithGlasses", rgb(200, 100, 220), glasses=True), dolphin_statue, trident,
    pirate_map, golden_anchor, glowing_jellyfish, fish_king_crown, mermaid_statue,
    sea_dragon_egg, rainbow_pearl, plush_kraken,
    water_unicorn, deep_sea_ufo, mega_splash_duck, golden_splash,
]


def main():
    write_all([f() for f in ITEMS], OUT_DIR)


if __name__ == "__main__":
    main()
