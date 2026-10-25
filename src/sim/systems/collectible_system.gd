class_name CollectibleSystem
extends RefCounted
## Fundstücke: Platzierung, Einsammeln.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


## Platziert alle noch nicht gefundenen Fundstücke deterministisch in ihren Zonen.
static func spawn_collectibles(w: SimWorld) -> void:
	var occupied := {}
	for n: ResourceNode in w.nodes.values():
		for dx in 2:
			for dy in 2:
				occupied[n.tile + Vector2i(dx, dy)] = true
	for bld: Building in w.buildings.values():
		for c in bld.cells():
			occupied[c] = true
	for c: Collectible in w.collectibles.values():
		occupied[c.tile] = true
	var present := {}
	for c: Collectible in w.collectibles.values():
		present[c.def_id] = true
	for def: Dictionary in w.collectible_cfg.get("collectibles", []):
		var def_id := str(def.get("id", ""))
		if w.collectibles_found.has(def_id) or present.has(def_id):
			continue
		var z := w.zones.zone_by_id(str(def.get("zone", "")))
		if z.is_empty():
			continue
		var c := Collectible.new()
		c.id = w.next_id()
		c.def_id = def_id
		c.tile = Collectible.pick_tile(def, z["rect"], occupied)
		occupied[c.tile] = true
		w.collectibles[c.id] = c
		w.collectible_added.emit(c)


static func collectible_def(w: SimWorld, def_id: String) -> Dictionary:
	for def: Dictionary in w.collectible_cfg.get("collectibles", []):
		if str(def.get("id", "")) == def_id:
			return def
	return {}


static func collectible_total(w: SimWorld) -> int:
	return w.collectible_cfg.get("collectibles", []).size()


static func _tick_collectibles(w: SimWorld) -> void:
	if w.collectibles.is_empty():
		return
	for c: Collectible in w.collectibles.values():
		if Vector2(c.center_px() - w.player.pos).length() <= float(Collectible.PICKUP_PX):
			w.collectibles.erase(c.id)
			w.collectibles_found[c.def_id] = true
			w.progression.add_xp(int(w.collectible_cfg.get("xp", 60)))
			w.collectible_found.emit(c, collectible_def(w, c.def_id))
			return
