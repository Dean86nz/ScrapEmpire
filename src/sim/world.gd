class_name SimWorld
extends RefCounted
## Wurzel der Simulation. Kennt keine Nodes, keine Sekunden. Positionen sind Vector2i in Pixeln.
## Befehle (Dictionaries) werden gesammelt und zu Beginn des nächsten Ticks angewandt.
## Änderungen werden per Signal gemeldet; die Darstellung hört darauf.

signal node_added(node: ResourceNode)
signal node_changed(node: ResourceNode)
signal node_removed(id: int)
signal loose_added(item: LooseItem)
signal loose_removed(id: int)
signal item_collected(item_id: String, from_pos: Vector2i)
signal inventory_full()
signal wreck_hit(node: ResourceNode)
signal wreck_destroyed(id: int)
signal building_placed(building: Building)
signal building_changed(building: Building)
signal building_removed(id: int)
signal place_failed(reason: String)
signal bolts_changed(value: int)
signal item_sold(item_id: String, value: int, pos: Vector2i)
signal deposit_rejected(building: Building, item_id: String)
signal too_hard(node: ResourceNode, tool: String)
signal node_respawned(node: ResourceNode)

const TILE := 64
const LOOT_SCATTER_PX := 40
const BUILD_RANGE_TILES := 6

var tick_count: int = 0
var width_tiles: int = 120
var height_tiles: int = 90
var player := PlayerState.new()
var rng := SimRng.new(0)
var nodes: Dictionary = {}      # id → ResourceNode
var loose: Dictionary = {}      # id → LooseItem
var grid := Grid.new(120, 90)
var buildings: Dictionary = {}  # id → Building
var defs: Dictionary = {}       # def_id → BuildingDef (von außen gesetzt)
var item_values: Dictionary = {}  # item_id → Bolts (von außen gesetzt)
var recipes: Array[RecipeDef] = []  # alle Rezepte (von außen gesetzt)
var unlocked_tech: Dictionary = {}  # tech_id → true (ab MS6 befüllt)
var bolts: int = 0
var progression := Progression.new()
var respawns: Array[Dictionary] = []  # [{kind, tile, ticks_left}]
var conveyor_order: Array[Conveyor] = []  # Tick-Reihenfolge: Ziel vor Quelle
var _network_dirty := true

var _commands: Array[Dictionary] = []
var _next_id: int = 1
var _full_notified := false
var _node_tiles: Dictionary = {}  # Vector2i → node id (für Bauprüfung)
var _too_hard_cooldown := 0
const TOO_HARD_INTERVAL := 20


func _init() -> void:
	# Methoden-Callable statt Lambda: ein Lambda hielte self fest und erzeugte einen Zyklus.
	player.inventory.changed.connect(_on_inventory_changed)


func _on_inventory_changed() -> void:
	_full_notified = false


# --- Aufbau ---------------------------------------------------------------

func set_size(w: int, h: int) -> void:
	width_tiles = w
	height_tiles = h
	grid = Grid.new(w, h)


func next_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


## Beliebiges Schrott-Objekt aus scrap_objects.json. amount_override nur für Haufen.
func add_object(kind: String, tile: Vector2i, amount_override: int = -1) -> ResourceNode:
	var n := ResourceNode.from_kind(next_id(), kind, tile, amount_override)
	nodes[n.id] = n
	_node_tiles[tile] = n.id
	node_added.emit(n)
	return n


func add_pile(kind: String, tile: Vector2i, amount: int) -> ResourceNode:
	return add_object(kind, tile, amount)


## Endliches Hammer-Objekt mit expliziter Ausbeute (Tests, alte Karten).
func add_wreck(tile: Vector2i, loot: Dictionary, kind: String = ResourceNode.KIND_WRECK) -> ResourceNode:
	var n := ResourceNode.make_wreck(next_id(), tile, loot, kind)
	nodes[n.id] = n
	_node_tiles[tile] = n.id
	node_added.emit(n)
	return n


