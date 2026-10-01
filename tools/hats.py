"""Generátor čepic z dílů (pro Rojo jako .model.json do assets/Hats).

Spuštění:  python3 tools/hats.py
Čepice jsou ve skutečné velikosti. Díl "Attach" je úchyt: hra ho dá 0,25 studu pod temeno hlavy.
Hlava je tu brána jako koule o průměru ~1,25 se středem v (0, -0.35, 0), obličej míří na -Z.
"""

from __future__ import annotations

import math
import os

from modelkit import Build, rgb, write_all, yaw_tilt

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "Hats")

WHITE = rgb(255, 255, 255)
BLACK = rgb(22, 22, 28)
GOLD = rgb(255, 200, 45)


def new(name: str) -> Build:
    b = Build(name)
    b.attach((0, 0, 0))
    return b


def ring(b: Build, r, y, n, seg_len, h, thick, color, material="Smooth", kind="box", offset=0.0):
    """Kruh z dílů kolem hlavy (tečně natočené)."""
    for i in range(n):
        a = i / n * math.tau + offset
        pos = (math.cos(a) * r, y, math.sin(a) * r)
        ry = -(math.degrees(a) + 90)
        if kind == "box":
            b.box((seg_len, h, thick), pos, color, material, rot=(0, ry, 0))
        else:
            b.ell((seg_len, h, thick), pos, color, material, rot=(0, ry, 0))


def chain(b: Build, points, d0, d1, color, material="Smooth", c1=None):
    """Zahnutý tvar (roh, chapadlo) z koulí, které se postupně zmenšují."""
    n = len(points)
    for i, p in enumerate(points):
        t = i / max(1, n - 1)
        col = color
        if c1 is not None:
            col = tuple(color[k] + (c1[k] - color[k]) * t for k in range(3))
        b.ball(d0 + (d1 - d0) * t, p, col, material)


def curve(p0, p1, p2, n):
    """Kvadratická Bézierova křivka – body pro chain()."""
    pts = []
    for i in range(n):
        t = i / (n - 1)
        pts.append(tuple((1 - t) ** 2 * p0[k] + 2 * (1 - t) * t * p1[k] + t * t * p2[k] for k in range(3)))
    return pts


def eyes(b: Build, y, z, spread, d):
    for side in (-1, 1):
        b.ball(d, (side * spread, y, z), WHITE)
        b.ball(d * 0.55, (side * spread, y + d * 0.05, z - d * 0.32), BLACK)
        b.ball(d * 0.18, (side * spread - d * 0.1, y + d * 0.2, z - d * 0.5), WHITE)


def star(b: Build, pos, d, color, material="Neon"):
    b.gem(d, pos, color, material, rot=(0, 45, 45))
    b.gem(d * 0.8, pos, color, material, rot=(45, 0, 0))


def dome(b: Build, color, material="Smooth", w=1.36, h=0.9, d=1.42, y=0.05):
    """Kopule čepice: spodek schovaný v hlavě, nezakrývá obličej."""
    b.ell((w, h, d), (0, y, 0.02), color, material)


# ===================== Čepice =====================

def baseball_cap():
    b = new("BaseballCap")
    red = rgb(230, 50, 50)
    dome(b, red, "Fabric")
    b.ell((1.15, 0.1, 0.85), (0, -0.1, -0.72), WHITE, "Fabric", rot=(-6, 0, 0))
    b.ball(0.16, (0, 0.5, 0.02), WHITE, "Fabric")
    star(b, (0, 0.18, -0.68), 0.2, WHITE, "Smooth")
    return b


def straw_hat():
    b = new("StrawHat")
    straw, red = rgb(235, 200, 120), rgb(200, 60, 60)
    b.cyl((0.08, 2.5, 2.5), (0, -0.06, 0), straw, "Fabric", rot=(0, 0, 90))
    b.ell((2.56, 0.12, 2.56), (0, -0.03, 0), rgb(220, 180, 100), "Fabric")
    b.cyl((0.6, 1.32, 1.32), (0, 0.22, 0), straw, "Fabric", rot=(0, 0, 90))
    b.ell((1.32, 0.3, 1.32), (0, 0.5, 0), straw, "Fabric")
    b.cyl((0.18, 1.36, 1.36), (0, 0.07, 0), red, "Fabric", rot=(0, 0, 90))
    # kytička na stuze
    for i in range(5):
        a = i / 5 * math.tau
        b.ball(0.14, (0.55 + math.cos(a) * 0.09, 0.1 + math.sin(a) * 0.09, -0.4), rgb(255, 230, 240))
    b.ball(0.1, (0.6, 0.1, -0.43), rgb(255, 210, 60))
    return b


