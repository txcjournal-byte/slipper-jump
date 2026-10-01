"""Generátor modelů bot z dílů (pro Rojo jako .model.json do assets/Slippers).

Spuštění:  python3 tools/shoes.py
Každá bota je jeden kus, špička míří na -Z, podrážka je dole (y = 0).
Hra si model sama zmenší na správnou velikost (src/shared/Models.luau).
"""

from __future__ import annotations

import math
import os

from modelkit import Build, rgb, write_all

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "Slippers")


# ===================== Pantofle (domácí bačkory) =====================

def slipper_base(s: Build, upper, sole, footbed, rim, upper_mat="Fabric", sole_mat="Smooth"):
    """Bačkora: tlustá zaoblená podrážka, měkká stélka a nártová kopule vepředu."""
    s.ell((1.45, 0.5, 2.9), (0, 0.2, 0), sole, sole_mat)
    s.ell((1.4, 0.3, 2.8), (0, 0.08, 0), sole, sole_mat)
    s.ell((1.3, 0.16, 2.65), (0, 0.42, 0.05), footbed, "Fabric")
    # kopule přes prsty a nárt
    s.ell((1.42, 1.15, 1.75), (0, 0.42, -0.5), upper, upper_mat)
    # lem otvoru (lemovka)
    s.ell((1.46, 0.75, 0.24), (0, 0.5, 0.3), rim, "Fabric", rot=(-15, 0, 0))
    # pruh na podrážce
    s.ell((1.48, 0.12, 2.93), (0, 0.04, 0), rim, sole_mat)


def basic_black():
    s = Build("BasicBlackSlippers")
    black, gray, sole = rgb(32, 32, 38), rgb(120, 120, 130), rgb(225, 225, 230)
    slipper_base(s, black, sole, rgb(70, 70, 80), gray)
    # prošívání na kopuli
    for i in range(5):
        x = -0.48 + i * 0.24
        s.box((0.06, 0.04, 0.16), (x, 0.88, -0.75 + abs(x) * 0.3), gray, "Fabric", rot=(-30, 0, 0))
    # bambulka
    s.ball(0.42, (0, 1.02, -0.62), rgb(70, 70, 80), "Fabric")
    s.ball(0.2, (0.12, 1.12, -0.74), rgb(110, 110, 120), "Fabric")
    return s


def beach_blue():
    s = Build("BeachBlueSlippers")
    blue, white, light = rgb(30, 135, 255), rgb(255, 255, 255), rgb(140, 220, 255)
    slipper_base(s, blue, white, rgb(255, 240, 200), white, upper_mat="Smooth")
    # vlnka přes kopuli
    for i in range(6):
        x = -0.6 + i * 0.24
        s.ell((0.3, 0.14, 0.3), (x, 0.78 + (0.05 if i % 2 else -0.02), -0.95 + abs(x) * 0.25), white)
    # kapky vody
    for x, y, z, d in ((-0.25, 1.06, -0.45, 0.3), (0.3, 1.0, -0.6, 0.24), (0.05, 0.98, -0.9, 0.2)):
        s.ball(d, (x, y, z), light, "Glass")
        s.wedge((d * 0.5, d * 0.7, d * 0.5), (x, y + d * 0.55, z), light, "Glass", rot=(0, 45, 0))
    # sluníčko na boku
    s.ball(0.32, (0.7, 0.5, -0.35), rgb(255, 215, 60), "Neon")
    return s


def watermelon():
    s = Build("WatermelonSlippers")
    red, green, dark, white = rgb(255, 75, 95), rgb(60, 185, 70), rgb(25, 110, 40), rgb(250, 250, 235)
    # podrážka = slupka (tmavě zelená, světle zelená, bílá)
    s.ell((1.45, 0.5, 2.9), (0, 0.2, 0), dark)
    s.ell((1.4, 0.3, 2.8), (0, 0.08, 0), dark)
    s.ell((1.4, 0.14, 2.86), (0, 0.38, 0), green)
    s.ell((1.32, 0.14, 2.7), (0, 0.46, 0.04), white, "Fabric")
    # kopule = dužina se slupkou dole
    s.ell((1.46, 1.15, 1.78), (0, 0.38, -0.5), green)
    s.ell((1.38, 1.15, 1.7), (0, 0.48, -0.5), red, "Fabric")
    s.ell((1.48, 0.75, 0.24), (0, 0.5, 0.3), green, "Fabric", rot=(-15, 0, 0))
    # pruhy na slupce
    for x in (-0.55, -0.2, 0.2, 0.55):
        s.ell((0.16, 0.12, 2.6), (x, 0.14, 0), green)
    # semínka
    for x, z, y in ((-0.35, -0.95, 0.88), (0.0, -1.05, 0.83), (0.35, -0.95, 0.88), (-0.2, -0.6, 1.0), (0.2, -0.6, 1.0), (-0.45, -0.4, 0.92), (0.45, -0.4, 0.92)):
        s.ell((0.1, 0.07, 0.18), (x, y, z), rgb(20, 20, 20), rot=(-30, 0, 0))
    # lísteček a stopka na patě
    s.box((0.08, 0.35, 0.08), (0, 0.65, 1.3), rgb(110, 80, 40), rot=(20, 0, 0))
    s.ell((0.35, 0.06, 0.2), (0.12, 0.8, 1.35), green, rot=(0, 30, 20))
    return s


def shark():
    s = Build("SharkSlippers")
    gray, belly, dark = rgb(105, 125, 150), rgb(245, 245, 245), rgb(70, 85, 105)
    slipper_base(s, gray, belly, rgb(200, 215, 230), dark, upper_mat="Smooth")
    # bílé bříško na kopuli
    s.ell((1.2, 0.5, 1.6), (0, 0.5, -0.62), belly)
    # tlama a zuby
    s.ell((1.0, 0.16, 0.5), (0, 0.6, -1.2), rgb(200, 40, 60))
    for i in range(6):
        x = -0.4 + i * 0.16
        s.wedge((0.1, 0.14, 0.1), (x, 0.72, -1.27 + abs(x) * 0.25), belly, rot=(180, 0, 0))
        s.wedge((0.1, 0.12, 0.1), (x, 0.5, -1.25 + abs(x) * 0.25), belly)
    # oči
    for side in (-1, 1):
        s.ball(0.28, (side * 0.42, 0.95, -0.85), belly)
        s.ball(0.16, (side * 0.45, 0.97, -0.95), rgb(15, 15, 20))
        s.ball(0.06, (side * 0.42, 1.03, -1.01), belly)
        # žábry
        for j in range(3):
            s.box((0.04, 0.22, 0.04), (side * 0.7, 0.62, -0.25 + j * 0.12), dark)
        # boční ploutve
        s.wedge((0.08, 0.35, 0.5), (side * 0.78, 0.35, -0.1), gray, rot=(0, 0, side * 50))
    # hřbetní ploutev
    s.wedge((0.16, 0.85, 0.75), (0, 1.33, -0.25), gray, rot=(0, 180, 0))
    s.wedge((0.16, 0.85, 0.25), (0, 1.33, -0.75), gray)
    # ocas na patě
    s.wedge((0.12, 0.6, 0.45), (0, 0.85, 1.45), gray, rot=(0, 0, 0))
    s.wedge((0.12, 0.45, 0.4), (0, 0.42, 1.55), gray, rot=(180, 0, 0))
    return s