func add_loose(item_id: String, pos: Vector2i, tier: int = 1) -> LooseItem:
	var item := LooseItem.new(next_id(), item_id, pos, tier)
	loose[item.id] = item
	loose_added.emit(item)
	return item


func size_px() -> Vector2i:
	return Vector2i(width_tiles, height_tiles) * TILE


# --- Tick -----------------------------------------------------------------

func queue_command(cmd: Dictionary) -> void:
	_commands.append(cmd)


func pending_commands() -> int:
	return _commands.size()


func tick() -> void:
	for cmd in _commands:
		_apply(cmd)
	_commands.clear()

	for n: ResourceNode in nodes.values():
		if n.tick():
			node_changed.emit(n)

	if _network_dirty:
		_rebuild_network()
	_tick_conveyors()
	_tick_outputs()
	_tick_extractors()

	for b: Building in buildings.values():
		if b.tick():
			if b is SellTerminal:
				var sold: String = (b as SellTerminal).take_sold()
				if sold != "":
					var value: int = int(item_values.get(sold, 0))
					bolts += value
					progression.on_sale(value)
					item_sold.emit(sold, value, b.center_px())
					bolts_changed.emit(bolts)
			building_changed.emit(b)

	if player.suck_cooldown > 0:
		player.suck_cooldown -= 1
	if player.hammer_cooldown > 0:
		player.hammer_cooldown -= 1
	if _too_hard_cooldown > 0:
		_too_hard_cooldown -= 1

	_tick_suction()
	_tick_hammer()
	_tick_respawns()
	player.hammer_pressed = false
	tick_count += 1


func _tick_respawns() -> void:
	var i := respawns.size() - 1
	while i >= 0:
		var r := respawns[i]
		r["ticks_left"] = int(r["ticks_left"]) - 1
		if int(r["ticks_left"]) <= 0:
			respawns.remove_at(i)
			if not _node_tiles.has(r["tile"]) and grid.at(r["tile"]) == null:
				var n := add_object(str(r["kind"]), r["tile"])
				node_respawned.emit(n)
			else:
				r["ticks_left"] = 100  # Kachel belegt: spaeter noch einmal versuchen
				respawns.append(r)
		i -= 1


func _remove_node(n: ResourceNode) -> void:
	nodes.erase(n.id)
	_node_tiles.erase(n.tile)
	node_removed.emit(n.id)
	if n.respawn_ticks > 0:
		respawns.append({"kind": n.kind, "tile": n.tile, "ticks_left": n.respawn_ticks})


func _emit_too_hard(n: ResourceNode, tool: String) -> void:
	if _too_hard_cooldown > 0:
		return
	_too_hard_cooldown = TOO_HARD_INTERVAL
	too_hard.emit(n, tool)