def swim_cap():
    b = new("SwimCap")
    blue = rgb(60, 170, 255)
    dome(b, blue, "Smooth", w=1.34, h=0.85, d=1.4)
    for x in (-0.3, 0.3):
        b.ell((0.12, 0.88, 1.43), (x, 0.06, 0.02), WHITE)
    for x, z, c in ((-0.45, -0.3, rgb(255, 120, 180)), (0.5, 0.1, rgb(255, 220, 60)), (0.0, -0.45, rgb(255, 120, 180))):
        for i in range(5):
            a = i / 5 * math.tau
            b.ball(0.1, (x + math.cos(a) * 0.07, 0.38 - abs(x) * 0.25, z + math.sin(a) * 0.07), c)
    # brýle na čele
    b.cyl((0.08, 1.4, 1.4), (0, -0.05, 0), rgb(40, 40, 50), rot=(0, 0, 90))
    for side in (-1, 1):
        b.cyl((0.14, 0.34, 0.34), (side * 0.22, 0.08, -0.62), rgb(140, 230, 255), "Glass", rot=(0, 90, -15))
    return b


def diving_goggles():
    b = new("DivingGoggles")
    dark, lens, orange = rgb(40, 40, 50), rgb(120, 220, 255), rgb(255, 140, 30)
    b.cyl((0.16, 1.32, 1.32), (0, -0.3, 0.02), dark, rot=(0, 0, 90))
    b.ell((0.98, 0.5, 0.3), (0, -0.3, -0.6), dark)
    for side in (-1, 1):
        b.cyl((0.16, 0.42, 0.42), (side * 0.22, -0.3, -0.72), lens, "Glass", rot=(0, 90, 0))
    # šnorchl
    b.cyl((1.1, 0.16, 0.16), (-0.66, 0.0, -0.15), orange, rot=(0, 0, 90))
    b.ball(0.16, (-0.66, 0.55, -0.15), orange)
    b.ell((0.18, 0.12, 0.25), (-0.66, 0.6, -0.25), orange)
    b.cyl((0.12, 0.25, 0.25), (-0.66, -0.55, -0.15), WHITE, rot=(0, 0, 90))
    return b


def fishing_hat():
    b = new("FishingHat")
    olive, orange = rgb(120, 140, 90), rgb(255, 150, 60)
    b.cyl((0.1, 1.9, 1.9), (0, -0.08, 0), olive, "Fabric", rot=(0, 0, 90))
    b.ell((1.95, 0.22, 1.95), (0, -0.14, 0), rgb(105, 125, 80), "Fabric")
    b.cyl((0.55, 1.36, 1.36), (0, 0.2, 0), olive, "Fabric", rot=(0, 0, 90))
    b.ell((1.36, 0.3, 1.36), (0, 0.47, 0), olive, "Fabric")
    b.cyl((0.14, 1.4, 1.4), (0, 0.04, 0), rgb(90, 70, 50), "Fabric", rot=(0, 0, 90))
    # návnady a rybička
    for i, a in enumerate((0.6, 1.4, 2.4)):
        x, z = math.cos(a) * 0.7, -math.sin(a) * 0.7
        b.ball(0.16, (x, 0.07, z), orange if i % 2 == 0 else rgb(255, 230, 60))
        b.wedge((0.04, 0.1, 0.12), (x, -0.06, z), rgb(200, 200, 210), "Metal")
    b.ell((0.12, 0.2, 0.4), (0.68, -0.4, 0.2), orange)
    b.wedge((0.06, 0.2, 0.16), (0.68, -0.4, 0.45), orange)
    b.cyl((0.4, 0.02, 0.02), (0.68, -0.15, 0.2), rgb(230, 230, 230), rot=(0, 0, 90))
    return b


