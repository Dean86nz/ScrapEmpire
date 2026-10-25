"""Erzeugt data/maps/main.json: Hauptgebiet 120×90 mit 3×3 Zonen à 40×30.
Die Tutorial-Zone liegt links in der Mitte (0,30)-(40,60) und enthält das bisherige
Tutorial-Layout, nur um 30 Kacheln nach unten verschoben. Deterministisch (fester Seed).
Aufruf: python -I tools/gen_main_map.py
"""
import json, random, os

W, H = 120, 90
ZW, ZH = 40, 30
rng = random.Random(20261025)

tutorial_nodes = [
    ("scrap_pile", 16, 12, 8), ("scrap_pile", 24, 11, 10), ("scrap_pile", 13, 18, 6),
    ("scrap_pile", 27, 19, 9), ("scrap_pile", 20, 22, 7), ("scrap_pile", 30, 14, 10),
    ("copper_tangle", 10, 10, 6), ("copper_tangle", 31, 23, 5),
    ("plastic_crumbs", 9, 21, 6), ("plastic_crumbs", 29, 8, 5),
    ("toaster", 17, 17, None), ("toaster", 25, 14, None),
    ("fridge", 7, 15, None), ("cart", 22, 26, None),
]

# Zonen-Raster: (zx, zy) -> Name, Tier-Bereich (min,max)
zones = {
    (0, 0): ("Nordstrand", 1, 2), (1, 0): ("Rostwiese", 2, 3), (2, 0): ("Satellitenfeld", 3, 4),
    (0, 1): ("Startlager", 1, 1), (1, 1): ("Kabelsenke", 1, 2), (2, 1): ("Kühlschrank-Friedhof", 2, 3),
    (0, 2): ("Südbucht", 1, 2), (1, 2): ("Palettenhafen", 2, 3), (2, 2): ("Monolith-Ebene", 3, 5),
}
tier_objects = {
    1: ["toaster", "toaster", "cart"],
    2: ["fridge", "cart", "fridge"],
    3: ["ship_part", "satellite", "satellite"],
    4: ["robot_arm"],
    5: ["monolith"],
}
piles = ["scrap_pile", "scrap_pile", "scrap_pile", "copper_tangle", "plastic_crumbs"]

occupied = set()
nodes = []

def place(kind, x, y, amount=None):
    key = (x, y)
    if key in occupied or not (0 <= x < W and 0 <= y < H):
        return False
    occupied.add(key)
    entry = {"kind": kind, "x": x, "y": y}
    if amount is not None:
        entry["amount"] = amount
    nodes.append(entry)
    return True

# Tutorial-Zone (0,1): festes Layout, verschoben
for kind, x, y, amount in tutorial_nodes:
    place(kind, x, y + ZH, amount)
# Spielerstart in der Tutorial-Zone freihalten
for dx in range(-1, 2):
    for dy in range(-1, 2):
        occupied.add((20 + dx, 45 + dy))

zone_list = []
for (zx, zy), (name, tmin, tmax) in zones.items():
    x0, y0 = zx * ZW, zy * ZH
    zone_list.append({"id": f"z{zx}{zy}", "name": name, "x": x0, "y": y0, "w": ZW, "h": ZH, "tutorial": (zx, zy) == (0, 1)})
    if (zx, zy) == (0, 1):
        continue
    def rand_tile():
        return rng.randint(x0 + 2, x0 + ZW - 3), rng.randint(y0 + 2, y0 + ZH - 3)
    for _ in range(rng.randint(7, 10)):
        for _try in range(20):
            x, y = rand_tile()
            if place(rng.choice(piles), x, y, rng.randint(5, 10)):
                break
    for _ in range(rng.randint(5, 8)):
        tier = rng.randint(tmin, tmax)
        kind = rng.choice(tier_objects[tier])
        for _try in range(20):
            x, y = rand_tile()
            if place(kind, x, y):
                break
    # Jede Zone außer dem Start bekommt mindestens einen Satelliten (Chrom-Quelle) ab Tier 3,
    # sonst einen Kühlschrank als Ziel.
    goal = "satellite" if tmax >= 3 else "fridge"
    for _try in range(30):
        x, y = rand_tile()
        if place(goal, x, y):
            break

data = {
    "name": "main",
    "width": W,
    "height": H,
    "seed": 4711,
    "player_start": {"x": 20, "y": 45},
    "tutorial_zone": {"x": 0, "y": 30, "w": 40, "h": 30},
    "gate": {"x": 40, "y": 42, "w": 1, "h": 6},
    "zones": zone_list,
    "nodes": nodes,
}
out = os.path.join(os.path.dirname(__file__), "..", "data", "maps", "main.json")
with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print(f"{len(nodes)} Objekte, {len(zone_list)} Zonen -> {os.path.abspath(out)}")
