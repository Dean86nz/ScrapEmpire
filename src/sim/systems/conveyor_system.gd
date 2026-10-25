class_name ConveyorSystem
extends RefCounted
## Förderbänder: Netz, Kurven, Transport, Maschinenausgänge, Saugstationen.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


## Kurvenformen und Tick-Reihenfolge neu berechnen (nach jeder Bauänderung).
static func _rebuild_network(w: SimWorld) -> void:
	w._network_dirty = false
	var belts: Array[Conveyor] = []
	for b: Building in w.buildings.values():
		if b is Conveyor:
			belts.append(b)
	var out_tiles: Dictionary = {}  # Kacheln, auf die ein Maschinen-Ausgang zeigt
	for b: Building in w.buildings.values():
		if b is Conveyor:
			continue
		for p in b.ports_world():
			if p["dir"] == "out":
				out_tiles[p["outside"]] = true
	for b in belts:
		var straight := out_tiles.has(b.tile)
		var side_feeders: Array[Conveyor] = []
		for a in belts:
			if a == b or a.front_tile() != b.tile or b.front_tile() == a.tile:
				continue
			if a.tile == b.back_tile():
				straight = true
			else:
				side_feeders.append(a)
		var old_shape := b.shape
		b.shape = Conveyor.Shape.STRAIGHT
		if not straight and side_feeders.size() == 1:
			var a := side_feeders[0]
			b.shape = Conveyor.Shape.TURN_FROM_LEFT if a.tile == b.tile + b.left_dir() else Conveyor.Shape.TURN_FROM_RIGHT
		if b.shape != old_shape:
			w.building_changed.emit(b)
	w.conveyor_order.clear()
	var visited: Dictionary = {}
	for b in belts:
		_visit_belt(w, b, visited)


static func _visit_belt(w: SimWorld, b: Conveyor, visited: Dictionary) -> void:
	if visited.has(b.id):
		return
	visited[b.id] = true
	var n := w.grid.at(b.front_tile())
	if n is Conveyor and n != b and (n as Conveyor).front_tile() != b.tile:
		_visit_belt(w, n, visited)
	w.conveyor_order.append(b)


static func _tick_conveyors(w: SimWorld) -> void:
	for c in w.conveyor_order:
		if c.front_wants_transfer():
			_try_transfer(w, c)
		c.advance()


static func _try_transfer(w: SimWorld, c: Conveyor) -> void:
	var item: String = str(c.front_item()["item"])
	var target := w.grid.at(c.front_tile())
	if target == null:
		return
	if target is Conveyor:
		var t := target as Conveyor
		if t.front_tile() == c.tile:
			return  # frontal
		var off := 0
		if t.back_tile() != c.tile:
			var curve_feed := (t.shape == Conveyor.Shape.TURN_FROM_LEFT and c.tile == t.tile + t.left_dir()) \
				or (t.shape == Conveyor.Shape.TURN_FROM_RIGHT and c.tile == t.tile + t.right_dir())
			off = 0 if curve_feed else Conveyor.SIDE_OFFSET
		if t.try_insert(item, off):
			c.pop_front()
		return
	var accepted := false
	if target is Ship:
		accepted = (target as Ship).accept_from_belt(item)
		if accepted:
			w.ship_received.emit(item, 1)
	elif target is Chest:
		accepted = target.accept_stack(item, 1) == 1
	elif target is SellTerminal:
		accepted = (target as SellTerminal).accept_from_belt(item)
	elif target.accepts_from_belt(c.tile, c.front_tile()):
		accepted = target.accept_stack(item, 1) == 1
	if accepted:
		c.pop_front()
		w.building_changed.emit(target)


## Führt von einem Ausgang eines Gebäudes dieser Art eine Bandkette bis zum Schiff? (Aufgabenkette)
static func belt_reaches_ship(w: SimWorld, def_id: String) -> bool:
	for b: Building in w.buildings.values():
		if b.def.id != def_id:
			continue
		for p in b.ports_world():
			if p["dir"] != "out":
				continue
			var t: Building = w.grid.at(p["outside"])
			var visited: Dictionary = {}
			while t is Conveyor and not visited.has(t.id):
				visited[t.id] = true
				t = w.grid.at((t as Conveyor).front_tile())
			if t is Ship:
				return true
	return false


## Maschinen- und Stationsausgänge legen je Tick höchstens ein Item auf das Band vor dem Port.
static func _tick_outputs(w: SimWorld) -> void:
	for b: Building in w.buildings.values():
		if b is Conveyor or not b.has_output():
			continue
		for p in b.ports_world():
			if p["dir"] != "out":
				continue
			var t := w.grid.at(p["outside"])
			if t is Conveyor and (t as Conveyor).front_tile() != p["cell"] and (t as Conveyor).rear_free():
				var item := b.pop_output_one()
				if item != "":
					(t as Conveyor).try_insert(item, 0)
					w.building_changed.emit(b)
				break


static func _tick_extractors(w: SimWorld) -> void:
	for b: Building in w.buildings.values():
		if not (b is Extractor):
			continue
		var e := b as Extractor
		if not e.tick_extract():
			continue
		for d: Vector2i in Conveyor.DIRS:
			var nid: int = w._node_tiles.get(e.tile + d, -1)
			if nid < 0 or not w.nodes.has(nid):
				continue
			var n: ResourceNode = w.nodes[nid]
			if n.is_pile() and n.tier <= Extractor.TIER:
				e.buffer.append(n.item_id())
				w.building_changed.emit(e)
				break