def propeller_cap():
    b = new("PropellerCap")
    cols = [rgb(255, 210, 50), rgb(230, 60, 60), rgb(60, 150, 255), rgb(80, 200, 90)]
    dome(b, cols[0], "Fabric")
    for i in range(4):
        a = i / 4 * math.tau + math.pi / 4
        b.ell((0.5, 0.85, 0.5), (math.cos(a) * 0.36, 0.1, math.sin(a) * 0.36), cols[i], "Fabric")
    b.ell((0.9, 0.08, 0.5), (0, -0.08, -0.72), cols[1], "Fabric")
    b.cyl((0.35, 0.1, 0.1), (0, 0.62, 0), BLACK, "Metal", rot=(0, 0, 90))
    b.ball(0.16, (0, 0.8, 0), rgb(230, 60, 60))
    for i, c in enumerate((cols[1], cols[2], cols[3])):
        a = i / 3 * 360
        b.ell((0.8, 0.04, 0.2), (math.cos(math.radians(a)) * 0.42, 0.82, -math.sin(math.radians(a)) * 0.42), c, rot=(15, a, 0))
    return b


def chef_hat():
    b = new("ChefHat")
    b.cyl((0.5, 1.36, 1.36), (0, 0.15, 0), WHITE, "Fabric", rot=(0, 0, 90))
    b.cyl((0.08, 1.4, 1.4), (0, -0.08, 0), rgb(235, 235, 235), "Fabric", rot=(0, 0, 90))
    for x, z, d in ((0, 0, 1.0), (-0.35, -0.3, 0.75), (0.35, -0.3, 0.75), (-0.35, 0.3, 0.75), (0.35, 0.3, 0.75), (0, -0.45, 0.65), (0, 0.45, 0.65)):
        b.ball(d, (x, 0.75 + (0.2 if d == 1.0 else 0), z), WHITE, "Fabric")
    return b


def cowboy_hat():
    b = new("CowboyHat")
    brown, dark = rgb(150, 95, 50), rgb(90, 55, 30)
    b.ell((2.3, 0.12, 2.0), (0, -0.05, 0), brown, "Fabric")
    for side in (-1, 1):
        b.ell((0.5, 0.12, 1.9), (side * 1.0, 0.12, 0), brown, "Fabric", rot=(0, 0, side * -35))
    b.ell((1.3, 1.0, 1.4), (0, 0.3, 0), brown, "Fabric")
    b.ell((0.3, 0.3, 1.0), (0, 0.8, 0), dark, "Fabric")
    b.cyl((0.16, 1.32, 1.32), (0, 0.05, 0), dark, "Fabric", rot=(0, 0, 90))
    star(b, (0, 0.06, -0.68), 0.2, GOLD, "Metal")
    return b


def shark_hood():
    b = new("SharkHood")
    gray, white = rgb(110, 130, 150), WHITE
    b.ell((1.55, 1.05, 1.7), (0, 0.15, 0.12), gray)
    b.ell((1.2, 0.3, 1.2), (0, -0.25, 0.35), gray)
    # zuby na čele
    for i in range(7):
        a = math.radians(-60 + i * 20)
        x, z = math.sin(a) * 0.68, -math.cos(a) * 0.68
        b.wedge((0.12, 0.2, 0.1), (x, -0.13, z), white, rot=(180, -math.degrees(a), 0))
    b.ell((1.4, 0.12, 0.25), (0, -0.07, -0.62), rgb(200, 60, 80))
    eyes(b, 0.35, -0.62, 0.42, 0.28)
    # ploutev a ocas
    b.wedge((0.16, 0.7, 0.6), (0, 0.95, 0.2), gray, rot=(0, 180, 0))
    b.wedge((0.16, 0.7, 0.2), (0, 0.95, -0.2), gray)
    b.wedge((0.12, 0.5, 0.4), (0, 0.35, 1.05), gray)
    b.wedge((0.12, 0.4, 0.35), (0, -0.05, 1.1), gray, rot=(180, 0, 0))
    for side in (-1, 1):
        b.wedge((0.06, 0.3, 0.45), (side * 0.78, -0.05, 0.25), gray, rot=(0, 0, side * 50))
    return b