def royal_diamond():
    s = Build("RoyalDiamondSlippers")
    ice, gold, ruby, emerald, white = rgb(120, 220, 255), rgb(255, 205, 50), rgb(230, 30, 70), rgb(40, 210, 120), rgb(255, 255, 255)
    s.ell((1.5, 0.52, 2.95), (0, 0.2, 0), gold, "Foil")
    s.ell((1.45, 0.3, 2.85), (0, 0.08, 0), gold, "Foil")
    s.ell((1.32, 0.16, 2.7), (0, 0.43, 0.05), rgb(150, 30, 60), "Fabric")
    s.ell((1.44, 1.2, 1.8), (0, 0.42, -0.5), ice, "Glass")
    s.ell((1.48, 0.78, 0.26), (0, 0.5, 0.3), gold, "Foil", rot=(-15, 0, 0))
    # zlatý pás s drahokamy po obvodu podrážky
    s.ell((1.54, 0.12, 2.99), (0, 0.3, 0), gold, "Metal")
    for i in range(8):
        a = i / 8 * math.pi * 2
        s.gem(0.16, (math.cos(a) * 0.76, 0.32, math.sin(a) * 1.48), ruby if i % 2 else emerald)
    # diamanty na kopuli
    for x, z in ((-0.35, -0.9), (0.35, -0.9), (0, -1.1), (-0.5, -0.5), (0.5, -0.5)):
        s.gem(0.2, (x, 0.88 + (0.08 if abs(x) < 0.4 else -0.05), z), white)
    # koruna
    s.cyl((0.32, 0.72, 0.72), (0, 1.1, -0.45), gold, "Foil", rot=(0, 0, 90))
    s.cyl((0.08, 0.76, 0.76), (0, 0.97, -0.45), gold, "Metal", rot=(0, 0, 90))
    for i in range(6):
        a = i / 6 * math.pi * 2
        x, z = math.cos(a) * 0.3, -0.45 + math.sin(a) * 0.3
        s.wedge((0.1, 0.3, 0.16), (x, 1.4, z), gold, "Foil", rot=(0, -math.degrees(a) + 90, 0))
        s.ball(0.11, (x, 1.58, z), white, "Glass")
    s.gem(0.22, (0, 1.12, -0.82), ruby, rot=(0, 45, 0))
    s.ball(0.24, (0, 1.32, -0.45), ruby, "Glass")
    return s


# ===================== Tenisky =====================

def sneaker_base(s: Build, upper, toe, sole, outsole, accent, lace, collar, high_top=False, upper_mat="Smooth", sole_mat="Smooth"):
    """Tenisa: buclatá podrážka, svršek ze tří elipsoidů, jazyk, tkaničky."""
    # podrážka
    s.ell((1.42, 0.55, 2.95), (0, 0.24, 0), sole, sole_mat)
    s.ell((1.4, 0.36, 2.9), (0, 0.12, 0), sole, sole_mat)
    s.ell((1.45, 0.14, 2.98), (0, 0.02, 0), outsole)
    # svršek
    s.ell((1.25, 0.95, 1.5), (0, 0.5, -0.65), upper, upper_mat)
    s.ell((1.3, 1.25, 1.7), (0, 0.66, 0.2), upper, upper_mat)
    s.ell((1.22, 1.35, 1.0), (0, 0.8, 0.85), upper, upper_mat)
    # špička
    s.ell((1.28, 0.62, 0.95), (0, 0.42, -1.0), toe, "Smooth")
    # jazyk a otvor
    s.ell((0.72, 0.3, 1.0), (0, 1.22, -0.05), accent, upper_mat, rot=(25, 0, 0))
    s.ell((0.9, 0.18, 0.75), (0, 1.36 if not high_top else 2.0, 0.6), collar, "Fabric")
    # tkaničky
    for i in range(4):
        z = -0.45 + i * 0.17
        y = 0.68 + 0.625 * math.sqrt(max(0.0, 1 - ((z - 0.2) / 0.85) ** 2))
        s.box((0.82, 0.08, 0.1), (0, y, z), lace, "Fabric", rot=(-20, 0, 0))
    s.ell((0.25, 0.08, 0.35), (0.42, 1.28, 0.2), lace, "Fabric", rot=(0, 30, 60))
    # patní poutko
    s.ell((0.32, 0.5, 0.16), (0, 1.2 if not high_top else 1.85, 1.3), accent, rot=(-15, 0, 0))
    if high_top:
        s.ell((1.18, 1.3, 1.1), (0, 1.45, 0.62), upper, upper_mat)
        s.ell((1.22, 0.24, 1.14), (0, 1.98, 0.62), accent)


def muddy_old():
    s = Build("MuddyOldSneakers")
    brown, mud, tan = rgb(130, 100, 70), rgb(85, 62, 40), rgb(195, 175, 140)
    sneaker_base(s, brown, rgb(160, 140, 110), tan, mud, rgb(100, 80, 60), rgb(175, 160, 130), rgb(60, 45, 30), upper_mat="Fabric")
    # bláto
    for x, y, z, w in ((-0.66, 0.35, -0.6, 0.55), (0.66, 0.3, 0.4, 0.7), (0.0, 0.25, -1.4, 0.6), (-0.6, 0.6, 0.7, 0.4), (0.5, 0.7, -0.4, 0.35)):
        s.ell((0.18, w * 0.6, w), (x, y, z), mud)
    s.ball(0.25, (0.25, 0.85, -0.95), mud)
    # záplata
    s.box((0.06, 0.4, 0.4), (-0.66, 0.75, 0.05), rgb(200, 70, 60), "Fabric", rot=(15, 0, 0))
    for i in range(3):
        s.box((0.07, 0.04, 0.48), (-0.68, 0.62 + i * 0.13, 0.05), rgb(240, 220, 180), "Fabric", rot=(15, 0, 0))
    # díra na špičce s prstem
    s.ball(0.32, (0.3, 0.68, -1.25), rgb(255, 200, 160))
    return s


