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
signal tech_unlocked(id: String)
signal research_failed(reason: String)
signal skill_bought(id: String, level: int)
signal skill_failed(reason: String)
signal modifiers_changed(mods: Dictionary)
signal inventory_resized()
signal helper_added(helper: Helper)
signal helper_removed(id: int)
signal helper_failed(reason: String)
signal helper_quip(helper: Helper, key: String)
signal helper_upgrade_bought(id: String, level: int)
signal zone_unlocked(zone_id: String)

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
var unlocked_tech: Dictionary = {}  # tech_id → true (Spiegel von tech.unlocked)
var tech := TechState.new()
var skills := SkillState.new()
var tasks := TaskList.new()
var flags: Dictionary = {}  # tutorial_step, tutorial_done, gate_open
var zones := ZoneTracker.new()
var helpers: Dictionary = {}          # id → Helper
var helper_cfg: Dictionary = {}       # data/helpers.json
var helper_upgrades: Dictionary = {}  # upgrade id → Stufe
var mods: Dictionary = Modifiers.DEFAULTS.duplicate()
var unlocked_buildings: Dictionary = {}  # def_id → true
var unlocked_features: Dictionary = {}   # autopilot, helpers
var rare_items: Dictionary = {}          # item_id → true (von außen gesetzt)
var gate_buildings := false              # true sobald Tech-Daten geladen sind
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
var blocked_tiles: Dictionary = {}  # Zaun-Kacheln (nicht bebaubar)


func _init() -> void:
	# Methoden-Callable statt Lambda: ein Lambda hielte self fest und erzeugte einen Zyklus.
	player.inventory.changed.connect(_on_inventory_changed)
	zones.zone_unlocked.connect(_on_zone_unlocked)


func _on_zone_unlocked(id: String) -> void:
	zone_unlocked.emit(id)


## Tech- und Skilldaten setzen; danach sind nur freigeschaltete Gebäude baubar.
func setup_progression_data(tech_defs: Array, skill_data: Dictionary) -> void:
	tech.setup(tech_defs)
	skills.setup(skill_data)
	gate_buildings = true
	for id in tech.unlocked.keys():
		_apply_tech_effects(str(id))
	recompute_modifiers()


func is_building_unlocked(def_id: String) -> bool:
	return not gate_buildings or unlocked_buildings.has(def_id)


func recompute_modifiers() -> void:
	mods = Modifiers.compute(skills.defs, skills.levels, tech.defs, tech.unlocked, helper_cfg.get("upgrades", []), helper_upgrades)
	if player.apply_modifiers(mods):
		inventory_resized.emit()
	for h: Helper in helpers.values():
		_apply_helper_mods(h)
	for b: Building in buildings.values():
		if b is SellTerminal:
			(b as SellTerminal).sell_interval = int(mods["sell_interval"])
	modifiers_changed.emit(mods)


func _apply_tech_effects(id: String) -> void:
	unlocked_tech[id] = true
	for eff: Dictionary in tech.effects_of(id):
		match str(eff.get("type", "")):
			"unlock_building":
				unlocked_buildings[str(eff["id"])] = true
			"unlock_recipe":
				pass  # über unlocked_tech + refresh_recipes
			"unlock_feature":
				unlocked_features[str(eff["id"])] = true
	refresh_recipes()


