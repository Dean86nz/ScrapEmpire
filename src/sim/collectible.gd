class_name Collectible
extends RefCounted
## Fundstück in der Welt: einzigartig, liegt an einer deterministischen Kachel seiner Zone,
## wird beim Darüberfahren eingesammelt. Gefundene Fundstücke stehen im Spielstand (IDs),
## nicht gefundene werden beim Laden aus den Definitionen neu platziert.

const PICKUP_PX := 40

var id: int
var def_id: String
var tile: Vector2i


func center_px() -> Vector2i:
	return tile * 64 + Vector2i(32, 32)


static func load_defs(path: String = "res://data/collectibles.json") -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


## Deterministische Kachel für ein Fundstück: freie Kachel in der Zone, aus Zonen-Seed und ID.
static func pick_tile(def: Dictionary, rect: Rect2i, occupied: Dictionary) -> Vector2i:
	var rng := SimRng.new((str(def.get("zone", "")) + ":" + str(def.get("id", ""))).hash() & 0x7FFFFFFF)
	var inner := Rect2i(rect.position + Vector2i(2, 2), rect.size - Vector2i(4, 4))
	for i in 200:
		var t := Vector2i(rng.randi_range(inner.position.x, inner.end.x - 1), rng.randi_range(inner.position.y, inner.end.y - 1))
		if not occupied.has(t):
			return t
	return inner.position