func _apply(cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"place":
			_cmd_place(cmd)
		"remove":
			_cmd_remove(cmd)
		"deposit":
			_cmd_deposit(cmd)
		"withdraw":
			_cmd_withdraw(cmd)
		"rotate":
			_cmd_rotate(cmd)


# --- Bauen ----------------------------------------------------------------

func player_tile() -> Vector2i:
	return Vector2i(floori(player.pos.x / float(TILE)), floori(player.pos.y / float(TILE)))


func building_count(def_id: String) -> int:
	var n := 0
	for b: Building in buildings.values():
		if b.def.id == def_id:
			n += 1
	return n


func next_cost(def: BuildingDef) -> Dictionary:
	return Economy.cost_for(def, building_count(def.id))


func in_build_range(tile: Vector2i, size: Vector2i) -> bool:
	var pt := player_tile()
	for c in Grid.footprint(tile, size):
		var d := c - pt
		if maxi(absi(d.x), absi(d.y)) > BUILD_RANGE_TILES:
			return false
	return true


func _tile_blocked(tile: Vector2i) -> bool:
	return _node_tiles.has(tile) or tile == player_tile()


func can_place_def(def: BuildingDef, tile: Vector2i, rot: int) -> bool:
	return grid.can_place(tile, def.rotated_size(rot), _tile_blocked)


func _cmd_place(cmd: Dictionary) -> void:
	var def: BuildingDef = defs.get(str(cmd.get("def_id", "")), null)
	if def == null:
		place_failed.emit("unknown")
		return
	var tile: Vector2i = cmd.get("tile", Vector2i.ZERO)
	var rot: int = int(cmd.get("rot", 0))
	if not in_build_range(tile, def.rotated_size(rot)):
		place_failed.emit("range")
		return
	if not can_place_def(def, tile, rot):
		place_failed.emit("blocked")
		return
	var cost := next_cost(def)
	if not Economy.can_afford(player.inventory, cost):
		place_failed.emit("cost")
		return
	Economy.pay(player.inventory, cost)
	var b := Building.create(next_id(), def, tile, rot)
	b.paid_cost = cost
	if b is Machine:
		(b as Machine).recipes = available_recipes(def.id)
	grid.place(b)
	buildings[b.id] = b
	_network_dirty = true
	progression.on_build()
	building_placed.emit(b)


## Platziert ohne Kosten und Reichweite (Tests, Dev-Szenarien).
func place_free(def_id: String, tile: Vector2i, rot: int = 0) -> Building:
	var def: BuildingDef = defs[def_id]
	if not can_place_def(def, tile, rot):
		return null
	var b := Building.create(next_id(), def, tile, rot)
	if b is Machine:
		(b as Machine).recipes = available_recipes(def.id)
	grid.place(b)
	buildings[b.id] = b
	_network_dirty = true
	building_placed.emit(b)
	return b


func _cmd_rotate(cmd: Dictionary) -> void:
	var b := grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null or not (b is Conveyor or b is Extractor):
		return
	b.rot = posmod(int(cmd.get("rot", 0)), 4)
	_network_dirty = true
	building_changed.emit(b)


# --- Förderbänder ---------------------------------------------------------

## Kurvenformen und Tick-Reihenfolge neu berechnen (nach jeder Bauänderung).
func _rebuild_network() -> void:
	_network_dirty = false
	var belts: Array[Conveyor] = []
	for b: Building in buildings.values():
		if b is Conveyor:
			belts.append(b)
	var out_tiles: Dictionary = {}  # Kacheln, auf die ein Maschinen-Ausgang zeigt
	for b: Building in buildings.values():
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
			building_changed.emit(b)
	conveyor_order.clear()
	var visited: Dictionary = {}
	for b in belts:
		_visit_belt(b, visited)


func _visit_belt(b: Conveyor, visited: Dictionary) -> void:
	if visited.has(b.id):
		return
	visited[b.id] = true
	var n := grid.at(b.front_tile())
	if n is Conveyor and n != b and (n as Conveyor).front_tile() != b.tile:
		_visit_belt(n, visited)
	conveyor_order.append(b)


func _tick_conveyors() -> void:
	for c in conveyor_order:
		if c.front_wants_transfer():
			_try_transfer(c)
		c.advance()


func _try_transfer(c: Conveyor) -> void:
	var item: String = str(c.front_item()["item"])
	var target := grid.at(c.front_tile())
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
	if target is Chest:
		accepted = target.accept_stack(item, 1) == 1
	elif target is SellTerminal:
		accepted = (target as SellTerminal).accept_from_belt(item)
	elif target.accepts_from_belt(c.tile, c.front_tile()):
		accepted = target.accept_stack(item, 1) == 1
	if accepted:
		c.pop_front()
		building_changed.emit(target)


## Maschinen- und Stationsausgänge legen je Tick höchstens ein Item auf das Band vor dem Port.
func _tick_outputs() -> void:
	for b: Building in buildings.values():
		if b is Conveyor or not b.has_output():
			continue
		for p in b.ports_world():
			if p["dir"] != "out":
				continue
			var t := grid.at(p["outside"])
			if t is Conveyor and (t as Conveyor).front_tile() != p["cell"] and (t as Conveyor).rear_free():
				var item := b.pop_output_one()
				if item != "":
					(t as Conveyor).try_insert(item, 0)
					building_changed.emit(b)
				break


func _tick_extractors() -> void:
	for b: Building in buildings.values():
		if not (b is Extractor):
			continue
		var e := b as Extractor
		if not e.tick_extract():
			continue
		for d: Vector2i in Conveyor.DIRS:
			var nid: int = _node_tiles.get(e.tile + d, -1)
			if nid < 0 or not nodes.has(nid):
				continue
			var n: ResourceNode = nodes[nid]
			if n.is_pile() and n.tier <= Extractor.TIER:
				e.buffer.append(n.item_id())
				building_changed.emit(e)
				break


## Rezepte einer Maschinenart, die ohne Tech oder mit freigeschalteter Tech verfügbar sind.
func available_recipes(machine_id: String) -> Array[RecipeDef]:
	var result: Array[RecipeDef] = []
	for r in recipes:
		if r.machine == machine_id and (r.tech == "" or unlocked_tech.has(r.tech)):
			result.append(r)
	return result


## Nach einer Tech-Freischaltung: Rezeptlisten aller Maschinen erneuern.
func refresh_recipes() -> void:
	for b: Building in buildings.values():
		if b is Machine:
			(b as Machine).recipes = available_recipes(b.def.id)


func _cmd_remove(cmd: Dictionary) -> void:
	var b := grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null:
		return
	grid.remove(b)
	buildings.erase(b.id)
	_network_dirty = true
	var to_refund: Dictionary = b.paid_cost.duplicate()
	for item in b.contents():
		to_refund[item] = to_refund.get(item, 0) + b.contents()[item]
	var rest := Economy.refund(player.inventory, to_refund)
	for item in rest:
		for i in int(rest[item]):
			add_loose(item, b.center_px() + _scatter())
	building_removed.emit(b.id)


func _cmd_deposit(cmd: Dictionary) -> void:
	var b := grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null:
		return
	var slot_index: int = int(cmd.get("slot", 0))
	if slot_index < 0 or slot_index >= player.inventory.slots.size():
		return
	var s: Dictionary = player.inventory.slots[slot_index]
	if s["item"] == "":
		return
	var item: String = s["item"]
	var accepted := b.accept_stack(item, int(s["count"]))
	if accepted > 0:
		player.inventory.remove(item, accepted)
		building_changed.emit(b)
	else:
		deposit_rejected.emit(b, item)


func _cmd_withdraw(cmd: Dictionary) -> void:
	var b := grid.at(cmd.get("tile", Vector2i.ZERO))
	if b == null:
		return
	var stack := b.withdraw_stack()
	if stack.is_empty():
		return
	var rest := player.inventory.add(stack["item"], stack["count"])
	if rest > 0:
		b.accept_stack(stack["item"], rest)
	building_changed.emit(b)


## Nächstes Gebäude, dessen Rechteck (um max_dist_px erweitert) pos enthält.
func building_near(pos: Vector2i, max_dist_px: int) -> Building:
	var best: Building = null
	var best_d := INF
	for b: Building in buildings.values():
		var r := b.rect_px().grow(max_dist_px)
		if not r.has_point(pos):
			continue
		var d := Vector2(pos).distance_to(Vector2(b.center_px()))
		if d < best_d:
			best_d = d
			best = b
	return best


func _scatter() -> Vector2i:
	return Vector2i(
		rng.randi_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX),
		rng.randi_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX))