def canvas_kicks():
    s = Build("CanvasKicks")
    canvas, red, white, navy = rgb(238, 236, 228), rgb(210, 45, 50), rgb(255, 255, 255), rgb(30, 40, 80)
    sneaker_base(s, canvas, white, white, rgb(200, 50, 50), red, navy, navy, upper_mat="Fabric")
    # červený a modrý proužek na podrážce
    s.ell((1.46, 0.07, 3.0), (0, 0.32, 0), red)
    s.ell((1.46, 0.05, 3.0), (0, 0.2, 0), navy)
    # gumová špička s rýhami
    for i in range(3):
        s.box((0.8, 0.04, 0.05), (0, 0.5 + i * 0.07, -1.4 + i * 0.03), rgb(215, 215, 215))
    # kulaté kovové očka u tkaniček
    for i in range(4):
        for side in (-1, 1):
            z = -0.45 + i * 0.17
            y = 0.66 + 0.625 * math.sqrt(max(0.0, 1 - ((z - 0.2) / 0.85) ** 2))
            s.cyl((0.04, 0.1, 0.1), (side * 0.44, y, z), rgb(200, 200, 210), "Metal", rot=(0, 0, 90 + side * 20))
    # kulatá nášivka na boku (vlastní znak, žádné logo)
    for side in (-1, 1):
        s.cyl((0.05, 0.42, 0.42), (side * 0.66, 0.85, 0.75), white, "Fabric")
        s.cyl((0.06, 0.32, 0.32), (side * 0.67, 0.85, 0.75), red, "Fabric")
        s.gem(0.14, (side * 0.7, 0.85, 0.75), white, "Smooth", rot=(45, 0, 0))
    return s


def street_runners():
    s = Build("StreetRunners")
    blue, white, cyan, dark = rgb(45, 105, 225), rgb(255, 255, 255), rgb(90, 220, 255), rgb(25, 35, 70)
    sneaker_base(s, blue, rgb(35, 85, 200), white, dark, white, white, dark, upper_mat="Fabric")
    # vzduchová okénka v podrážce
    for side in (-1, 1):
        for z in (0.55, 0.95):
            s.ell((0.08, 0.26, 0.32), (side * 0.7, 0.22, z), cyan, "Glass", transparency=0.15)
    # bílá vlnovka na boku
    for side in (-1, 1):
        for i in range(5):
            z = -0.6 + i * 0.32
            s.ell((0.06, 0.12, 0.38), (side * 0.66, 0.6 + 0.12 * math.sin(i * 1.4), z), white, rot=(math.degrees(0.3 * math.cos(i * 1.4)), 0, 0))
    # reflexní pata
    s.ell((0.9, 0.35, 0.2), (0, 0.85, 1.36), rgb(230, 240, 255), "Foil")
    return s


def flame(s: Build, x, y, z, h, color_out, color_in, side):
    """Plamínek na boku boty (z klínů a koule)."""
    s.wedge((0.06, h, h * 0.55), (x, y, z), color_out, "Neon", rot=(0, 0, 0))
    s.wedge((0.06, h * 0.6, h * 0.35), (x + side * 0.02, y - h * 0.12, z + h * 0.05), color_in, "Neon")
    s.ell((0.06, h * 0.45, h * 0.6), (x, y - h * 0.42, z + h * 0.1), color_out, "Neon")


def sky_dunk():
    s = Build("SkyDunkLegends")
    red, black, white, orange, yellow = rgb(205, 30, 40), rgb(22, 22, 28), rgb(255, 255, 255), rgb(255, 120, 20), rgb(255, 225, 60)
    sneaker_base(s, red, black, white, black, black, white, black, high_top=True)
    # černé panely
    for side in (-1, 1):
        s.ell((0.08, 0.7, 1.2), (side * 0.64, 0.75, -0.15), black)
        s.ell((0.08, 0.9, 0.6), (side * 0.6, 1.35, 0.8), black)
        # plameny podél boku
        for i, h in enumerate((0.55, 0.75, 0.6, 0.45)):
            flame(s, side * 0.7, 0.4 + h * 0.5, -0.9 + i * 0.42, h, orange, yellow, side)
        # křídla u kotníku
        for j in range(3):
            s.ell((0.06, 0.18, 0.75 - j * 0.15), (side * (0.66 + j * 0.03), 1.6 + j * 0.16, 1.1 + j * 0.12), white, rot=(-35, 0, 0))
    # zlatá hvězda na jazyku
    s.gem(0.2, (0, 1.42, -0.2), yellow, "Neon", rot=(0, 0, 45))
    return s


def golden_air():
    s = Build("GoldenAirKings")
    gold, deep, diamond, white, ruby = rgb(255, 200, 40), rgb(210, 150, 20), rgb(140, 235, 255), rgb(255, 255, 255), rgb(230, 30, 70)
    sneaker_base(s, gold, deep, white, deep, diamond, white, deep, high_top=True, upper_mat="Foil")
    s.ell((1.46, 0.08, 3.0), (0, 0.3, 0), gold, "Metal")
    # diamanty po boku a na špičce
    for side in (-1, 1):
        for i in range(4):
            s.gem(0.2, (side * 0.66, 0.6 + (i % 2) * 0.2, -0.6 + i * 0.35), diamond)
        # vzduchové okno v podrážce
        s.ell((0.08, 0.26, 0.5), (side * 0.7, 0.22, 0.8), diamond, "Glass", transparency=0.1)
    s.gem(0.26, (0, 0.82, -1.15), diamond)
    # koruna na kotníku
    s.cyl((0.28, 0.7, 0.7), (0, 2.25, 0.62), gold, "Foil", rot=(0, 0, 90))
    for i in range(5):
        a = i / 5 * math.pi * 2
        x, z = math.cos(a) * 0.3, 0.62 + math.sin(a) * 0.3
        s.wedge((0.1, 0.3, 0.16), (x, 2.53, z), gold, "Foil", rot=(0, -math.degrees(a) + 90, 0))
        s.ball(0.1, (x, 2.7, z), ruby if i % 2 else white, "Glass")
    s.gem(0.2, (0, 2.27, 0.27), ruby, rot=(0, 45, 0))
    return s


# ===================== Další pantofle =====================

WHITE = rgb(255, 255, 255)
BLACK = rgb(20, 20, 25)


def eyes(s: Build, y, z, spread, d, x0=0.0, look=-1):
    for side in (-1, 1):
        s.ball(d, (x0 + side * spread, y, z), WHITE)
        s.ball(d * 0.55, (x0 + side * spread, y + d * 0.05, z + look * d * 0.32), BLACK)
        s.ball(d * 0.18, (x0 + side * spread - d * 0.1, y + d * 0.2, z + look * d * 0.5), WHITE)