def flower_crown():
    b = new("FlowerCrown")
    leaf = rgb(90, 180, 80)
    ring(b, 0.64, -0.02, 14, 0.32, 0.12, 0.14, leaf, kind="ell")
    petals = [rgb(255, 130, 200), rgb(255, 240, 90), rgb(180, 120, 255), rgb(255, 255, 255), rgb(255, 150, 80)]
    for i in range(8):
        a = i / 8 * math.tau + 0.2
        cx, cz = math.cos(a) * 0.68, math.sin(a) * 0.68
        col = petals[i % len(petals)]
        for j in range(5):
            pa = j / 5 * math.tau
            b.ball(0.16, (cx + math.cos(pa) * 0.1 * math.sin(a), 0.06 + math.sin(pa) * 0.1, cz - math.cos(pa) * 0.1 * math.cos(a)), col)
        b.ball(0.1, (cx * 1.05, 0.06, cz * 1.05), rgb(255, 210, 60) if col != rgb(255, 240, 90) else rgb(255, 150, 60))
    for i in range(6):
        a = i / 6 * math.tau + 0.5
        b.ell((0.12, 0.05, 0.28), (math.cos(a) * 0.7, -0.05, math.sin(a) * 0.7), leaf, rot=(0, -math.degrees(a), 20))
    return b


def wizard_hat():
    b = new("WizardHat")
    purple, gold = rgb(80, 60, 190), rgb(255, 230, 90)
    b.cyl((0.08, 2.2, 2.2), (0, -0.05, 0), purple, "Fabric", rot=(0, 0, 90))
    pts = []
    for i in range(8):
        t = i / 7
        d = 1.35 * (1 - t) + 0.12 * t
        x = 0.35 * t * t
        y = 0.15 + i * 0.22
        b.cyl((0.26, d, d), (x, y, 0), purple, "Fabric", rot=(0, 0, 90 + 25 * t * t))
        pts.append((x, y))
    b.ball(0.18, (0.55, 1.7, 0), gold, "Neon")
    b.cyl((0.14, 1.38, 1.38), (0, 0.07, 0), gold, "Fabric", rot=(0, 0, 90))
    for x, y, z, d in ((0.0, 0.55, -0.55, 0.22), (-0.35, 0.85, -0.3, 0.15), (0.3, 1.0, -0.25, 0.14), (-0.1, 1.25, -0.2, 0.12)):
        star(b, (x, y, z), d, gold)
    # měsíček
    b.ell((0.06, 0.3, 0.3), (0.45, 0.5, -0.45), gold, "Neon")
    b.ell((0.07, 0.26, 0.26), (0.46, 0.53, -0.53), purple, "Fabric")
    return b


def knight_helmet():
    b = new("KnightHelmet")
    steel, red = rgb(180, 185, 195), rgb(230, 60, 60)
    b.ell((1.5, 1.65, 1.6), (0, -0.33, 0), steel, "Metal")
    b.ell((0.12, 1.7, 1.62), (0, -0.32, 0), rgb(150, 155, 165), "Metal")
    b.box((1.1, 0.1, 0.2), (0, -0.3, -0.75), BLACK)
    b.box((0.9, 0.08, 0.2), (0, -0.48, -0.74), BLACK)
    for i in range(4):
        b.box((0.06, 0.12, 0.2), (-0.24 + i * 0.16, -0.75, -0.7), BLACK)
    for side in (-1, 1):
        b.ball(0.1, (side * 0.72, -0.3, -0.25), rgb(220, 220, 230), "Metal")
    # chochol
    for i in range(6):
        b.ell((0.18, 0.5, 0.3), (0, 0.6 + math.sin(i * 0.5) * 0.15, -0.25 + i * 0.15), red, "Fabric", rot=(-30 + i * 20, 0, 0))
    return b


