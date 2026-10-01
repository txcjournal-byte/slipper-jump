"""Společné nástroje pro generátory modelů z dílů (tools/shoes.py, hats.py, items.py).

Výstup jsou soubory .model.json pro Rojo. Zaoblené tvary jsou díly se SpecialMesh typu Sphere
(elipsoid vyplní celý díl), takže jdou natáhnout do libovolného tvaru.
"""

from __future__ import annotations

import json
import math
import os

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


def yaw_tilt(ry: float, rx: float = 0, rz: float = 0):
    """Nejdřív náklon kolem vlastní osy X (a Z), pak otočení kolem svislé osy: R = Ry * Rx * Rz."""
    return mat_mul(mat_mul(angles(0, ry, 0), angles(rx, 0, 0)), angles(0, 0, rz))


def along(direction):
    """Matice, která natočí osu Y dílu do zadaného směru."""
    dx, dy, dz = direction
    n = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
    up = (dx / n, dy / n, dz / n)
    ref = (0.0, 0.0, 1.0) if abs(up[2]) < 0.9 else (1.0, 0.0, 0.0)
    rx = (up[1] * ref[2] - up[2] * ref[1], up[2] * ref[0] - up[0] * ref[2], up[0] * ref[1] - up[1] * ref[0])
    rn = math.sqrt(sum(c * c for c in rx))
    rx = tuple(c / rn for c in rx)
    bz = (rx[1] * up[2] - rx[2] * up[1], rx[2] * up[0] - rx[0] * up[2], rx[0] * up[1] - rx[1] * up[0])
    return [[rx[0], up[0], bz[0]], [rx[1], up[1], bz[1]], [rx[2], up[2], bz[2]]]


class Build:
    def __init__(self, name: str):
        self.name = name
        self.parts: list[dict] = []

    def add(self, kind, size, pos, color, material="Smooth", rot=(0, 0, 0), transparency=0.0):
        self.parts.append(
            {
                "kind": kind,
                "size": tuple(max(0.05, s) for s in size),
                "pos": tuple(pos),
                "rot": rot if isinstance(rot, list) else angles(*rot),
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

    def attach(self, pos):
        """Neviditelný úchyt: model zůstane ve skutečné velikosti (čepice: 0,25 pod temenem hlavy)."""
        self.add("attach", (0.1, 0.1, 0.1), pos, (1, 1, 1))

    def tube(self, points, d0, d1, color, material="Smooth", c1=None):
        """Zahnutý hladký tvar (roh, chapadlo, ocas) z protáhlých elipsoidů podél bodů."""
        n = len(points) - 1
        for i in range(n):
            p0, p1 = points[i], points[i + 1]
            t = i / max(1, n - 1)
            d = d0 + (d1 - d0) * t
            col = color if c1 is None else tuple(color[k] + (c1[k] - color[k]) * t for k in range(3))
            seg = [p1[k] - p0[k] for k in range(3)]
            length = math.sqrt(sum(c * c for c in seg))
            mid = tuple((p0[k] + p1[k]) / 2 for k in range(3))
            self.add("ellipsoid", (d, length * 1.5 + d * 0.3, d), mid, col, material, along(seg))

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
            if p["kind"] == "attach":
                node["name"] = "Attach"
                props["Transparency"] = 1
            elif p["kind"] == "wedge":
                node["className"] = "WedgePart"
            elif p["kind"] == "cylinder":
                props["Shape"] = {"Enum": 2}
            elif p["kind"] == "ellipsoid":
                node["children"] = [{"name": "Mesh", "className": "SpecialMesh", "properties": {"MeshType": {"Enum": 3}}}]
            children.append(node)
        return {"className": "Model", "children": children}


def write_all(builds, out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    for b in builds:
        with open(os.path.join(out_dir, f"{b.name}.model.json"), "w") as fh:
            json.dump(b.to_json(), fh, separators=(",", ":"))
        print(f"{b.name}: {len(b.parts)} dílů")
