"""Generátor hezčích modelů bot z dílů (pro Rojo jako .model.json do assets/Slippers).

Spuštění:  python3 tools/shoes.py
Každá bota je jeden kus, špička míří na -Z, podrážka je dole (y = 0).
Zaoblené tvary jsou díly se SpecialMesh typu Sphere (elipsoid vyplní celý díl).
Hra si model sama zmenší na správnou velikost (src/shared/Models.luau).
"""

from __future__ import annotations

import json
import math
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "Slippers")

MATERIAL = {
    "Plastic": 256,
    "Smooth": 272,
    "Neon": 288,
    "Wood": 512,
    "Marble": 784,
    "Foil": 1040,
    "Metal": 1088,
    "Fabric": 1312,
    "Ice": 1536,
    "Glass": 1568,
}


def rgb(r: int, g: int, b: int) -> tuple:
    return (r / 255, g / 255, b / 255)


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def angles(rx: float = 0, ry: float = 0, rz: float = 0):
    """Jako CFrame.Angles(rx, ry, rz) ve stupních: R = Rx * Ry * Rz."""
    x, y, z = math.radians(rx), math.radians(ry), math.radians(rz)
    rxm = [[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]]
    rym = [[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]]
    rzm = [[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]]
    return mat_mul(mat_mul(rxm, rym), rzm)


class Shoe:
    def __init__(self, name: str):
        self.name = name
        self.parts: list[dict] = []

    def add(self, kind, size, pos, color, material="Smooth", rot=(0, 0, 0), transparency=0.0):
        self.parts.append(
            {
                "kind": kind,
                "size": tuple(max(0.05, s) for s in size),
                "pos": tuple(pos),
                "rot": angles(*rot),
                "color": color,
                "material": material,
                "transparency": transparency,
            }
        )

    # zkratky
    def ell(self, size, pos, color, material="Smooth", rot=(0, 0, 0), transparency=0.0):
        self.add("ellipsoid", size, pos, color, material, rot, transparency)

    def box(self, size, pos, color, material="Smooth", rot=(0, 0, 0), transparency=0.0):
        self.add("block", size, pos, color, material, rot, transparency)

    def cyl(self, size, pos, color, material="Smooth", rot=(0, 0, 0)):
        # Roblox válec má osu ve směru X
        self.add("cylinder", size, pos, color, material, rot)

    def wedge(self, size, pos, color, material="Smooth", rot=(0, 0, 0)):
        self.add("wedge", size, pos, color, material, rot)

    def ball(self, d, pos, color, material="Smooth", transparency=0.0):
        self.add("ellipsoid", (d, d, d), pos, color, material, (0, 0, 0), transparency)

    def gem(self, d, pos, color, material="Glass", rot=(45, 0, 45)):
        self.add("block", (d, d, d), pos, color, material, rot)

    def to_json(self) -> dict:
        children = []
        for i, p in enumerate(self.parts):
            props = {
                "Size": list(p["size"]),
                "CFrame": {"CFrame": {"position": list(p["pos"]), "orientation": p["rot"]}},
                "Color": list(p["color"]),
                "Material": {"Enum": MATERIAL[p["material"]]},
                "Anchored": True,
                "CanCollide": False,
                "TopSurface": {"Enum": 0},
                "BottomSurface": {"Enum": 0},
            }
            if p["transparency"] > 0:
                props["Transparency"] = p["transparency"]
            node: dict = {"name": f"Part{i + 1}", "className": "Part", "properties": props}
            if p["kind"] == "wedge":
                node["className"] = "WedgePart"
            elif p["kind"] == "cylinder":
                props["Shape"] = {"Enum": 2}
            elif p["kind"] == "ellipsoid":
                node["children"] = [{"name": "Mesh", "className": "SpecialMesh", "properties": {"MeshType": {"Enum": 3}}}]
            children.append(node)
        return {"className": "Model", "children": children}


# ===================== Pantofle (domácí bačkory) =====================

def slipper_base(s: Shoe, upper, sole, footbed, rim, upper_mat="Fabric", sole_mat="Smooth"):
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
    s = Shoe("BasicBlackSlippers")
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
    s = Shoe("BeachBlueSlippers")
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
    s = Shoe("WatermelonSlippers")
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
    s = Shoe("SharkSlippers")
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
    s = Shoe("RoyalDiamondSlippers")
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

def sneaker_base(s: Shoe, upper, toe, sole, outsole, accent, lace, collar, high_top=False, upper_mat="Smooth", sole_mat="Smooth"):
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
    s.box((0.3, 0.45, 0.12), (0, 1.25 if not high_top else 1.9, 1.32), accent, rot=(-15, 0, 0))
    if high_top:
        s.ell((1.18, 1.3, 1.1), (0, 1.45, 0.62), upper, upper_mat)
        s.ell((1.22, 0.24, 1.14), (0, 1.98, 0.62), accent)


def muddy_old():
    s = Shoe("MuddyOldSneakers")
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
    s = Shoe("CanvasKicks")
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
    s = Shoe("StreetRunners")
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


def flame(s: Shoe, x, y, z, h, color_out, color_in, side):
    """Plamínek na boku boty (z klínů a koule)."""
    s.wedge((0.06, h, h * 0.55), (x, y, z), color_out, "Neon", rot=(0, 0, 0))
    s.wedge((0.06, h * 0.6, h * 0.35), (x + side * 0.02, y - h * 0.12, z + h * 0.05), color_in, "Neon")
    s.ell((0.06, h * 0.45, h * 0.6), (x, y - h * 0.42, z + h * 0.1), color_out, "Neon")


def sky_dunk():
    s = Shoe("SkyDunkLegends")
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
    s = Shoe("GoldenAirKings")
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


SHOES = [basic_black, beach_blue, watermelon, shark, royal_diamond, muddy_old, canvas_kicks, street_runners, sky_dunk, golden_air]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    shoes = [f() for f in SHOES]
    for s in shoes:
        path = os.path.join(OUT_DIR, f"{s.name}.model.json")
        with open(path, "w") as fh:
            json.dump(s.to_json(), fh, separators=(",", ":"))
        print(f"{s.name}: {len(s.parts)} dílů")


if __name__ == "__main__":
    main()