def bolt(s: Build, x, y, z, h, color, material="Neon", width=0.06):
    """Blesk z tří šikmých kvádrů (na boku boty, plochý ve směru X)."""
    s.box((width, h * 0.45, h * 0.12), (x, y + h * 0.3, z - h * 0.05), color, material, rot=(-30, 0, 0))
    s.box((width, h * 0.12, h * 0.4), (x, y + h * 0.05, z), color, material)
    s.box((width, h * 0.45, h * 0.12), (x, y - h * 0.22, z + h * 0.08), color, material, rot=(-30, 0, 0))


def star(s: Build, pos, d, color, material="Neon"):
    s.gem(d, pos, color, material, rot=(0, 45, 45))
    s.gem(d * 0.8, pos, color, material, rot=(45, 0, 0))


def fluffy_bunny():
    s = Build("FluffyBunnySlippers")
    pink, rose, white = rgb(255, 222, 236), rgb(255, 150, 195), rgb(255, 250, 252)
    slipper_base(s, pink, white, rose, white)
    # chlupaté kuličky kolem lemu
    for i in range(7):
        a = math.pi * (i / 6)
        s.ball(0.32, (math.cos(a) * 0.68, 0.72 + math.sin(a) * 0.12, 0.3), white, "Fabric")
    # uši
    for side in (-1, 1):
        s.ell((0.36, 1.25, 0.24), (side * 0.32, 1.35, -0.35), pink, "Fabric", rot=(-12, 0, -side * 14))
        s.ell((0.2, 0.95, 0.1), (side * 0.32, 1.33, -0.47), rose, "Fabric", rot=(-12, 0, -side * 14))
    eyes(s, 0.82, -1.08, 0.27, 0.26)
    s.ell((0.2, 0.13, 0.12), (0, 0.62, -1.3), rose)
    for side in (-1, 1):
        s.ell((0.24, 0.12, 0.08), (side * 0.48, 0.58, -1.12), rgb(255, 170, 200), rot=(0, side * 30, 0))
    # ocásek
    s.ball(0.45, (0, 0.6, 1.4), white, "Fabric")
    return s


def rubber_duck():
    s = Build("RubberDuckSlippers")
    yellow, orange = rgb(255, 215, 35), rgb(255, 135, 20)
    slipper_base(s, yellow, rgb(80, 180, 255), rgb(255, 245, 190), orange, upper_mat="Smooth")
    # hlava kachničky na špičce
    s.ball(0.95, (0, 1.05, -0.7), yellow)
    s.ell((0.6, 0.2, 0.5), (0, 0.98, -1.18), orange)
    s.ell((0.5, 0.12, 0.4), (0, 0.86, -1.12), orange)
    eyes(s, 1.2, -1.05, 0.2, 0.2)
    # chocholka
    for i in range(3):
        s.ell((0.08, 0.3, 0.12), (-0.08 + i * 0.08, 1.55, -0.68), yellow, rot=(0, 0, -20 + i * 20))
    # křidélka
    for side in (-1, 1):
        s.ell((0.18, 0.4, 0.75), (side * 0.72, 0.6, -0.2), yellow, rot=(-15, 0, side * 20))
    # bublinky
    for x, z, d in ((0.45, 0.95, 0.24), (-0.45, 1.1, 0.2), (0.0, 1.3, 0.16)):
        s.ball(d, (x, 0.42, z), rgb(200, 240, 255), "Glass", transparency=0.2)
    return s


def pineapple():
    s = Build("PineappleSlippers")
    yellow, dark, green = rgb(255, 190, 40), rgb(200, 130, 20), rgb(60, 170, 60)
    slipper_base(s, yellow, rgb(255, 230, 140), rgb(255, 245, 200), dark, upper_mat="Smooth")
    # kosočtverečný vzor
    for row in range(3):
        for col in range(4):
            x = -0.45 + col * 0.3 + (0.15 if row % 2 else 0)
            z = -1.05 + row * 0.28
            y = 0.42 + 0.575 * math.sqrt(max(0.0, 1 - (x / 0.71) ** 2 - ((z + 0.5) / 0.875) ** 2)) + 0.02
            if abs(x) < 0.62:
                s.gem(0.12, (x, y, z), dark, "Smooth", rot=(0, 45, 0))
    # listy nahoře
    for i in range(7):
        a = -60 + i * 20
        s.wedge((0.1, 0.8 - abs(i - 3) * 0.12, 0.25), (math.sin(math.radians(a)) * 0.15, 1.3, -0.45 + math.cos(math.radians(a)) * 0.05), green, rot=(0, a, -a * 0.4))
    return s


def penguin():
    s = Build("PenguinSlippers")
    black, white, orange = rgb(32, 36, 52), rgb(255, 255, 255), rgb(255, 160, 30)
    slipper_base(s, black, rgb(170, 220, 255), rgb(230, 245, 255), white, upper_mat="Smooth")
    s.ell((1.1, 0.95, 0.9), (0, 0.5, -1.0), white)
    eyes(s, 0.92, -1.2, 0.24, 0.24)
    s.wedge((0.3, 0.18, 0.3), (0, 0.7, -1.48), orange, rot=(0, 180, 0))
    for side in (-1, 1):
        s.ell((0.12, 0.6, 0.45), (side * 0.75, 0.6, -0.3), black, rot=(0, 0, side * 25))
        s.ell((0.22, 0.12, 0.12), (side * 0.36, 0.72, -1.25), rgb(255, 150, 170))
        # nožičky
        s.ell((0.3, 0.12, 0.3), (side * 0.3, 0.06, -1.45), orange)
    # čepička se sněhem
    s.ell((0.85, 0.35, 0.7), (0, 1.0, -0.4), rgb(60, 140, 255), "Fabric")
    s.ball(0.3, (0, 1.22, -0.35), white, "Fabric")
    return s


def rainbow():
    s = Build("RainbowSlippers")
    cols = [rgb(255, 70, 70), rgb(255, 165, 40), rgb(255, 230, 60), rgb(80, 210, 90), rgb(60, 150, 255), rgb(170, 80, 255)]
    s.ell((1.45, 0.5, 2.9), (0, 0.2, 0), WHITE)
    s.ell((1.4, 0.3, 2.8), (0, 0.08, 0), WHITE)
    s.ell((1.3, 0.16, 2.65), (0, 0.42, 0.05), rgb(255, 230, 245), "Fabric")
    # bílá kopule s duhovými oblouky přes nárt
    s.ell((1.42, 1.15, 1.75), (0, 0.42, -0.5), WHITE, "Smooth")
    for i, c in enumerate(cols):
        z = -1.1 + i * 0.2
        k = math.sqrt(max(0.0, 1 - ((z + 0.5) / 0.875) ** 2))
        s.ell((1.42 * k * 1.04 + 0.02, 1.15 * k * 1.04 + 0.02, 0.2), (0, 0.42, z), c, "Smooth")
    s.ell((1.46, 0.75, 0.24), (0, 0.5, 0.3), WHITE, "Fabric", rot=(-15, 0, 0))
    # obláčky na koncích duhy
    for side in (-1, 1):
        for j in range(3):
            s.ball(0.42 - j * 0.06, (side * 0.75, 0.35 + j * 0.12, -0.6 + j * 0.25), WHITE, "Fabric")
    for i, c in enumerate(cols):
        s.ell((1.47, 0.05, 2.92), (0, 0.06 + i * 0.05, 0), c)
    return s


