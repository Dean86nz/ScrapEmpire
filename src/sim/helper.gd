class_name Helper
extends WorkerBody
## Helfer-Roboter (GDD Kap. 18): arbeitet in einer Zone (Kreis um zone_tile) alle Objekte bis
## zu seiner Werkzeug-Stufe ab und bringt volle Ladung zum Lager (depot_tile). Bewegt sich in
## der Sim selbst (geradeaus, ohne Kollision). Nutzt die TaskList-Logik mit zwei Schritten.

signal quip(key: String)


var id: int
var name_index := 0
var color_index := 0
var zone_tile := Vector2i.ZERO
var radius_tiles := 6
var depot_tile := Vector2i.ZERO
var tasks := TaskList.new()
var speed_px_per_tick := 11
var stuck_timer := 0        # Ticks bis zum nächsten „Steckenbleiben“
var _last_loops := 0
var _plan_cooldown := 0
var suck_cooldown := 0
var hammer_cooldown := 0
var idle_quip_timer := 1200  # Ticks bis zum nächsten Leerlauf-Spruch
var bored := ""               # "" = hat Arbeit; "empty" = nichts mehr da; "too_hard" = nur zu harter Müll
var zone_id := ""             # zugewiesene Zone (seit MS34); "" = alter Kreis um zone_tile
var auto := true              # seit MS42 immer: sucht sich selbst die nächste Zone mit passendem Müll
var rally_id := -1            # Boss, zu dem Rusty gerufen hat (-1 = keiner)


func _init() -> void:
	inventory = Inventory.new(3, 10)


func display_name(names: Array) -> String:
	return str(names[name_index % names.size()]) if not names.is_empty() else "Helfer %d" % id


func apply_modifiers(m: Dictionary, base_speed_px_per_s: int, base_slots: int, base_stack: int) -> void:
	suction_tier = int(m["helper_tier"])
	hammer_tier = int(m["helper_tier"])
	speed_px_per_tick = maxi(int(round(base_speed_px_per_s * float(m["helper_speed_mult"]) / 20.0)), 1)
	var stack := base_stack + int(m["helper_capacity_add"])
	if inventory.slot_count != base_slots or inventory.stack_size != stack:
		inventory.resize(base_slots, stack)


func zone_center_px() -> Vector2i:
	return zone_tile * TILE + Vector2i(TILE / 2, TILE / 2)


func in_zone(tile: Vector2i) -> bool:
	if zone_id != "" and _zones != null:
		return _zones.zone_id_at(tile) == zone_id
	return Vector2(tile - zone_tile).length() <= float(radius_tiles) + 0.5


var _zones: ZoneTracker


## Nach dem Umsetzen sofort neu planen.
func request_replan() -> void:
	_plan_cooldown = 0
	tasks.steps.clear()


## Ein Tick: ggf. neu planen, Aufgaben ausführen, bewegen.
func tick(world: SimWorld) -> void:
	if _plan_cooldown > 0:
		_plan_cooldown -= 1
	# Neu planen, wenn keine Schritte vorliegen oder die Liste einmal durchlaufen wurde.
	if tasks.steps.is_empty() or tasks.loops != _last_loops:
		if _plan_cooldown == 0:
			_plan(world)
	tasks.tick(world, self)
	_move()
	if stuck_timer > 0:
		stuck_timer -= 1


## Sucht das nächste abbaubare Objekt in der Zone; ohne Ziel: nur abliefern oder warten.
func _plan(world: SimWorld) -> void:
	_zones = world.zones
	var depot := NetworkSystem.depot_for(world, zone_id if zone_id != "" else world.zones.zone_id_at(zone_tile))
	if depot != null:
		depot_tile = depot.tile
	tasks.stop(self)
	tasks.steps.clear()
	tasks.index = 0
	tasks.loops = 0
	_last_loops = 0
	# Verstärkung: zum Boss rennen und mithauen, alles andere wartet
	if rally_id >= 0:
		var boss: ResourceNode = world.nodes.get(rally_id, null)
		if boss != null and not boss.is_depleted():
			bored = ""
			tasks.add_step(TaskList.Type.HAMMER, boss.tile)
			tasks.start(self)
			return
		rally_id = -1
	var best: ResourceNode = null
	var best_d := INF
	var too_hard := false
	for n: ResourceNode in world.nodes.values():
		if n.is_depleted() or not in_zone(n.tile):
			continue
		if n.boss:
			continue  # Bosse nur auf Rustys Ruf
		var tier_ok := n.tier <= (hammer_tier if n.uses_hammer() else suction_tier)
		if not tier_ok:
			too_hard = true
			continue
		var d := Vector2(n.center_px() - pos).length()
		if d < best_d:
			best_d = d
			best = n
	bored = "" if best != null else ("too_hard" if too_hard else "empty")
	if best != null and not inventory.is_full():
		tasks.add_step(TaskList.Type.HAMMER if best.uses_hammer() else TaskList.Type.COLLECT, best.tile)
	if inventory.total() > 0 or best == null:
		tasks.add_step(TaskList.Type.DEPOSIT, depot_tile)
	if tasks.steps.is_empty():
		_plan_cooldown = 100  # nichts zu tun: in 5 s wieder schauen
		return
	tasks.start(self)
	if inventory.total() == 0 and best == null:
		_plan_cooldown = 100


func _move() -> void:
	if not has_move_target():
		return
	var d := Vector2(move_target - pos)
	if d.length() <= speed_px_per_tick:
		pos = move_target
		return
	pos += Vector2i((d.normalized() * speed_px_per_tick).round())
	if d.length() > 1.0:
		aim = d.normalized()


func pause_for_stuck(ticks: int) -> void:
	tasks.wait_ticks = maxi(tasks.wait_ticks, ticks)
	move_target = NONE_TARGET
	suck_held = false


func to_dict() -> Dictionary:
	return {
		"name_index": name_index, "color_index": color_index,
		"pos": [pos.x, pos.y], "zone": [zone_tile.x, zone_tile.y], "radius": radius_tiles,
		"depot": [depot_tile.x, depot_tile.y], "inventory": inventory.to_dict(),
		"stuck_timer": stuck_timer, "zone_id": zone_id, "rally": rally_id,
	}


func from_dict(d: Dictionary) -> void:
	name_index = int(d.get("name_index", 0))
	color_index = int(d.get("color_index", 0))
	pos = SaveCodec.to_v2(d.get("pos"))
	zone_tile = SaveCodec.to_v2(d.get("zone"))
	radius_tiles = int(d.get("radius", 6))
	depot_tile = SaveCodec.to_v2(d.get("depot"))
	inventory.from_dict(d.get("inventory", {}))
	stuck_timer = int(d.get("stuck_timer", 0))
	zone_id = str(d.get("zone_id", ""))
	rally_id = int(d.get("rally", -1))