def viking_helmet():
    b = new("VikingHelmet")
    steel, horn, brass = rgb(160, 160, 170), rgb(250, 240, 210), rgb(200, 150, 60)
    dome(b, steel, "Metal", w=1.42, h=0.95, d=1.46)
    b.cyl((0.18, 1.44, 1.44), (0, -0.08, 0.02), brass, "Metal", rot=(0, 0, 90))
    for i in range(10):
        a = i / 10 * math.tau
        b.ball(0.08, (math.cos(a) * 0.72, -0.08, 0.02 + math.sin(a) * 0.72), rgb(230, 200, 120), "Metal")
    b.box((0.14, 0.5, 0.1), (0, -0.3, -0.7), brass, "Metal")
    b.ell((0.12, 0.9, 1.45), (0, 0.08, 0.02), brass, "Metal")
    for side in (-1, 1):
        pts = curve((side * 0.6, 0.15, 0), (side * 1.15, 0.35, -0.1), (side * 1.05, 1.0, -0.15), 8)
        b.tube(pts, 0.34, 0.08, horn, "Smooth", c1=rgb(255, 255, 240))
    return b


def astronaut_helmet():
    b = new("AstronautHelmet")
    white, visor, blue = rgb(245, 245, 250), rgb(80, 170, 255), rgb(60, 120, 230)
    b.ball(1.8, (0, -0.35, 0), white)
    b.ell((1.25, 0.95, 0.6), (0, -0.32, -0.62), visor, "Glass", transparency=0.25)
    b.ell((1.1, 0.2, 0.3), (-0.1, -0.05, -0.8), WHITE, "Neon", transparency=0.6)
    b.cyl((0.3, 1.5, 1.5), (0, -1.05, 0), rgb(200, 200, 210), "Metal", rot=(0, 0, 90))
    for side in (-1, 1):
        b.cyl((0.16, 0.5, 0.5), (side * 0.88, -0.35, 0), blue, rot=(0, 0, 0))
    b.cyl((0.5, 0.06, 0.06), (0.6, 0.55, 0.2), rgb(150, 150, 160), "Metal", rot=(0, 0, 70))
    b.ball(0.14, (0.68, 0.78, 0.2), rgb(255, 60, 60), "Neon")
    return b


def octopus_buddy():
    b = new("OctopusBuddy")
    pink, light = rgb(255, 120, 170), rgb(255, 180, 210)
    b.ell((1.2, 1.05, 1.15), (0, 0.55, 0.05), pink)
    b.ell((0.9, 0.7, 0.8), (0, 0.85, 0.15), pink)
    eyes(b, 0.55, -0.5, 0.24, 0.3)
    b.ell((0.25, 0.08, 0.06), (0, 0.32, -0.55), rgb(160, 40, 80))
    for side in (-1, 1):
        b.ell((0.18, 0.08, 0.08), (side * 0.42, 0.38, -0.47), light)
    # chapadla přes hlavu
    for i in range(6):
        a = i / 6 * math.tau + math.pi / 6
        if abs(math.sin(a) + 1) < 0.2:
            continue
        cx, cz = math.cos(a), math.sin(a)
        if cz < -0.5:
            continue
        pts = curve((cx * 0.45, 0.2, cz * 0.45), (cx * 0.8, 0.0, cz * 0.8), (cx * 0.78, -0.55, cz * 0.78 + 0.05), 7)
        b.tube(pts, 0.28, 0.12, pink)
        b.ball(0.16, (cx * 0.86, -0.62, cz * 0.86 + 0.05), light)
    return b


def halo():
    b = new("Halo")
    glow = rgb(255, 240, 140)
    ring(b, 0.55, 0.75, 16, 0.24, 0.1, 0.12, glow, "Neon", kind="ell")
    ring(b, 0.55, 0.75, 8, 0.1, 0.12, 0.08, WHITE, "Neon", kind="box", offset=0.2)
    for side in (-1, 1):
        for j in range(3):
            b.ell((0.06, 0.18, 0.5 - j * 0.1), (side * (0.66 + j * 0.03), -0.05 + j * 0.13, 0.35 + j * 0.06), WHITE, "Fabric", rot=(-35, 0, side * -10))
    return b