def golden():
    s = Build("GoldenSlippers")
    gold, light, deep = rgb(255, 200, 40), rgb(255, 240, 150), rgb(200, 140, 20)
    slipper_base(s, gold, deep, light, light, upper_mat="Foil", sole_mat="Metal")
    # mašle
    s.ell((0.5, 0.35, 0.25), (-0.28, 1.05, -0.65), light, "Foil", rot=(0, 0, 20))
    s.ell((0.5, 0.35, 0.25), (0.28, 1.05, -0.65), light, "Foil", rot=(0, 0, -20))
    s.ball(0.24, (0, 1.05, -0.68), deep, "Metal")
    # zlaté jiskry
    for x, y, z in ((-0.5, 0.75, -1.0), (0.55, 0.65, -0.95), (0.0, 0.85, -1.2), (-0.62, 0.45, 0.6), (0.62, 0.45, 0.6)):
        star(s, (x, y, z), 0.14, rgb(255, 250, 200))
    # mince na patě
    s.cyl((0.08, 0.45, 0.45), (0, 0.6, 1.3), gold, "Metal", rot=(0, 90, 0))
    return s


def spring():
    s = Build("SpringSlippers")
    mint, metal = rgb(80, 220, 160), rgb(185, 185, 195)
    s.ell((1.45, 0.5, 2.9), (0, 0.75, 0), WHITE)
    s.ell((1.3, 0.16, 2.65), (0, 0.97, 0.05), rgb(220, 255, 240), "Fabric")
    s.ell((1.42, 1.15, 1.75), (0, 0.97, -0.5), mint, "Smooth")
    s.ell((1.46, 0.75, 0.24), (0, 1.05, 0.3), rgb(40, 170, 120), "Fabric", rot=(-15, 0, 0))
    # pružiny pod podrážkou
    for z in (-0.75, 0.75):
        for i in range(5):
            s.cyl((0.07, 0.6, 0.6), (0, 0.12 + i * 0.1, z), metal, "Metal", rot=(0, 0, 90 + (8 if i % 2 else -8)))
        s.cyl((0.08, 0.75, 0.75), (0, 0.04, z), rgb(60, 60, 70), "Smooth", rot=(0, 0, 90))
    eyes(s, 1.35, -1.05, 0.25, 0.24)
    s.ell((0.4, 0.08, 0.1), (0, 1.15, -1.32), rgb(30, 100, 70))
    return s


def rocket():
    s = Build("RocketSlippers")
    red, white, dark = rgb(230, 55, 45), rgb(235, 235, 245), rgb(60, 60, 75)
    slipper_base(s, red, white, rgb(255, 230, 220), white, upper_mat="Smooth")
    # okénko
    s.cyl((0.12, 0.5, 0.5), (0, 0.85, -0.85), white, "Metal", rot=(0, 90, -35))
    s.cyl((0.14, 0.38, 0.38), (0, 0.86, -0.87), rgb(120, 200, 255), "Glass", rot=(0, 90, -35))
    # ploutve na stranách paty
    for side in (-1, 1):
        s.wedge((0.08, 0.6, 0.6), (side * 0.72, 0.6, 1.0), white, rot=(0, 0, 0))
    s.wedge((0.08, 0.6, 0.6), (0, 0.95, 0.95), white)
    # tryska a plamen
    s.cyl((0.45, 0.55, 0.55), (0, 0.5, 1.55), dark, "Metal", rot=(0, 90, 0))
    s.ell((0.42, 0.42, 0.55), (0, 0.5, 1.95), rgb(255, 150, 40), "Neon")
    s.ell((0.24, 0.24, 0.35), (0, 0.5, 2.05), rgb(255, 240, 120), "Neon")
    return s


def dino():
    s = Build("DinoSlippers")
    green, belly, white = rgb(90, 190, 80), rgb(250, 230, 120), WHITE
    slipper_base(s, green, rgb(70, 150, 60), belly, rgb(60, 150, 55), upper_mat="Smooth")
    eyes(s, 1.0, -0.82, 0.3, 0.3)
    s.ell((1.1, 0.25, 0.6), (0, 0.55, -1.2), rgb(200, 60, 70))
    for i in range(5):
        x = -0.36 + i * 0.18
        s.wedge((0.12, 0.16, 0.1), (x, 0.7, -1.32 + abs(x) * 0.3), white, rot=(180, 0, 0))
    # bodliny po hřbetě a ocásek
    for i in range(4):
        z = -0.55 + i * 0.3
        s.wedge((0.1, 0.35 - i * 0.04, 0.3), (0, 1.12 - i * 0.12, z), rgb(255, 170, 40), rot=(0, 180, 0))
    s.ell((0.4, 0.35, 0.8), (0, 0.5, 1.6), green, rot=(15, 0, 0))
    # drápky
    for x in (-0.35, 0, 0.35):
        s.wedge((0.12, 0.15, 0.18), (x, 0.12, -1.5), white, rot=(0, 180, 0))
    return s


def crystal():
    s = Build("CrystalSlippers")
    ice, white, pink = rgb(170, 230, 255), WHITE, rgb(255, 170, 230)
    slipper_base(s, ice, rgb(120, 190, 240), rgb(230, 248, 255), white, upper_mat="Glass", sole_mat="Glass")
    for x, y, z, h, rx, rz, c in ((0, 1.2, -0.5, 0.75, 0, 0, white), (-0.32, 1.05, -0.65, 0.55, -10, 20, pink), (0.32, 1.05, -0.65, 0.55, -10, -20, ice), (-0.15, 1.0, -0.95, 0.45, -30, 10, ice), (0.18, 0.98, -0.95, 0.4, -30, -15, pink)):
        s.box((0.2, h, 0.2), (x, y, z), c, "Glass", rot=(rx, 45, rz))
        s.wedge((0.2, 0.18, 0.2), (x, y + h / 2 + 0.09, z), c, "Glass", rot=(rx, 45, rz))
    for i in range(6):
        a = i / 6 * math.pi * 2
        s.gem(0.14, (math.cos(a) * 0.74, 0.3, math.sin(a) * 1.45), white, "Neon")
    return s


