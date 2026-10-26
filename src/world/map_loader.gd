class_name MapLoader
extends RefCounted
## Liest eine Karte aus data/maps/*.json in eine SimWorld.
## Liefert die Startposition des Spielers in Pixeln (Kachelmitte).


static func read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "Karte nicht lesbar: " + path)
	var data: Dictionary = JSON.parse_string(text)
	assert(data != null, "Karte ist kein gültiges JSON: " + path)
	return data


static func load_into(world: SimWorld, path: String) -> Vector2i:
	return apply(world, read(path))


## with_nodes = false: nur Größe und Seed (beim Laden eines Spielstands, der die Knoten selbst mitbringt).
static func apply(world: SimWorld, data: Dictionary, with_nodes: bool = true) -> Vector2i:
	world.set_size(int(data.get("width", 40)), int(data.get("height", 30)))
	world.rng = SimRng.new(int(data.get("seed", 0)))
	world.zones.setup(data.get("zones", []), data.get("nodes", []), data.get("zone_order", []), float(data.get("unlock_cleanliness", 0.5)))
	if with_nodes:
		for entry: Dictionary in data.get("nodes", []):
			var kind := str(entry.get("kind", ""))
			var tile := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
			if entry.has("loot") and (kind == ResourceNode.KIND_WRECK or ResourceNode.has_kind(kind)):
				# Explizite Ausbeute überschreibt die Definition (alte Karten, Sonderfälle).
				var loot: Dictionary = {}
				for k in entry["loot"]:
					loot[str(k)] = int(entry["loot"][k])
				world.add_wreck(tile, loot, kind)
			elif ResourceNode.has_kind(kind):
				world.add_object(kind, tile, int(entry.get("amount", -1)))
			else:
				push_warning("Karte: unbekannter Knotentyp '%s' übersprungen" % kind)
	if with_nodes and data.has("ship"):
		ensure_ship(world, data)
	if with_nodes:
		ensure_dirt(world, data)
	var start: Dictionary = data.get("player_start", {"x": world.width_tiles / 2, "y": world.height_tiles / 2})
	return _start_px(world, start)


## Erzeugt den Schmutz, wenn die Karte ihn vorsieht ("dirt": true) und er noch fehlt
## (neues Spiel oder Spielstand von vor MS21). Müll-Umfeld aus den aktuellen Objekten.
static func ensure_dirt(world: SimWorld, data: Dictionary) -> void:
	if not bool(data.get("dirt", false)) or world.dirt.is_active():
		return
	if world.dirt_cfg.is_empty():
		world.dirt_cfg = DirtMap.load_config()
	var trash: Array = []
	for n: ResourceNode in world.nodes.values():
		if n.is_wreck() and not n.is_resource():
			trash.append(n.tile)
	var s := ShipSystem.ship(world)
	var ship_center := s.tile + Vector2i(1, 1) if s != null else Vector2i(-1, -1)
	world.dirt.generate(world.width_tiles, world.height_tiles, world.zones, trash, ship_center, int(data.get("seed", 0)), world.dirt_cfg)
	world.zones.refresh(world.nodes)


## Stellt sicher, dass genau ein Raumschiff existiert: an der Kartenposition, sonst in der Nähe
## (freie 3×3-Fläche in Spiralsuche). Für neue Spiele und alte Spielstände ohne Schiff.
static func ensure_ship(world: SimWorld, data: Dictionary) -> Ship:
	var existing := ShipSystem.ship(world)
	if existing != null:
		return existing
	if not world.defs.has("ship"):
		return null
	var def: BuildingDef = world.defs["ship"]
	var sd: Dictionary = data.get("ship", {})
	var start: Dictionary = data.get("player_start", {"x": world.width_tiles / 2, "y": world.height_tiles / 2})
	var base := Vector2i(int(sd.get("x", int(start.get("x", 0)) - 4)), int(sd.get("y", int(start.get("y", 0)) - 2)))
	for r in 9:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := base + Vector2i(dx, dy)
				if t.x < 0 or t.y < 0 or t.x + 3 > world.width_tiles or t.y + 3 > world.height_tiles:
					continue
				if world.can_place_def(def, t, 0):
					var s := world.place_free("ship", t, 0) as Ship
					if s != null:
						ShipSystem.apply_stage(world, s)
						return s
	push_warning("Karte: kein Platz für das Raumschiff gefunden")
	return null


## Ergänzt Karten-Objekte in Zonen, die im Spielstand leer sind (z. B. nach der Migration
## der alten Tutorial-Karte). Belegte Kacheln werden übersprungen.
static func fill_missing_zones(world: SimWorld, data: Dictionary) -> int:
	var per_zone: Dictionary = {}
	for n: ResourceNode in world.nodes.values():
		per_zone[world.zones.zone_id_at(n.tile)] = true
	var added := 0
	for entry: Dictionary in data.get("nodes", []):
		var kind := str(entry.get("kind", ""))
		var tile := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var zid := world.zones.zone_id_at(tile)
		if per_zone.has(zid) or not ResourceNode.has_kind(kind):
			continue
		if world.grid.at(tile) != null or world._node_tiles.has(tile):
			continue
		world.add_object(kind, tile, int(entry.get("amount", -1)))
		added += 1
	return added


static func _start_px(world: SimWorld, start: Dictionary) -> Vector2i:
	var half := ResourceNode.TILE / 2
	return Vector2i(int(start["x"]), int(start["y"])) * ResourceNode.TILE + Vector2i(half, half)