def dragon_horns():
    b = new("DragonHorns")
    red, gold = rgb(200, 40, 60), rgb(255, 200, 60)
    for side in (-1, 1):
        pts = curve((side * 0.32, 0.05, -0.2), (side * 0.6, 0.65, 0.05), (side * 0.45, 0.95, 0.55), 9)
        b.tube(pts, 0.32, 0.07, red, "Smooth", c1=gold)
        b.ell((0.35, 0.15, 0.35), (side * 0.32, 0.02, -0.2), gold, "Metal")
    for i in range(4):
        b.wedge((0.06, 0.25 - i * 0.03, 0.22), (0, 0.38 - i * 0.08, -0.1 + i * 0.22), red, rot=(0, 180, 0))
    b.gem(0.18, (0, 0.1, -0.6), gold, "Neon", rot=(0, 45, 0))
    return b


def rainbow_wig():
    b = new("RainbowWig")
    cols = [rgb(255, 80, 80), rgb(255, 170, 40), rgb(255, 230, 60), rgb(80, 210, 90), rgb(60, 150, 255), rgb(170, 80, 255), rgb(255, 120, 220)]
    k = 0
    for layer, (y, r, n, d) in enumerate(((0.65, 0.0, 1, 0.7), (0.45, 0.45, 7, 0.55), (0.1, 0.7, 10, 0.5), (-0.3, 0.75, 9, 0.48))):
        for i in range(n):
            a = i / n * math.tau + layer * 0.3
            x, z = math.cos(a) * r, math.sin(a) * r
            if layer >= 2 and z < -0.35 and abs(x) < 0.55:
                continue  # obličej nechat volný
            b.ball(d, (x, y, z + 0.05), cols[k % len(cols)], "Fabric")
            k += 1
    return b


def ice_crown():
    b = new("IceCrown")
    ice = rgb(170, 230, 255)
    ring(b, 0.64, 0.02, 12, 0.36, 0.22, 0.1, ice, "Glass")
    for i in range(10):
        a = i / 10 * math.tau
        h = 0.55 if i % 2 == 0 else 0.35
        x, z = math.cos(a) * 0.65, math.sin(a) * 0.65
        b.box((0.14, h, 0.14), (x, 0.13 + h / 2, z), ice if i % 2 else WHITE, "Glass", rot=(0, 45 - math.degrees(a), 0))
        b.wedge((0.14, 0.16, 0.14), (x, 0.13 + h + 0.08, z), WHITE, "Ice", rot=(0, -math.degrees(a), 0))
    b.gem(0.22, (0, 0.2, -0.68), rgb(120, 200, 255), "Neon")
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        b.wedge((0.06, 0.18, 0.06), (math.cos(a) * 0.66, -0.17, math.sin(a) * 0.66), WHITE, "Ice", rot=(180, 0, 0))
    return b


def sea_king_crown():
    b = new("SeaKingCrown")
    aqua, pearl, coral = rgb(60, 200, 230), rgb(250, 245, 240), rgb(255, 120, 110)
    ring(b, 0.66, 0.05, 14, 0.32, 0.28, 0.1, GOLD, "Foil")
    for i in range(7):
        a = i / 7 * math.tau - math.pi / 2
        x, z = math.cos(a) * 0.66, math.sin(a) * 0.66
        front = i == 0
        h = 0.65 if front else 0.42
        b.box((0.1, h, 0.1), (x, 0.2 + h / 2, z), GOLD, "Foil")
        if front:
            # trojzubec vepředu
            for dx in (-0.14, 0, 0.14):
                b.wedge((0.08, 0.22, 0.08), (x + dx, 0.2 + h + 0.08 - (0.06 if dx else 0), z), GOLD, "Foil")
            b.box((0.36, 0.06, 0.08), (x, 0.2 + h - 0.05, z), GOLD, "Foil")
        else:
            b.ball(0.16, (x, 0.2 + h + 0.06, z), pearl)
    for i in range(14):
        a = i / 14 * math.tau
        b.gem(0.1, (math.cos(a) * 0.72, 0.05, math.sin(a) * 0.72), aqua if i % 2 else coral, "Glass")
    # mušličky
    for side in (-1, 1):
        for j in range(4):
            b.wedge((0.06, 0.2, 0.12), (side * 0.7, 0.12, -0.15 + j * 0.05), coral, rot=(0, 90 * side, -30 + j * 20))
    return b


