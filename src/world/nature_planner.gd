class_name NaturePlanner
extends RefCounted
## Plant Natur-Dekor (Gras, Blumen, Büsche, Teiche) für eine Zone je Reinigungsstufe.
## Deterministisch aus Zonen-Seed, damit dieselbe Zone immer gleich heilt. Reine Logik, testbar.

static func load_config(path: String = "res://data/nature.json") -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


## Liefert [{kind, tile}] für die Zone. `occupied` enthält Kacheln (Vector2i → true), die frei bleiben müssen.
## Kacheln am Zonenrand (1 Kachel) bleiben frei, damit Zäune und Tore sichtbar sind.
static func plan(rect: Rect2i, stage: int, seed_value: int, cfg: Dictionary, occupied: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if stage <= 0:
		return out
	var densities: Dictionary = cfg.get("decor", {}).get(str(stage), {})
	if densities.is_empty():
		return out
	var sizes: Dictionary = cfg.get("decor_size", {})
	var rng := SimRng.new(seed_value)
	var used: Dictionary = occupied.duplicate()
	var inner := Rect2i(rect.position + Vector2i.ONE, rect.size - Vector2i(2, 2))
	if inner.size.x <= 0 or inner.size.y <= 0:
		return out
	var area := inner.size.x * inner.size.y
	# Große Objekte zuerst, damit sie Platz finden
	var kinds := densities.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return _footprint(a, sizes).x > _footprint(b, sizes).x)
	for kind in kinds:
		var count := int(round(float(densities[kind]) * area))
		var fp := _footprint(str(kind), sizes)
		var tries := count * 6
		while count > 0 and tries > 0:
			tries -= 1
			var t := Vector2i(rng.randi_range(inner.position.x, inner.end.x - fp.x), rng.randi_range(inner.position.y, inner.end.y - fp.y))
			if _free(t, fp, used):
				for dx in fp.x:
					for dy in fp.y:
						used[t + Vector2i(dx, dy)] = true
				out.append({"kind": str(kind), "tile": t})
				count -= 1
	return out


static func _footprint(kind: String, sizes: Dictionary) -> Vector2i:
	var s: Variant = sizes.get(kind)
	if s is Array and s.size() == 2:
		return Vector2i(int(s[0]), int(s[1]))
	return Vector2i.ONE


static func _free(t: Vector2i, fp: Vector2i, used: Dictionary) -> bool:
	for dx in fp.x:
		for dy in fp.y:
			if used.has(t + Vector2i(dx, dy)):
				return false
	return true


## Seed je Zone: stabil über Spielstände hinweg.
static func zone_seed(zone_id: String) -> int:
	return zone_id.hash() & 0x7FFFFFFF