# --- Saugen ---------------------------------------------------------------

func _tick_suction() -> void:
	if not player.suck_held or player.suck_cooldown > 0:
		return
	var target: Variant = _find_suck_target()
	if target == null:
		var hard := _find_too_hard_suck_target()
		if hard != null:
			_emit_too_hard(hard, "suction")
		return
	var item_id: String = target.item_id if target is LooseItem else _peek_suck_item(target as ResourceNode)
	if not player.inventory.can_add(item_id):
		if not _full_notified:
			_full_notified = true
			inventory_full.emit()
		return
	var from_pos: Vector2i
	var tier := 1
	if target is LooseItem:
		from_pos = target.pos
		tier = target.tier
		loose.erase(target.id)
		loose_removed.emit(target.id)
	else:
		var node := target as ResourceNode
		from_pos = node.center_px()
		tier = node.tier
		node.take_one()
		if node.is_wreck() and node.is_depleted():
			_remove_node(node)
			wreck_destroyed.emit(node.id)
		else:
			node_changed.emit(node)
	player.inventory.add(item_id, 1)
	player.suck_cooldown = PlayerState.SUCK_INTERVAL
	progression.on_collect(tier)
	item_collected.emit(item_id, from_pos)


## Welches Item ein Saug-Objekt als Naechstes liefert (ohne es zu entnehmen).
func _peek_suck_item(node: ResourceNode) -> String:
	if node.is_pile():
		return node.item_id()
	var keys := node.loot.keys()
	keys.sort()
	var best := ""
	var best_n := 0
	for k: String in keys:
		if int(node.loot[k]) > best_n:
			best = k
			best_n = int(node.loot[k])
	return best


