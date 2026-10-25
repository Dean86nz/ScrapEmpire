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

const LOOT_SCATTER_PX := 40

var tick_count: int = 0
var width_tiles: int = 120
var height_tiles: int = 90
var player := PlayerState.new()
var rng := SimRng.new(0)
var nodes: Dictionary = {}  # id → ResourceNode
var loose: Dictionary = {}  # id → LooseItem

var _commands: Array[Dictionary] = []
var _next_id: int = 1
var _full_notified := false


func _init() -> void:
	# Methoden-Callable statt Lambda: ein Lambda hielte self fest und erzeugte einen Zyklus.
	player.inventory.changed.connect(_on_inventory_changed)


func _on_inventory_changed() -> void:
	_full_notified = false


# --- Aufbau ---------------------------------------------------------------

func next_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func add_pile(kind: String, tile: Vector2i, amount: int) -> ResourceNode:
	var n := ResourceNode.make_pile(next_id(), kind, tile, amount)
	nodes[n.id] = n
	node_added.emit(n)
	return n


func add_wreck(tile: Vector2i, loot: Dictionary) -> ResourceNode:
	var n := ResourceNode.make_wreck(next_id(), tile, loot)
	nodes[n.id] = n
	node_added.emit(n)
	return n


func add_loose(item_id: String, pos: Vector2i) -> LooseItem:
	var item := LooseItem.new(next_id(), item_id, pos)
	loose[item.id] = item
	loose_added.emit(item)
	return item


func size_px() -> Vector2i:
	return Vector2i(width_tiles, height_tiles) * ResourceNode.TILE


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

	if player.suck_cooldown > 0:
		player.suck_cooldown -= 1
	if player.hammer_cooldown > 0:
		player.hammer_cooldown -= 1

	_tick_suction()
	_tick_hammer()
	player.hammer_pressed = false
	tick_count += 1


func _apply(_cmd: Dictionary) -> void:
	pass  # Befehlstypen kommen mit dem Bauen (MS2)


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
		var offset := Vector2i(
			rng.randi_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX),
			rng.randi_range(-LOOT_SCATTER_PX, LOOT_SCATTER_PX))
		add_loose(item_id, wreck.center_px() + offset)
	wreck_hit.emit(wreck)
	if wreck.is_depleted():
		nodes.erase(wreck.id)
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
