class_name SaveMigrations
extends RefCounted
## Hebt Spielstände um genau eine Version an. Registriert in SaveManager.
## 1 → 2: Karte "tutorial" (40×30) wurde Teil der Hauptkarte "main" (120×90); die
##        Tutorial-Zone liegt dort bei (0,30). Alles um 30 Kacheln nach unten verschieben.
##        Alte Stände gelten als Tutorial-fertig, das Tor ist offen.

const SHIFT_TILES := Vector2i(0, 30)
const SHIFT_PX := Vector2(0, 30 * 64)


static func all() -> Dictionary:
	return {1: Callable(SaveMigrations, "v1_to_v2"), 2: Callable(SaveMigrations, "v2_to_v3")}


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
