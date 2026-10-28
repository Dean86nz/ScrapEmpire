class_name Drone
extends RefCounted
## Sammel-Drohne: startet am Schiff, fliegt (ohne Kollision) zum nächsten losen Teil oder
## Rohstoffhaufen in einer freigeschalteten Zone, saugt bis zur Tragkraft und liefert am Schiff ab.
## Lose Teile (z. B. aus zerhämmertem Müll) haben Vorrang. Deterministisch, rein tickbasiert.

enum State { SEEK, COLLECT, RETURN, IDLE, FETCH }

const ARRIVE_PX := 24
const IDLE_TICKS := 40

var id: int
var pos := Vector2i.ZERO
var home := Vector2i.ZERO          # Schiffsmitte
var carry: Dictionary = {}         # item → Menge
var capacity := 6
var speed_px_per_tick := 13
var tier := 1
var collect_interval := 4
var search_radius_px := 30 * 64
var state := State.SEEK
var target_loose := -1             # id eines losen Teils
var target_node := -1              # id eines Haufens
var target_pos := Vector2i.ZERO
var trips := 0
var target_point := -1             # Sammelstelle, von der gerade abgeholt wird
var fetch_min := 8
var _cooldown := 0
var _idle := 0


func apply_modifiers(m: Dictionary, base_speed_px_per_s: int, base_capacity: int) -> void:
	speed_px_per_tick = maxi(int(round(base_speed_px_per_s * float(m.get("drone_speed_mult", 1.0)) / 20.0)), 1)
	capacity = base_capacity + int(m.get("drone_capacity_add", 0))


func carry_total() -> int:
	var n := 0
	for k in carry:
		n += int(carry[k])
	return n


func is_carrying() -> bool:
	return carry_total() > 0


## Wird gerade dieses lose Teil oder dieser Haufen angeflogen? (verhindert, dass alle dasselbe wollen)
func claims_loose(loose_id: int) -> bool:
	return state == State.COLLECT and target_loose == loose_id


func tick(world: SimWorld) -> void:
	match state:
		State.IDLE:
			_idle -= 1
			if _idle <= 0:
				state = State.SEEK
		State.SEEK:
			_seek(world)
		State.COLLECT:
			_collect(world)
		State.FETCH:
			_fetch(world)
		State.RETURN:
			if _fly_to(home):
				var s := ShipSystem.ship(world)
				if s != null:
					for item in carry:
						s.accept_stack(str(item), int(carry[item]))
				carry = {}
				trips += 1
				state = State.SEEK


func _seek(world: SimWorld) -> void:
	if carry_total() >= capacity:
		state = State.RETURN
		return
	# Transport hat Vorrang: Sammelstelle mit dem meisten noch nicht verplanten Material
	var best_p: CollectionPoint = null
	var best_free := fetch_min - 1 if not is_carrying() else 0
	for p in NetworkSystem.points(world):
		var free := p.total() - _claimed_at(world, p.id)
		if free > best_free:
			best_free = free
			best_p = p
	if best_p != null:
		target_point = best_p.id
		target_pos = best_p.center_px()
		state = State.FETCH
		return
	var best_d := float(search_radius_px)
	target_loose = -1
	target_node = -1
	for item: LooseItem in world.loose.values():
		if _claimed_by_other(world, item.id) or not _reachable(world, item.pos):
			continue
		var d := Vector2(item.pos - pos).length()
		if d < best_d:
			best_d = d
			target_loose = item.id
			target_pos = item.pos
	if target_loose < 0:
		best_d = float(search_radius_px)
		for n: ResourceNode in world.nodes.values():
			if not n.is_pile() or n.is_depleted() or n.tier > tier or not _reachable(world, n.center_px()):
				continue
			var d2 := Vector2(n.center_px() - pos).length()
			if d2 < best_d:
				best_d = d2
				target_node = n.id
				target_pos = n.center_px()
	if target_loose >= 0 or target_node >= 0:
		state = State.COLLECT
	elif is_carrying():
		state = State.RETURN
	else:
		state = State.IDLE
		_idle = IDLE_TICKS


func _collect(world: SimWorld) -> void:
	if target_loose >= 0 and not world.loose.has(target_loose):
		state = State.SEEK
		return
	if target_node >= 0 and (not world.nodes.has(target_node) or (world.nodes[target_node] as ResourceNode).is_depleted()):
		state = State.SEEK
		return
	if not _fly_to(target_pos):
		return
	if _cooldown > 0:
		_cooldown -= 1
		return
	_cooldown = collect_interval
	var item_id := ""
	if target_loose >= 0:
		var li: LooseItem = world.loose[target_loose]
		item_id = li.item_id
		world.loose.erase(li.id)
		world.loose_removed.emit(li.id)
		target_loose = -1
	else:
		var n: ResourceNode = world.nodes[target_node]
		item_id = n.take_one()
		NodeSystem.after_take(world, n)
	if item_id != "":
		carry[item_id] = int(carry.get(item_id, 0)) + 1
	if carry_total() >= capacity:
		state = State.RETURN
	elif target_loose < 0 and target_node < 0:
		state = State.SEEK


## Bei der Sammelstelle laden, dann zum Schiff.
func _fetch(world: SimWorld) -> void:
	var p: Building = world.buildings.get(target_point)
	if not (p is CollectionPoint):
		target_point = -1
		state = State.SEEK
		return
	if not _fly_to(target_pos):
		return
	var got := (p as CollectionPoint).take(capacity - carry_total())
	for k in got:
		carry[k] = int(carry.get(k, 0)) + int(got[k])
	world.building_changed.emit(p)
	target_point = -1
	state = State.RETURN if is_carrying() else State.SEEK


## Wie viel Material an dieser Sammelstelle schon andere Drohnen abholen wollen.
func _claimed_at(world: SimWorld, point_id: int) -> int:
	var n := 0
	for d: Drone in world.drones.values():
		if d != self and d.state == State.FETCH and d.target_point == point_id:
			n += d.capacity - d.carry_total()
	return n


func _claimed_by_other(world: SimWorld, loose_id: int) -> bool:
	for d: Drone in world.drones.values():
		if d != self and d.claims_loose(loose_id):
			return true
	return false


## Nur in freigeschalteten Zonen und im Suchradius um das Schiff.
func _reachable(world: SimWorld, p: Vector2i) -> bool:
	if Vector2(p - home).length() > search_radius_px:
		return false
	var zid := world.zones.zone_id_at(Vector2i(p.x / 64, p.y / 64))
	return zid == "" or world.zones.is_unlocked(zid)


## true, wenn angekommen.
func _fly_to(goal: Vector2i) -> bool:
	var d := Vector2(goal - pos)
	if d.length() <= maxf(speed_px_per_tick, ARRIVE_PX):
		pos = goal
		return true
	pos += Vector2i((d.normalized() * speed_px_per_tick).round())
	return false


func to_dict() -> Dictionary:
	return {"pos": [pos.x, pos.y], "carry": carry.duplicate(), "trips": trips}


func from_dict(d: Dictionary) -> void:
	pos = SaveCodec.to_v2(d.get("pos"))
	carry = {}
	for k in d.get("carry", {}):
		carry[str(k)] = int(d["carry"][k])
	trips = int(d.get("trips", 0))
	state = State.RETURN if is_carrying() else State.SEEK