## Saug-Objekt im Kegel, dessen Stufe zu hoch ist (fuer Feedback).
func _find_too_hard_suck_target() -> ResourceNode:
	for n: ResourceNode in nodes.values():
		if n.uses_hammer() or n.is_depleted() or n.tier <= player.suction_tier:
			continue
		if _cone_distance(n.center_px()) < INF:
			return n
	return null


## Lose Items haben Vorrang vor Haufen; innerhalb einer Gruppe das nächstgelegene.
func _find_suck_target() -> Variant:
	var best: Variant = null
	var best_d := INF
	for item: LooseItem in loose.values():
		var d := _cone_distance(item.pos)
		if d < best_d:
			best_d = d
			best = item
	if best != null:
		return best
	for n: ResourceNode in nodes.values():
		if n.uses_hammer() or n.is_depleted() or n.tier > player.suction_tier:
			continue
		var d := _cone_distance(n.center_px())
		if d < best_d:
			best_d = d
			best = n
	return best


## Abstand zum Ziel, wenn es im Saugkegel liegt, sonst INF.
func _cone_distance(target: Vector2i) -> float:
	var d := Vector2(target - player.pos)
	var dist := d.length()
	if dist > PlayerState.SUCK_RANGE_PX:
		return INF
	if dist < 1.0:
		return 0.0
	if d.normalized().dot(player.aim) < cos(PlayerState.SUCK_HALF_ANGLE_RAD):
		return INF
	return dist


# --- Hämmern --------------------------------------------------------------

func _tick_hammer() -> void:
	if not player.hammer_pressed or player.hammer_cooldown > 0:
		return
	var wreck := _find_wreck_target()
	if wreck == null:
		return
	player.hammer_cooldown = PlayerState.HAMMER_INTERVAL
	if wreck.tier > player.hammer_tier:
		_emit_too_hard(wreck, "hammer")
		return
	var item_id := wreck.take_one()
	if item_id != "":
		add_loose(item_id, wreck.center_px() + _scatter(), wreck.tier)
	wreck_hit.emit(wreck)
	if wreck.is_depleted():
		_remove_node(wreck)
		wreck_destroyed.emit(wreck.id)
	else:
		node_changed.emit(wreck)


func _find_wreck_target() -> ResourceNode:
	var hit_point := Vector2(player.pos) + player.aim * PlayerState.HAMMER_REACH_PX
	var best: ResourceNode = null
	var best_d := float(PlayerState.HAMMER_RANGE_PX)
	for n: ResourceNode in nodes.values():
		if not n.uses_hammer():
			continue
		var d := hit_point.distance_to(Vector2(n.center_px()))
		if d <= best_d:
			best_d = d
			best = n
	return best