def captain_hat():
    b = new("CaptainHat")
    navy = rgb(30, 40, 90)
    b.cyl((0.3, 1.38, 1.38), (0, 0.0, 0), navy, "Fabric", rot=(0, 0, 90))
    b.ell((1.75, 0.35, 1.8), (0, 0.32, 0.05), WHITE, "Fabric")
    b.cyl((0.12, 1.75, 1.8), (0, 0.35, 0.05), WHITE, "Fabric", rot=(0, 0, 90))
    b.ell((1.0, 0.1, 0.6), (0, -0.1, -0.75), BLACK, rot=(-10, 0, 0))
    b.box((0.9, 0.05, 0.05), (0, 0.06, -0.69), GOLD, "Metal")
    # kotva
    b.box((0.05, 0.25, 0.04), (0, 0.15, -0.72), GOLD, "Metal")
    b.box((0.16, 0.04, 0.04), (0, 0.24, -0.72), GOLD, "Metal")
    b.ell((0.24, 0.08, 0.04), (0, 0.04, -0.72), GOLD, "Metal")
    for side in (-1, 1):
        b.ell((0.4, 0.15, 0.1), (side * 0.28, 0.15, -0.7), GOLD, "Metal", rot=(0, 0, side * 20))
    return b


def pirate_hat():
    b = new("PirateHat")
    black, gold = rgb(35, 35, 40), GOLD
    b.ell((1.4, 0.9, 1.45), (0, 0.1, 0.02), black, "Fabric")
    for i in range(3):
        a = math.radians(-90 + i * 120)
        x, z = math.cos(a) * 0.62, math.sin(a) * 0.62
        ry = -math.degrees(a) - 90
        b.ell((1.45, 0.7, 0.14), (x, 0.28, z), black, "Fabric", rot=yaw_tilt(ry, 20))
    b.cyl((0.1, 1.44, 1.44), (0, -0.04, 0.02), gold, "Fabric", rot=(0, 0, 90))
    # lebka
    b.ball(0.26, (0, 0.3, -0.72), WHITE)
    b.ell((0.16, 0.1, 0.1), (0, 0.18, -0.72), WHITE)
    for side in (-1, 1):
        b.ball(0.07, (side * 0.06, 0.32, -0.84), black)
        b.box((0.4, 0.05, 0.05), (0, 0.05, -0.72), WHITE, rot=(0, 0, side * 35))
    b.ell((0.12, 0.45, 0.06), (0.45, 0.6, 0.3), rgb(230, 60, 60), "Fabric", rot=(0, 0, -30))
    return b


def golden_bow_hat():
    b = new("GoldenBowHat")
    red = rgb(230, 40, 50)
    b.cyl((0.22, 1.36, 1.36), (0, -0.02, 0), GOLD, "Foil", rot=(0, 0, 90))
    for i in range(8):
        a = i / 8 * math.tau
        b.gem(0.1, (math.cos(a) * 0.69, -0.02, math.sin(a) * 0.69), WHITE, "Glass")
    for side in (-1, 1):
        b.ell((0.75, 0.6, 0.3), (side * 0.38, 0.55, -0.05), red, "Fabric", rot=(0, 0, side * -25))
        b.ell((0.45, 0.3, 0.32), (side * 0.38, 0.55, -0.06), rgb(180, 25, 35), "Fabric", rot=(0, 0, side * -25))
        b.ell((0.2, 0.55, 0.14), (side * 0.22, 0.2, -0.1), red, "Fabric", rot=(0, 0, side * 25))
    b.ball(0.32, (0, 0.55, -0.08), GOLD, "Foil")
    star(b, (0, 0.55, -0.26), 0.14, WHITE)
    return b


HATS = [
    baseball_cap, straw_hat, swim_cap, diving_goggles, fishing_hat, propeller_cap, chef_hat, cowboy_hat,
    shark_hood, flower_crown, wizard_hat, knight_helmet, viking_helmet, astronaut_helmet, octopus_buddy,
    halo, dragon_horns, rainbow_wig, ice_crown, sea_king_crown, captain_hat, pirate_hat, golden_bow_hat,
]


def main():
    write_all([f() for f in HATS], OUT_DIR)


if __name__ == "__main__":
    main()
