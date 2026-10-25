class_name MapLoader
extends RefCounted
## Liest eine Karte aus data/maps/*.json in eine SimWorld.
## Liefert die Startposition des Spielers in Pixeln (Kachelmitte).


static func load_into(world: SimWorld, path: String) -> Vector2i:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Karte nicht lesbar: " + path)
	var data: Dictionary = JSON.parse_string(text)
	assert(data != null, "Karte ist kein gültiges JSON: " + path)
	return apply(world, data)


static func apply(world: SimWorld, data: Dictionary) -> Vector2i:
	world.set_size(int(data.get("width", 40)), int(data.get("height", 30)))
	world.rng = SimRng.new(int(data.get("seed", 0)))
	for entry: Dictionary in data.get("nodes", []):
		var kind := str(entry.get("kind", ""))
		var tile := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if kind == ResourceNode.KIND_WRECK:
			var loot: Dictionary = {}
			for k in entry.get("loot", {}):
				loot[str(k)] = int(entry["loot"][k])
			world.add_wreck(tile, loot)
		elif ResourceNode.is_pile_kind(kind):
			world.add_pile(kind, tile, int(entry.get("amount", ResourceNode.PILE_MAX)))
		else:
			push_warning("Karte: unbekannter Knotentyp '%s' übersprungen" % kind)
	var start: Dictionary = data.get("player_start", {"x": world.width_tiles / 2, "y": world.height_tiles / 2})
	var half := ResourceNode.TILE / 2
	return Vector2i(int(start["x"]), int(start["y"])) * ResourceNode.TILE + Vector2i(half, half)