def lava():
    s = Build("LavaSlippers")
    rock, lava_c, glow = rgb(60, 35, 30), rgb(255, 90, 20), rgb(255, 210, 60)
    slipper_base(s, rock, rgb(40, 25, 25), lava_c, lava_c, upper_mat="Smooth")
    # žhavé praskliny
    for x, z, ry in ((-0.35, -0.9, 30), (0.3, -0.75, -40), (0.0, -0.45, 80), (-0.5, -0.4, -20), (0.5, -0.25, 15)):
        y = 0.42 + 0.575 * math.sqrt(max(0.0, 1 - (x / 0.71) ** 2 - ((z + 0.5) / 0.875) ** 2)) - 0.02
        s.box((0.07, 0.07, 0.4), (x, y, z), glow, "Neon", rot=(0, ry, 0))
    s.ell((1.48, 0.1, 2.95), (0, 0.32, 0), lava_c, "Neon")
    # kapky lávy
    for x, z in ((-0.6, -0.9), (0.62, 0.2), (0.0, 1.35)):
        s.ell((0.18, 0.3, 0.18), (x, 0.25, z), lava_c, "Neon")
    # pára
    for x, y, z, d in ((0.15, 1.15, -0.55, 0.3), (-0.12, 1.4, -0.5, 0.24)):
        s.ball(d, (x, y, z), rgb(240, 240, 240), transparency=0.4)
    return s


def cloud_wing():
    s = Build("CloudWingSlippers")
    white, sky = rgb(248, 250, 255), rgb(170, 210, 255)
    s.ell((1.45, 0.5, 2.9), (0, 0.2, 0), sky)
    s.ell((1.4, 0.3, 2.8), (0, 0.08, 0), sky)
    s.ell((1.3, 0.16, 2.65), (0, 0.42, 0.05), white, "Fabric")
    for x, y, z, d in ((0, 0.75, -0.5, 1.0), (-0.38, 0.62, -0.85, 0.7), (0.38, 0.62, -0.85, 0.7), (-0.42, 0.7, -0.2, 0.7), (0.42, 0.7, -0.2, 0.7), (0, 0.6, -1.05, 0.7)):
        s.ball(d, (x, y, z), white, "Fabric")
    # křidélka
    for side in (-1, 1):
        for j in range(3):
            s.ell((0.08, 0.22, 0.85 - j * 0.18), (side * (0.78 + j * 0.04), 0.65 + j * 0.18, 0.55 + j * 0.12), white, rot=(-30, 0, side * -15))
    return s


def robot():
    s = Build("RobotSlippers")
    metal, dark, green = rgb(150, 160, 175), rgb(60, 65, 75), rgb(60, 255, 120)
    slipper_base(s, metal, dark, rgb(90, 95, 105), dark, upper_mat="Metal", sole_mat="Smooth")
    # obrazovka s očima
    s.ell((0.95, 0.5, 0.35), (0, 0.85, -1.05), rgb(20, 25, 30), "Glass", rot=(-35, 0, 0))
    for side in (-1, 1):
        s.box((0.18, 0.12, 0.05), (side * 0.2, 0.92, -1.17), green, "Neon", rot=(-35, 0, 0))
    s.box((0.36, 0.05, 0.05), (0, 0.78, -1.24), green, "Neon", rot=(-35, 0, 0))
    # anténa
    s.cyl((0.6, 0.07, 0.07), (0, 1.25, -0.45), dark, "Metal", rot=(0, 0, 90))
    s.ball(0.2, (0, 1.58, -0.45), rgb(255, 60, 60), "Neon")
    # šrouby a LED po stranách
    for side in (-1, 1):
        for j in range(3):
            s.ball(0.12, (side * 0.72, 0.38, -0.7 + j * 0.6), green if j == 1 else rgb(255, 210, 60), "Neon")
        s.cyl((0.08, 0.2, 0.2), (side * 0.7, 0.7, -0.4), dark, "Metal")
    return s


def galaxy():
    s = Build("GalaxySlippers")
    purple, pink, blue = rgb(60, 30, 120), rgb(255, 120, 255), rgb(80, 160, 255)
    slipper_base(s, purple, rgb(30, 15, 60), rgb(90, 50, 160), pink, upper_mat="Glass")
    s.ell((1.2, 0.8, 1.2), (-0.1, 0.55, -0.6), rgb(110, 50, 170), "Glass", rot=(0, 30, 0))
    for x, z in ((-0.4, -0.9), (0.35, -1.0), (0.1, -0.6), (-0.5, -0.4), (0.5, -0.4), (0.0, -1.2)):
        y = 0.42 + 0.575 * math.sqrt(max(0.0, 1 - (x / 0.71) ** 2 - ((z + 0.5) / 0.875) ** 2))
        star(s, (x, y, z), 0.12, WHITE)
    # planeta s prstencem
    s.ball(0.42, (0.0, 1.2, -0.45), rgb(255, 170, 60))
    s.cyl((0.04, 0.85, 0.85), (0.0, 1.2, -0.45), blue, "Neon", rot=(0, 0, 70))
    for i in range(6):
        a = i / 6 * math.pi * 2
        s.ball(0.1, (math.cos(a) * 0.74, 0.3, math.sin(a) * 1.45), pink, "Neon")
    return s


def dragon():
    s = Build("DragonSlippers")
    red, gold, dark = rgb(200, 40, 60), rgb(255, 200, 60), rgb(140, 20, 40)
    slipper_base(s, red, dark, rgb(255, 220, 160), gold, upper_mat="Smooth")
    # šupiny
    for row in range(2):
        for col in range(4):
            x = -0.42 + col * 0.28 + row * 0.14
            z = -0.95 + row * 0.3
            y = 0.42 + 0.575 * math.sqrt(max(0.0, 1 - (x / 0.71) ** 2 - ((z + 0.5) / 0.875) ** 2))
            if abs(x) < 0.6:
                s.ell((0.24, 0.08, 0.2), (x, y, z), dark)
    eyes(s, 1.0, -0.8, 0.3, 0.28)
    # nozdry a rohy
    for side in (-1, 1):
        s.ball(0.1, (side * 0.15, 0.75, -1.32), dark)
        s.wedge((0.14, 0.5, 0.2), (side * 0.35, 1.3, -0.45), gold, rot=(-20, 0, side * -20))
        # křidélka
        s.wedge((0.06, 0.7, 0.8), (side * 0.75, 0.85, 0.35), gold, rot=(0, 0, side * -35))
    # plamínek z nosu
    s.ell((0.3, 0.25, 0.45), (0, 0.65, -1.6), rgb(255, 140, 30), "Neon")
    s.ell((0.16, 0.14, 0.25), (0, 0.65, -1.72), rgb(255, 240, 120), "Neon")
    # ocas
    s.ell((0.3, 0.3, 0.8), (0, 0.45, 1.65), red, rot=(10, 0, 0))
    s.wedge((0.08, 0.35, 0.35), (0, 0.6, 2.05), gold)
    return s


# ===================== Další tenisky =====================

