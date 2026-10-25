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

var _commands: Array[Dictionary] = []
var _next_id: int = 1
var _full_notified := false
var _node_tiles: Dictionary = {}  # Vector2i → node id (für Bauprüfung)


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


func add_pile(kind: String, tile: Vector2i, amount: int) -> ResourceNode:
	var n := ResourceNode.make_pile(next_id(), kind, tile, amount)
	nodes[n.id] = n
	_node_tiles[tile] = n.id
	node_added.emit(n)
	return n


func add_wreck(tile: Vector2i, loot: Dictionary) -> ResourceNode:
	var n := ResourceNode.make_wreck(next_id(), tile, loot)
	nodes[n.id] = n
	_node_tiles[tile] = n.id
	node_added.emit(n)
	return n


func add_loose(item_id: String, pos: Vector2i) -> LooseItem:
	var item := LooseItem.new(next_id(), item_id, pos)
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

	for b: Building in buildings.values():
		if b.tick():
			if b is SellTerminal:
				var sold: String = (b as SellTerminal).take_sold()
				if sold != "":
					var value: int = int(item_values.get(sold, 0))
					bolts += value
					item_sold.emit(sold, value, b.center_px())
					bolts_changed.emit(bolts)
			building_changed.emit(b)

	if player.suck_cooldown > 0:
		player.suck_cooldown -= 1
	if player.hammer_cooldown > 0:
		player.hammer_cooldown -= 1

	_tick_suction()
	_tick_hammer()
	player.hammer_pressed = false
	tick_count += 1


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
	building_placed.emit(b)


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
		return
	var item_id: String = target.item_id if target is LooseItem else (target as ResourceNode).item_id()
	if not player.inventory.can_add(item_id):
		if not _full_notified:
			_full_notified = true
			inventory_full.emit()
		return
	var from_pos: Vector2i
	if target is LooseItem:
		from_pos = target.pos
		loose.erase(target.id)
		loose_removed.emit(target.id)
	else:
		var node := target as ResourceNode
		from_pos = node.center_px()
		node.take_one()
		node_changed.emit(node)
	player.inventory.add(item_id, 1)
	player.suck_cooldown = PlayerState.SUCK_INTERVAL
	item_collected.emit(item_id, from_pos)


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
		if n.is_wreck() or n.is_depleted():
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
	var item_id := wreck.take_one()
	if item_id != "":
		add_loose(item_id, wreck.center_px() + _scatter())
	wreck_hit.emit(wreck)
	if wreck.is_depleted():
		nodes.erase(wreck.id)
		_node_tiles.erase(wreck.tile)
		node_removed.emit(wreck.id)
		wreck_destroyed.emit(wreck.id)
	else:
		node_changed.emit(wreck)


func _find_wreck_target() -> ResourceNode:
	var hit_point := Vector2(player.pos) + player.aim * PlayerState.HAMMER_REACH_PX
	var best: ResourceNode = null
	var best_d := float(PlayerState.HAMMER_RANGE_PX)
	for n: ResourceNode in nodes.values():
		if not n.is_wreck():
			continue
		var d := hit_point.distance_to(Vector2(n.center_px()))
		if d <= best_d:
			best_d = d
			best = n
	return best
