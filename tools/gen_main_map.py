"""Erzeugt data/maps/main.json (Phase 2, MS36): 120×90 Kacheln, 6 Themen-Zonen à 40×45 in 3×2.
Reihenfolge als Schlange: unten links (Schiff) → unten Mitte → unten rechts → oben rechts → oben Mitte
→ oben links (Endzone direkt über dem Start). Jede Zone füllt sich mit ihren Müll-Objekten, bis ihr
Zielwert in Bolts erreicht ist, plus Haufen und einem Boss. Deterministisch (fester Seed).
Aufruf: python -I tools/gen_main_map.py
"""
import json, random, os

W, H = 120, 90
ZW, ZH = 40, 45
rng = random.Random(20261028)
HERE = os.path.dirname(__file__)
objs = {o["id"]: o for o in json.load(open(os.path.join(HERE, "..", "data", "scrap_objects.json"), encoding="utf-8"))["objects"]}
values = {i["id"]: i["sell_value"] for i in json.load(open(os.path.join(HERE, "..", "data", "items.json"), encoding="utf-8"))["items"]}

# (Spalte, Zeile) → id, Name-Schlüssel, Thema, Zielwert ohne Boss, Objekte (Gewicht), Haufen, Boss
ZONES = [
    ((0, 1), "ZONE_SCRAPYARD", "scrapyard", 1900, {"toaster": 3, "tv": 3, "tire_stack": 2, "pallet": 1}, {"scrap_pile": 4, "copper_tangle": 1}, "toaster_tower"),
    ((1, 1), "ZONE_CABLES", "cables", 3600, {"radio": 3, "charger_nest": 3, "cart": 2, "concrete": 1}, {"copper_tangle": 4, "scrap_pile": 2}, "cable_monster"),
    ((2, 1), "ZONE_BEACH", "beach", 5400, {"duck_pile": 3, "flipflop_heap": 3, "umbrella_wreck": 2, "sofa": 1}, {"plastic_crumbs": 4, "driftwood_pile": 2}, "plastic_whale"),
    ((2, 0), "ZONE_FRIDGES", "fridges", 7200, {"fridge": 3, "freezer": 3, "pizza_tower": 2, "ruin_wall": 1}, {"scrap_pile": 2, "rubble_field": 2}, "freezer_king"),
    ((1, 0), "ZONE_SATELLITES", "satellites", 8200, {"satellite": 3, "ship_part": 3, "robot_arm": 2}, {"copper_tangle": 2, "scrap_pile": 2}, "mega_dish"),
    ((0, 0), "ZONE_MONOLITHS", "monoliths", 7400, {"monolith": 3, "stardust_crystal": 3, "mystery_cube": 2}, {"rubble_field": 2, "scrap_pile": 2}, "ur_heap"),
]
SHIP = (16, 64)          # 3×3, Zone unten links
START = (20, 66)

occupied = set()
nodes = []


def value_of(kind, amount=None):
    o = objs[kind]
    if o["type"] == "pile":
        return values[o["item"]] * (amount if amount is not None else o.get("max", 10))
    return sum(values[k] * c for k, c in o["yield"].items())


def place(kind, x, y, amount=None):
    if (x, y) in occupied or not (0 <= x < W and 0 <= y < H):
        return False
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            occupied.add((x + dx, y + dy))   # etwas Abstand zwischen Objekten
    e = {"kind": kind, "x": x, "y": y}
    if amount is not None:
        e["amount"] = amount
    nodes.append(e)
    return True


# Schiff und Start freihalten
for sx in range(SHIP[0] - 3, SHIP[0] + 7):
    for sy in range(SHIP[1] - 3, SHIP[1] + 7):
        occupied.add((sx, sy))

zone_list = []
order = []
for (zx, zy), name_key, theme, target, table, piles, boss in ZONES:
    zid = f"z{zx}{zy}"
    order.append(zid)
    x0, y0 = zx * ZW, zy * ZH
    # Fester Bauplatz für die Sammelstelle (2×2), frei gehalten samt Rand (MS41)
    site = (x0 + ZW // 2 - 9, y0 + ZH // 2 + 9)
    for sx in range(site[0] - 2, site[0] + 4):
        for sy in range(site[1] - 2, site[1] + 4):
            occupied.add((sx, sy))
    zone_list.append({"id": zid, "name_key": name_key, "name": name_key, "theme": theme, "x": x0, "y": y0, "w": ZW, "h": ZH,
                      "site": {"x": site[0], "y": site[1]}})

    def rand_tile(margin=3):
        return rng.randint(x0 + margin, x0 + ZW - 1 - margin), rng.randint(y0 + margin, y0 + ZH - 1 - margin)

    # Boss in der Zonenmitte (etwas versetzt), deutlich sichtbar
    for _ in range(50):
        bx, by = x0 + ZW // 2 + rng.randint(-6, 6), y0 + ZH // 2 + rng.randint(-6, 6)
        if place(boss, bx, by):
            break
    total = 0
    kinds = [k for k, wgt in table.items() for _ in range(wgt)]
    pile_kinds = [k for k, wgt in piles.items() for _ in range(wgt)]
    guard = 0
    while total < target and guard < 2000:
        guard += 1
        if rng.random() < 0.35:
            kind = rng.choice(pile_kinds)
            amount = rng.randint(6, 10)
        else:
            kind = rng.choice(kinds)
            amount = None
        x, y = rand_tile()
        if place(kind, x, y, amount):
            total += value_of(kind, amount)

data = {
    "name": "main",
    "width": W,
    "height": H,
    "seed": 4712,
    "player_start": {"x": START[0], "y": START[1]},
    "ship": {"x": SHIP[0], "y": SHIP[1]},
    "dirt": True,
    "zone_order": order,
    "unlock_cleanliness": 0.5,
    "zones": zone_list,
    "nodes": nodes,
}
out = os.path.join(HERE, "..", "data", "maps", "main.json")
with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump(data, f, indent=1, ensure_ascii=False)
base = sum(value_of(n["kind"], n.get("amount")) for n in nodes)
print(f"{len(nodes)} Objekte, {len(zone_list)} Zonen, Kartenwert {base} Bolts -> {os.path.abspath(out)}")