def taped_up():
    s = Build("TapedUpTrainers")
    gray, tape = rgb(150, 150, 158), rgb(225, 220, 170)
    sneaker_base(s, gray, rgb(120, 120, 128), rgb(200, 195, 185), rgb(90, 90, 95), rgb(110, 110, 118), rgb(190, 180, 150), rgb(70, 70, 75), upper_mat="Fabric")
    # izolepa
    for z, ry in ((-0.7, 12), (0.25, -8), (0.85, 5)):
        s.ell((1.38, 0.32, 0.26), (0, 0.65, z), tape, "Plastic", rot=(0, ry, 0))
    s.box((0.08, 0.3, 0.5), (0.68, 0.95, -0.1), tape, "Plastic", rot=(25, 0, 0))
    # kapka
    s.ell((0.15, 0.25, 0.15), (-0.7, 0.4, -0.95), rgb(130, 200, 255), "Glass")
    return s


def skate_lows():
    s = Build("SkateLows")
    black, red, white = rgb(35, 35, 40), rgb(240, 70, 60), WHITE
    sneaker_base(s, black, black, white, rgb(150, 60, 50), red, white, red, upper_mat="Fabric")
    # šachovnice na boku
    for side in (-1, 1):
        for r in range(2):
            for c in range(4):
                if (r + c) % 2 == 0:
                    s.box((0.05, 0.16, 0.2), (side * 0.66, 0.55 + r * 0.16, -0.3 + c * 0.2), white)
    return s


def court_classics():
    s = Build("CourtClassics")
    white, green, gum = WHITE, rgb(40, 170, 80), rgb(200, 150, 90)
    sneaker_base(s, white, rgb(240, 240, 240), white, gum, green, white, green, high_top=True)
    for side in (-1, 1):
        s.ell((0.08, 0.5, 1.3), (side * 0.63, 0.75, 0.0), green)
        s.ell((0.07, 0.3, 0.4), (side * 0.6, 1.5, 0.8), green)
        # perforace
        for i in range(3):
            s.ball(0.07, (side * 0.62, 0.62, -0.95 + i * 0.15), rgb(200, 200, 200))
    return s


def neon_sprinters():
    s = Build("NeonSprinters")
    lime, black = rgb(190, 255, 40), rgb(30, 30, 35)
    sneaker_base(s, lime, lime, black, rgb(60, 60, 70), black, black, black, upper_mat="Fabric")
    for side in (-1, 1):
        for i in range(3):
            s.box((0.06, 0.08, 1.2 - i * 0.25), (side * 0.66, 0.5 + i * 0.18, 0.15 + i * 0.1), rgb(0, 255, 200), "Neon", rot=(-8, 0, 0))
    # tretry
    for x in (-0.35, 0, 0.35):
        s.wedge((0.1, 0.16, 0.1), (x, -0.1, -0.9), rgb(200, 200, 210), "Metal", rot=(180, 0, 0))
    return s


def graffiti():
    s = Build("GraffitiHighTops")
    pink, cyan, yellow, purple = rgb(255, 120, 200), rgb(80, 220, 255), rgb(255, 230, 60), rgb(150, 80, 255)
    sneaker_base(s, pink, cyan, WHITE, purple, cyan, yellow, purple, high_top=True)
    for side in (-1, 1):
        for x, y, z, d, c in ((0, 0.75, -0.5, 0.35, cyan), (0, 1.0, 0.3, 0.3, yellow), (0, 1.5, 0.8, 0.28, purple), (0, 0.6, 0.6, 0.22, yellow), (0, 1.2, -0.1, 0.18, purple)):
            s.ell((0.06, d, d), (side * (0.63 + 0.02), y, z), c)
    for x, z in ((-0.3, -1.1), (0.25, -0.95)):
        s.ball(0.14, (x, 0.85, z), yellow)
    return s


def lightning_lows():
    s = Build("LightningLows")
    yellow, black = rgb(255, 215, 40), rgb(30, 30, 40)
    sneaker_base(s, yellow, black, WHITE, black, black, black, black)
    for side in (-1, 1):
        bolt(s, side * 0.67, 0.75, 0.1, 0.9, black, "Smooth")
        bolt(s, side * 0.68, 0.75, 0.1, 0.6, rgb(120, 220, 255), "Neon", width=0.07)
    bolt(s, 0, 0.5, 1.4, 0.4, rgb(120, 220, 255), "Neon", width=0.07)
    return s


def ice_breakers():
    s = Build("IceBreakers")
    ice, white = rgb(170, 225, 255), WHITE
    sneaker_base(s, ice, white, rgb(220, 240, 255), rgb(120, 180, 230), white, white, rgb(100, 160, 220), high_top=True, upper_mat="Glass", sole_mat="Ice")
    # rampouchy a vločky
    for i in range(6):
        x = -0.55 + i * 0.22
        s.wedge((0.1, 0.3 - (i % 2) * 0.1, 0.1), (x, -0.05, -0.6 + (i % 3) * 0.6), white, "Ice", rot=(180, 45, 0))
    for side in (-1, 1):
        star(s, (side * 0.67, 1.0, -0.2), 0.2, white)
        star(s, (side * 0.62, 1.6, 0.7), 0.15, white)
    return s


def rocket_boosters():
    s = Build("RocketBoosters")
    red, white, dark = rgb(230, 60, 50), rgb(240, 240, 245), rgb(70, 70, 80)
    sneaker_base(s, red, white, white, dark, white, white, dark)
    for side in (-1, 1):
        s.cyl((0.7, 0.32, 0.32), (side * 0.55, 0.85, 1.35), white, "Metal", rot=(0, 90, 0))
        s.ell((0.25, 0.25, 0.4), (side * 0.55, 0.85, 1.8), rgb(255, 150, 40), "Neon")
        s.wedge((0.06, 0.35, 0.3), (side * 0.75, 0.85, 1.2), red)
    s.cyl((0.12, 0.4, 0.4), (0, 0.9, -0.95), rgb(120, 200, 255), "Glass", rot=(0, 90, -40))
    return s


def lava_stompers():
    s = Build("LavaStompers")
    rock, lava_c = rgb(40, 30, 30), rgb(255, 100, 20)
    sneaker_base(s, rock, rgb(70, 50, 45), rgb(60, 40, 35), lava_c, lava_c, lava_c, rgb(25, 20, 20), high_top=True)
    s.ell((1.47, 0.1, 3.0), (0, 0.28, 0), lava_c, "Neon")
    for side in (-1, 1):
        for y, z, rx in ((0.6, -0.5, 30), (0.9, 0.2, -40), (1.4, 0.7, 20), (0.55, 0.6, -10)):
            s.box((0.06, 0.06, 0.45), (side * 0.66, y, z), rgb(255, 200, 60), "Neon", rot=(rx, 0, 0))
    return s