func _cmd_research(cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := tech.can_start(id, bolts, player.inventory)
	if reason != "":
		research_failed.emit(reason)
		return
	var d: Dictionary = tech.by_id[id]
	bolts -= int(d.get("cost_bolts", 0))
	for item in d.get("cost_items", {}):
		player.inventory.remove(str(item), int(d["cost_items"][item]))
	bolts_changed.emit(bolts)
	progression.on_tech(int(d.get("cost_bolts", 0)))
	tech.start(id)
	if tech.current_id == "":  # Zeit 0: sofort fertig
		pass


func _cmd_buy_skill(cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := skills.can_buy(id, progression.skill_points)
	if reason != "":
		skill_failed.emit(reason)
		return
	progression.skill_points -= 1
	skills.buy(id)
	recompute_modifiers()
	skill_bought.emit(id, skills.level_of(id))


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
					var value: int = sale_value(sold, (b as SellTerminal).buffer.size() + 1)
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

	tasks.tick(self, player)
	_tick_helpers()
	_tick_suction()
	_tick_magnet()
	_tick_hammer()
	_tick_respawns()
	if tick_count % 20 == 0:
		zones.check_unlocks(nodes)
	var done := tech.tick()
	if done != "":
		_apply_tech_effects(done)
		recompute_modifiers()
		tech_unlocked.emit(done)
	player.hammer_pressed = false
	tick_count += 1


# --- Helfer-Roboter ---------------------------------------------------------

func helper_count() -> int:
	return helpers.size()


func next_helper_cost() -> Dictionary:
	var n := helper_count()
	var base := float(helper_cfg.get("cost_base_bolts", 400))
	var growth := float(helper_cfg.get("cost_growth", 1.5))
	var bolts_cost := int(round(base * pow(growth, n) / 10.0)) * 10
	return {"bolts": bolts_cost, "chrome": int(helper_cfg.get("cost_chrome", 5))}


## "" wenn kaufbar, sonst Grund: locked, max, bolts, chrome, no_depot, zone_locked
func can_buy_helper(depot_tile: Vector2i, zone_tile: Vector2i = Vector2i(-1, -1)) -> String:
	if not unlocked_features.has("helpers"):
		return "locked"
	if zone_tile.x >= 0:
		var zid := zones.zone_id_at(zone_tile)
		if zid != "" and not zones.is_unlocked(zid):
			return "zone_locked"
	if helper_count() >= int(helper_cfg.get("max_helpers", 6)):
		return "max"
	var cost := next_helper_cost()
	if bolts < int(cost["bolts"]):
		return "bolts"
	if player.inventory.count_of("chrome") < int(cost["chrome"]):
		return "chrome"
	if grid.at(depot_tile) == null:
		return "no_depot"
	return ""


func _apply_helper_mods(h: Helper) -> void:
	h.apply_modifiers(mods, int(helper_cfg.get("base_speed_px_per_s", 224)), int(helper_cfg.get("base_slots", 3)), int(helper_cfg.get("base_stack", 10)))


func _schedule_stuck(h: Helper) -> void:
	var lo := int(helper_cfg.get("stuck_min_s", 240)) * 20
	var hi := int(helper_cfg.get("stuck_max_s", 360)) * 20
	h.stuck_timer = rng.randi_range(lo, hi)


func add_helper(zone_tile: Vector2i, depot_tile: Vector2i, name_index: int = -1, color_index: int = -1) -> Helper:
	var h := Helper.new()
	h.id = next_id()
	var n := helper_count()
	h.name_index = n if name_index < 0 else name_index
	h.color_index = n if color_index < 0 else color_index
	h.zone_tile = zone_tile
	h.radius_tiles = int(helper_cfg.get("zone_radius_tiles", 6))
	h.depot_tile = depot_tile
	var depot := grid.at(depot_tile)
	h.pos = depot.center_px() + Vector2i(0, 48) if depot != null else zone_tile * TILE
	_apply_helper_mods(h)
	_schedule_stuck(h)
	helpers[h.id] = h
	helper_added.emit(h)
	return h


func _cmd_buy_helper(cmd: Dictionary) -> void:
	var zone_tile: Vector2i = cmd.get("zone", Vector2i.ZERO)
	var depot_tile: Vector2i = cmd.get("depot", Vector2i.ZERO)
	var reason := can_buy_helper(depot_tile, zone_tile)
	if reason != "":
		helper_failed.emit(reason)
		return
	var cost := next_helper_cost()
	bolts -= int(cost["bolts"])
	player.inventory.remove("chrome", int(cost["chrome"]))
	bolts_changed.emit(bolts)
	var h := add_helper(zone_tile, depot_tile)
	var hired: Array = helper_cfg.get("quips_hired", [])
	if not hired.is_empty():
		helper_quip.emit(h, str(hired[h.id % hired.size()]))


func _cmd_remove_helper(cmd: Dictionary) -> void:
	var id := int(cmd.get("id", -1))
	if not helpers.has(id):
		return
	var h: Helper = helpers[id]
	# Inhalt fällt als lose Items am Standort
	for s: Dictionary in h.inventory.slots:
		for i in int(s["count"]):
			if i < 20:
				add_loose(s["item"], h.pos + _scatter())
	helpers.erase(id)
	helper_removed.emit(id)


func helper_upgrade_def(id: String) -> Dictionary:
	for u: Dictionary in helper_cfg.get("upgrades", []):
		if str(u["id"]) == id:
			return u
	return {}


## "" wenn kaufbar, sonst: unknown, max, locked, bolts, chrome
func can_buy_helper_upgrade(id: String) -> String:
	var u := helper_upgrade_def(id)
	if u.is_empty():
		return "unknown"
	var level := int(helper_upgrades.get(id, 0))
	if level >= int(u.get("max_level", 1)):
		return "max"
	var feature := str(u.get("requires_feature", ""))
	if feature != "" and not unlocked_features.has(feature):
		return "locked"
	if bolts < int(u["cost_bolts"][level]):
		return "bolts"
	if player.inventory.count_of("chrome") < int(u["cost_chrome"][level]):
		return "chrome"
	return ""


func _cmd_buy_helper_upgrade(cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := can_buy_helper_upgrade(id)
	if reason != "":
		helper_failed.emit(reason)
		return
	var u := helper_upgrade_def(id)
	var level := int(helper_upgrades.get(id, 0))
	bolts -= int(u["cost_bolts"][level])
	player.inventory.remove("chrome", int(u["cost_chrome"][level]))
	helper_upgrades[id] = level + 1
	bolts_changed.emit(bolts)
	recompute_modifiers()
	helper_upgrade_bought.emit(id, level + 1)


## Saugen/Hämmern für einen Helfer (gleiche Regeln wie Rusty, aber ohne Kegel: Reichweite reicht).
func helper_work(h: Helper) -> void:
	if h.suck_held:
		if h.suck_cooldown > 0:
			h.suck_cooldown -= 1
		else:
			var target: Variant = _find_suck_target_for(h)
			if target != null and h.inventory.can_add(target.item_id if target is LooseItem else _peek_suck_item(target)):
				var item_id: String
				if target is LooseItem:
					item_id = target.item_id
					loose.erase(target.id)
					loose_removed.emit(target.id)
				else:
					var node := target as ResourceNode
					item_id = node.take_one()
					if node.is_wreck() and node.is_depleted():
						_remove_node(node)
						wreck_destroyed.emit(node.id)
					else:
						node_changed.emit(node)
				h.inventory.add(item_id, 1)
				h.suck_cooldown = PlayerState.BASE_SUCK_INTERVAL
				progression.on_collect(1)
	if h.hammer_pressed:
		h.hammer_pressed = false
		if h.hammer_cooldown > 0:
			pass
		else:
			var hit_point := Vector2(h.pos) + h.aim * PlayerState.HAMMER_REACH_PX
			for n: ResourceNode in nodes.values():
				if not n.uses_hammer() or n.tier > h.hammer_tier:
					continue
				if hit_point.distance_to(Vector2(n.center_px())) <= float(h.hammer_range_px):
					h.hammer_cooldown = PlayerState.BASE_HAMMER_INTERVAL
					var item_id := n.take_one()
					if item_id != "":
						add_loose(item_id, n.center_px() + _scatter(), n.tier)
					wreck_hit.emit(n)
					if n.is_depleted():
						_remove_node(n)
						wreck_destroyed.emit(n.id)
					else:
						node_changed.emit(n)
					break
	if h.hammer_cooldown > 0:
		h.hammer_cooldown -= 1


func _find_suck_target_for(h: Helper) -> Variant:
	var best: Variant = null
	var best_d := INF
	for item: LooseItem in loose.values():
		var d := Vector2(item.pos - h.pos).length()
		if d <= h.suck_range_px and d < best_d:
			best_d = d
			best = item
	if best != null:
		return best
	for n: ResourceNode in nodes.values():
		if n.uses_hammer() or n.is_depleted() or n.tier > h.suction_tier:
			continue
		var d := Vector2(n.center_px() - h.pos).length()
		if d <= h.suck_range_px and d < best_d:
			best_d = d
			best = n
	return best


func _tick_helpers() -> void:
	for h: Helper in helpers.values():
		h.idle_quip_timer -= 1
		if h.idle_quip_timer <= 0:
			h.idle_quip_timer = rng.randi_range(60 * 20, 120 * 20)
			var idle: Array = helper_cfg.get("quips_idle", [])
			if not idle.is_empty():
				helper_quip.emit(h, str(idle[rng.randi_range(0, idle.size() - 1)]))
		if h.stuck_timer == 1:
			h.pause_for_stuck(int(helper_cfg.get("stuck_pause_s", 5)) * 20)
			var stuck: Array = helper_cfg.get("quips_stuck", [])
			if not stuck.is_empty():
				helper_quip.emit(h, str(stuck[rng.randi_range(0, stuck.size() - 1)]))
			_schedule_stuck(h)
		h.tick(self)
		helper_work(h)


## Magnet-Skill: lose Items im Radius werden ohne Zielen eingesammelt (1 je Tick).
func _tick_magnet() -> void:
	if player.magnet_radius_px <= 0:
		return
	var r2 := player.magnet_radius_px * player.magnet_radius_px
	for item: LooseItem in loose.values():
		if Vector2(item.pos - player.pos).length_squared() > r2:
			continue
		if not player.inventory.can_add(item.item_id):
			return
		loose.erase(item.id)
		loose_removed.emit(item.id)
		player.inventory.add(item.item_id, 1)
		progression.on_collect(item.tier)
		item_collected.emit(item.item_id, item.pos)
		return


func _tick_respawns() -> void:
	var i := respawns.size() - 1
	while i >= 0:
		var r := respawns[i]
		r["ticks_left"] = int(r["ticks_left"]) - 1
		if int(r["ticks_left"]) <= 0:
			respawns.remove_at(i)
			var kind := str(r["kind"])
			var is_res: bool = ResourceNode.has_kind(kind) and (bool(ResourceNode.defs[kind].get("resource", false)) or str(ResourceNode.defs[kind].get("type", "pile")) == "pile")
			if not is_res and not zones.allows_trash_respawn(r["tile"], nodes):
				i -= 1
				continue  # Zone inzwischen sauber genug: kein Müll mehr
			if not _node_tiles.has(r["tile"]) and grid.at(r["tile"]) == null:
				var n := add_object(kind, r["tile"])
				node_respawned.emit(n)
				zones.refresh(nodes)
			else:
				r["ticks_left"] = 100  # Kachel belegt: spaeter noch einmal versuchen
				respawns.append(r)
		i -= 1


func _remove_node(n: ResourceNode) -> void:
	nodes.erase(n.id)
	_node_tiles.erase(n.tile)
	node_removed.emit(n.id)
	# Rohstoffquellen respawnen immer; Müll nur, solange die Zone unter 50 % sauber ist.
	if n.respawn_ticks > 0 and (n.is_resource() or zones.allows_trash_respawn(n.tile, nodes)):
		respawns.append({"kind": n.kind, "tile": n.tile, "ticks_left": n.respawn_ticks})
	zones.refresh(nodes)


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
		"research":
			_cmd_research(cmd)
		"buy_skill":
			_cmd_buy_skill(cmd)
		"buy_helper":
			_cmd_buy_helper(cmd)
		"buy_helper_upgrade":
			_cmd_buy_helper_upgrade(cmd)
		"remove_helper":
			_cmd_remove_helper(cmd)


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
	return _node_tiles.has(tile) or tile == player_tile() or blocked_tiles.has(tile)


func can_place_def(def: BuildingDef, tile: Vector2i, rot: int) -> bool:
	return grid.can_place(tile, def.rotated_size(rot), _tile_blocked)


func _cmd_place(cmd: Dictionary) -> void:
	var def: BuildingDef = defs.get(str(cmd.get("def_id", "")), null)
	if def == null:
		place_failed.emit("unknown")
		return
	if not is_building_unlocked(def.id):
		place_failed.emit("locked")
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
	if b is SellTerminal:
		(b as SellTerminal).sell_interval = int(mods["sell_interval"])
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


## Verkaufswert mit Boni: Feilschen, Kenner (seltene Items), Großhändler (Puffer ≥ 20).
func sale_value(item_id: String, buffer_size_at_sale: int) -> int:
	var v := float(item_values.get(item_id, 0)) * float(mods["sell_mult"])
	if rare_items.has(item_id):
		v *= float(mods["rare_mult"])
	if buffer_size_at_sale >= 20:
		v *= 1.0 + float(mods["bulk_bonus"])
	return maxi(int(round(v)), 0)


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
	player.suck_cooldown = player.suck_interval
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
	if dist > player.suck_range_px:
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
	player.hammer_cooldown = player.hammer_interval
	if wreck.tier > player.hammer_tier:
		_emit_too_hard(wreck, "hammer")
		return
	for i in player.hammer_items:
		var item_id := wreck.take_one()
		if item_id == "":
			break
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
	var best_d := float(player.hammer_range_px)
	for n: ResourceNode in nodes.values():
		if not n.uses_hammer():
			continue
		var d := hit_point.distance_to(Vector2(n.center_px()))
		if d <= best_d:
			best_d = d
			best = n
	return best
