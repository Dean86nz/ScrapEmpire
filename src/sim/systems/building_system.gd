class_name BuildingSystem
extends RefCounted
## Bauen, Abreißen, Drehen, Einlegen, Entnehmen, Kosten, Reichweite.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


static func player_tile(w: SimWorld) -> Vector2i:
	return Vector2i(floori(w.player.pos.x / float(SimWorld.TILE)), floori(w.player.pos.y / float(SimWorld.TILE)))


static func building_count(w: SimWorld, def_id: String) -> int:
	var n := 0
	for b: Building in w.buildings.values():
		if b.def.id == def_id:
			n += 1
	return n


static func next_cost(w: SimWorld, def: BuildingDef) -> Dictionary:
	return Economy.cost_for(def, building_count(w, def.id))


static func in_build_range(w: SimWorld, tile: Vector2i, size: Vector2i) -> bool:
	var pt := player_tile(w)
	for c in Grid.footprint(tile, size):
		var d := c - pt
		if maxi(absi(d.x), absi(d.y)) > SimWorld.BUILD_RANGE_TILES:
			return false
	return true


static func _tile_blocked(w: SimWorld, tile: Vector2i) -> bool:
	return w._node_tiles.has(tile) or tile == player_tile(w) or w.blocked_tiles.has(tile)


static func can_place_def(w: SimWorld, def: BuildingDef, tile: Vector2i, rot: int) -> bool:
	return w.grid.can_place(tile, def.rotated_size(rot), w._tile_blocked)


static func _cmd_place(w: SimWorld, cmd: Dictionary) -> void:
	var def: BuildingDef = w.defs.get(str(cmd.get("def_id", "")), null)
	if def == null:
		w.place_failed.emit("unknown")
		return
	if not w.is_building_unlocked(def.id):
		w.place_failed.emit("locked")
		return
	var tile: Vector2i = cmd.get("tile", Vector2i.ZERO)
	var rot: int = int(cmd.get("rot", 0))
	if not in_build_range(w, tile, def.rotated_size(rot)):
		w.place_failed.emit("range")
		return
	if not can_place_def(w, def, tile, rot):
		w.place_failed.emit("blocked")
		return
	var cost := next_cost(w, def)
	if not Economy.can_afford(w.player.inventory, cost):
		w.place_failed.emit("cost")
		return
	Economy.pay(w.player.inventory, cost)
	var b := Building.create(w.next_id(), def, tile, rot)
	b.paid_cost = cost
	if b is Machine:
		(b as Machine).recipes = w.available_recipes(def.id)
	if b is SellTerminal:
		(b as SellTerminal).sell_interval = int(w.mods["sell_interval"])
	w.grid.place(b)
	w.buildings[b.id] = b
	w._network_dirty = true
	w.progression.on_build()
	w.building_placed.emit(b)


## Platziert ohne Kosten und Reichweite (Tests, Dev-Szenarien).
static func place_free(w: SimWorld, def_id: String, tile: Vector2i, rot: int = 0) -> Building:
	var def: BuildingDef = w.defs[def_id]
	if not can_place_def(w, def, tile, rot):
		return null
	var b := Building.create(w.next_id(), def, tile, rot)
	if b is Machine:
		(b as Machine).recipes = w.available_recipes(def.id)
	w.grid.place(b)
	w.buildings[b.id] = b
	w._network_dirty = true
	w.building_placed.emit(b)
	return b


static func _cmd_rotate(w: SimWorld, cmd: Dictionary) -> void:
	var b := w.grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null or not (b is Conveyor or b is Extractor):
		return
	b.rot = posmod(int(cmd.get("rot", 0)), 4)
	w._network_dirty = true
	w.building_changed.emit(b)


static func _cmd_remove(w: SimWorld, cmd: Dictionary) -> void:
	var b := w.grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null:
		return
	w.grid.remove(b)
	w.buildings.erase(b.id)
	w._network_dirty = true
	var to_refund: Dictionary = b.paid_cost.duplicate()
	for item in b.contents():
		to_refund[item] = to_refund.get(item, 0) + b.contents()[item]
	var rest := Economy.refund(w.player.inventory, to_refund)
	for item in rest:
		for i in int(rest[item]):
			w.add_loose(item, b.center_px() + w._scatter())
	w.building_removed.emit(b.id)


static func _cmd_deposit(w: SimWorld, cmd: Dictionary) -> void:
	var b := w.grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null:
		return
	var slot_index: int = int(cmd.get("slot", 0))
	if slot_index < 0 or slot_index >= w.player.inventory.slots.size():
		return
	var s: Dictionary = w.player.inventory.slots[slot_index]
	if s["item"] == "":
		return
	var item: String = s["item"]
	var accepted := b.accept_stack(item, int(s["count"]))
	if accepted > 0:
		w.player.inventory.remove(item, accepted)
		w.building_changed.emit(b)
	else:
		w.deposit_rejected.emit(b, item)


static func _cmd_withdraw(w: SimWorld, cmd: Dictionary) -> void:
	var b := w.grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null:
		return
	var stack := b.withdraw_stack()
	if stack.is_empty():
		return
	var rest := w.player.inventory.add(stack["item"], stack["count"])
	if rest > 0:
		b.accept_stack(stack["item"], rest)
	w.building_changed.emit(b)


## Nächstes Gebäude, dessen Rechteck (um max_dist_px erweitert) pos enthält.
static func building_near(w: SimWorld, pos: Vector2i, max_dist_px: int) -> Building:
	var best: Building = null
	var best_d := INF
	for b: Building in w.buildings.values():
		var r := b.rect_px().grow(max_dist_px)
		if not r.has_point(pos):
			continue
		var d := Vector2(pos).distance_to(Vector2(b.center_px()))
		if d < best_d:
			best_d = d
			best = b
	return best