def thunder_dunks():
    s = Build("ThunderDunks")
    purple, yellow = rgb(70, 40, 160), rgb(255, 230, 60)
    sneaker_base(s, purple, rgb(50, 25, 120), WHITE, rgb(40, 20, 90), yellow, yellow, rgb(40, 20, 90), high_top=True)
    for side in (-1, 1):
        bolt(s, side * 0.67, 0.85, 0.0, 1.0, yellow)
        bolt(s, side * 0.62, 1.55, 0.75, 0.5, yellow)
    # bouřkový mráček na jazyku
    for x, d in ((-0.15, 0.3), (0.12, 0.34), (0.0, 0.26)):
        s.ball(d, (x, 1.5, -0.25), rgb(130, 120, 160))
    return s


def crystal_courts():
    s = Build("CrystalCourts")
    ice, white, pink = rgb(190, 240, 255), WHITE, rgb(255, 180, 240)
    sneaker_base(s, ice, white, white, rgb(150, 210, 240), pink, white, rgb(140, 200, 230), upper_mat="Glass")
    for side in (-1, 1):
        for i, (y, z, h) in enumerate(((0.75, -0.6, 0.45), (0.95, 0.0, 0.6), (0.85, 0.6, 0.5))):
            s.box((0.15, h, 0.15), (side * 0.66, y, z), pink if i == 1 else white, "Glass", rot=(30 - i * 20, 45, side * 20))
    s.gem(0.28, (0, 0.85, -1.15), pink)
    return s


def galaxy_runners():
    s = Build("GalaxyRunners")
    navy, pink, blue = rgb(40, 25, 100), rgb(255, 120, 255), rgb(90, 170, 255)
    sneaker_base(s, navy, rgb(70, 40, 150), rgb(30, 20, 70), pink, pink, WHITE, rgb(20, 10, 50), upper_mat="Glass")
    s.ell((1.47, 0.08, 3.0), (0, 0.3, 0), blue, "Neon")
    for side in (-1, 1):
        s.ell((0.06, 0.6, 1.0), (side * 0.64, 0.8, 0.1), rgb(130, 60, 200), "Glass")
        for y, z in ((0.6, -0.6), (1.0, -0.1), (0.75, 0.5), (1.2, 0.85)):
            star(s, (side * 0.67, y, z), 0.11, WHITE)
        s.ball(0.3, (side * 0.67, 0.95, 0.3), rgb(255, 170, 60))
    return s


def cyber_steppers():
    s = Build("CyberSteppers")
    dark, cyan = rgb(30, 35, 45), rgb(0, 255, 230)
    sneaker_base(s, dark, rgb(45, 50, 60), rgb(50, 55, 65), cyan, cyan, cyan, rgb(15, 15, 20))
    s.ell((1.47, 0.06, 3.0), (0, 0.32, 0), cyan, "Neon")
    for side in (-1, 1):
        # obvodové cestičky
        s.box((0.05, 0.05, 1.1), (side * 0.66, 0.6, -0.1), cyan, "Neon")
        s.box((0.05, 0.4, 0.05), (side * 0.66, 0.78, 0.45), cyan, "Neon")
        s.box((0.05, 0.05, 0.5), (side * 0.66, 0.98, 0.7), cyan, "Neon")
        s.box((0.05, 0.3, 0.05), (side * 0.66, 0.73, -0.65), cyan, "Neon")
        for y, z in ((0.6, 0.45), (0.98, 0.95), (0.88, -0.65)):
            s.ball(0.1, (side * 0.67, y, z), WHITE, "Neon")
    s.box((0.8, 0.1, 0.35), (0, 0.75, -1.2), cyan, "Neon", rot=(-40, 0, 0))
    return s


def dragon_scale():
    s = Build("DragonScaleHighs")
    green, gold, dark = rgb(30, 140, 80), rgb(255, 200, 60), rgb(20, 90, 50)
    sneaker_base(s, green, dark, rgb(240, 220, 160), dark, gold, gold, dark, high_top=True)
    for side in (-1, 1):
        for r in range(3):
            for c in range(4):
                s.ell((0.06, 0.2, 0.22), (side * 0.65, 0.55 + r * 0.25, -0.6 + c * 0.3 + (r % 2) * 0.15), dark)
        s.wedge((0.12, 0.45, 0.25), (side * 0.45, 2.2, 0.7), gold, rot=(-20, 0, side * -25))
    # hřbet
    for i in range(4):
        s.wedge((0.08, 0.3, 0.25), (0, 1.1 + i * 0.25, 1.15 + i * 0.03), gold, rot=(0, 180, 0))
    s.ball(0.3, (0, 0.6, -1.45), rgb(120, 230, 140), transparency=0.3)
    return s


def phantom():
    s = Build("PhantomGlides")
    ghost, lav = rgb(245, 245, 255), rgb(150, 160, 255)
    s.ell((1.42, 0.55, 2.95), (0, 0.24, 0), lav, "Neon", transparency=0.3)
    s.ell((1.25, 0.95, 1.5), (0, 0.5, -0.65), ghost, "Glass", transparency=0.15)
    s.ell((1.3, 1.25, 1.7), (0, 0.66, 0.2), ghost, "Glass", transparency=0.15)
    s.ell((1.22, 1.35, 1.0), (0, 0.8, 0.85), ghost, "Glass", transparency=0.15)
    s.ell((0.9, 0.18, 0.75), (0, 1.36, 0.6), rgb(90, 90, 160), "Fabric")
    eyes(s, 0.85, -1.33, 0.25, 0.26)
    s.ell((0.22, 0.25, 0.1), (0, 0.6, -1.4), rgb(60, 60, 110))
    # ocásek ducha
    for i in range(3):
        s.ell((0.35 - i * 0.08, 0.3 - i * 0.06, 0.4), (0, 0.6 + i * 0.12, 1.45 + i * 0.25), ghost, "Glass", transparency=0.25)
    for side in (-1, 1):
        for y, z in ((0.7, -0.3), (1.0, 0.4)):
            star(s, (side * 0.68, y, z), 0.12, lav)
    return s


SHOES = [
    basic_black, beach_blue, watermelon, fluffy_bunny, shark, rubber_duck, pineapple, penguin, rainbow, golden,
    spring, rocket, dino, crystal, lava, cloud_wing, robot, galaxy, dragon, royal_diamond,
    muddy_old, taped_up, canvas_kicks, street_runners, skate_lows, court_classics, neon_sprinters, graffiti, lightning_lows, ice_breakers,
    rocket_boosters, lava_stompers, thunder_dunks, crystal_courts, galaxy_runners, cyber_steppers, dragon_scale, phantom, sky_dunk, golden_air,
]



def main():
    write_all([f() for f in SHOES], OUT_DIR)


if __name__ == "__main__":
    main()
