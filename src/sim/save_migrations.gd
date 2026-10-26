class_name SaveMigrations
extends RefCounted
## Hebt Spielstände um genau eine Version an. Registriert in SaveManager.
## 1 → 2: Karte "tutorial" (40×30) wurde Teil der Hauptkarte "main" (120×90); die
##        Tutorial-Zone liegt dort bei (0,30). Alles um 30 Kacheln nach unten verschieben.
##        Alte Stände gelten als Tutorial-fertig, das Tor ist offen.

const SHIFT_TILES := Vector2i(0, 30)
const SHIFT_PX := Vector2(0, 30 * 64)


static func all() -> Dictionary:
	return {1: Callable(SaveMigrations, "v1_to_v2"), 2: Callable(SaveMigrations, "v2_to_v3"), 3: Callable(SaveMigrations, "v3_to_v4"), 4: Callable(SaveMigrations, "v4_to_v5"), 5: Callable(SaveMigrations, "v5_to_v6"), 6: Callable(SaveMigrations, "v6_to_v7"), 8: Callable(SaveMigrations, "v8_to_v9")}


## 8 → 9 (MS25): XP verbessert Rusty, Bolts das Schiff. Schiff-Upgrades für Laderaum, Tempo,
## Saugtempo und Werkzeug werden zu Skills (Taschen, Fahrtempo, Saugtempo, Werkzeug), jeweils die
## höhere Stufe aus altem Skill und altem Upgrade, geschenkt. Alle Skillpunkte kommen zurück und
## werden nach der neuen Regel (2 je Level) neu berechnet. Nichts Gekauftes geht verloren.
static func v8_to_v9(data: Dictionary) -> Dictionary:
	var old_sk: Dictionary = data.get("skills", {})
	var old_up: Dictionary = data.get("ship_upgrades", {})
	var sk := func(k: String) -> int: return int(old_sk.get(k, 0))
	var up := func(k: String) -> int: return int(old_up.get(k, 0))
	var skills := {}
	skills["drive"] = mini(maxi(up.call("speed"), sk.call("agility")), 8)
	skills["boost"] = mini(sk.call("boost"), 3)
	skills["suck"] = mini(maxi(up.call("suction"), sk.call("tempo")), 8)
	skills["reach"] = mini(sk.call("reach"), 4)
	skills["magnet"] = mini(sk.call("magnet"), 3)
	skills["bags"] = mini(up.call("cargo"), 8)
	skills["tool"] = mini(up.call("tool"), 3)
	data["skills"] = skills
	data["ship_upgrades"] = {"yield": up.call("yield")}
	var prog: Dictionary = data.get("progression", {})
	prog["skill_points"] = maxi(int(prog.get("level", 1)) - 1, 0) * 2
	data["progression"] = prog
	data["version"] = 9
	return data


static func v6_to_v7(data: Dictionary) -> Dictionary:
	data["quests"] = {"index": 0, "counters": {}}
	data["version"] = 7
	return data


static func v5_to_v6(data: Dictionary) -> Dictionary:
	data["collectibles_found"] = []
	data["version"] = 6
	return data


static func v4_to_v5(data: Dictionary) -> Dictionary:
	data["drones"] = []
	data["drone_upgrades"] = {}
	data["version"] = 5
	return data


## 3 → 4: Kapitel (freigeschaltete Zonen). Alte Stände beginnen mit der Startzone.
static func v3_to_v4(data: Dictionary) -> Dictionary:
	data["unlocked_zones"] = ["z01"]
	data["version"] = 4
	return data


## 2 → 3: Helfer-Roboter und ihre Upgrades.
static func v2_to_v3(data: Dictionary) -> Dictionary:
	data["helpers"] = []
	data["helper_upgrades"] = {}
	data["version"] = 3
	return data


static func _shift_tile(a: Variant) -> Array:
	if a is Array and a.size() >= 2:
		return [int(a[0]) + SHIFT_TILES.x, int(a[1]) + SHIFT_TILES.y]
	return a


static func v1_to_v2(data: Dictionary) -> Dictionary:
	if str(data.get("map", "tutorial")) == "tutorial":
		for n in data.get("nodes", []):
			n["tile"] = _shift_tile(n.get("tile"))
		for l in data.get("loose", []):
			l["pos"] = _shift_tile(l.get("pos")) if false else [int(l["pos"][0]) + int(SHIFT_PX.x), int(l["pos"][1]) + int(SHIFT_PX.y)]
		for b in data.get("buildings", []):
			b["tile"] = _shift_tile(b.get("tile"))
		for r in data.get("respawns", []):
			r["tile"] = _shift_tile(r.get("tile"))
		var p: Dictionary = data.get("player", {})
		if p.has("pos"):
			p["pos"] = [float(p["pos"][0]) + SHIFT_PX.x, float(p["pos"][1]) + SHIFT_PX.y]
		data["map"] = "main"
	data["tutorial"] = {"step": 5, "done": true}
	data["tasks"] = {"steps": [], "active": false, "index": 0}
	data["flags"] = {"gate_open": true}
	data["version"] = 2
	return data
