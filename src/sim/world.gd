class_name SimWorld
extends RefCounted
## Wurzel der Simulation. Kennt keine Nodes, keine Sekunden. Positionen sind Vector2i in Pixeln.
## Befehle (Dictionaries) werden gesammelt und zu Beginn des nächsten Ticks angewandt.
## Änderungen werden per Signal gemeldet; die Darstellung hört darauf.
## Kern-Ablauf (seit MS20): sammeln → am Schiff abliefern (Bolts) → Upgrades → Bots und Drohnen.

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
signal skill_bought(id: String, level: int)
signal skill_failed(reason: String)
signal modifiers_changed(mods: Dictionary)
signal inventory_resized()
signal helper_added(helper: Helper)
signal helper_removed(id: int)
signal helper_failed(reason: String)
signal helper_quip(helper: Helper, key: String)
signal helper_bored(helper: Helper)
signal boss_defeated(kind: String, zone_id: String, reward: int)
signal hammer_impact(node: ResourceNode, tool_tier: int, one_hit: bool)  # Rustys Schlag (Effekte je Stufe)
signal loose_changed(item: LooseItem)                       # Bündel kleiner geworden (MS64)
signal secret_found(id: String)                            # Secret entdeckt (MS60)
signal secret_progress(id: String, n: int, total: int)      # z. B. Ente 5/12
signal helper_fused(helper: Helper)                        # Fusion zu Super-/Mega-Bot (MS57)
signal boss_rally(boss: ResourceNode, called: int)          # Rusty ruft Verstärkung
signal boss_blocked(boss: ResourceNode, have: int, need: int)  # Schlag ohne genug Bots
signal boss_swing(boss: ResourceNode)                      # Bot haut, aber noch zu wenige
signal point_stored(point: Building, count: int)
signal courier_added(courier: Courier)
signal courier_removed(id: int)
signal courier_loaded(courier: Courier, items: Dictionary)
signal courier_unloaded(courier: Courier, depot: Building)
signal courier_failed(reason: String)
signal helper_upgrade_bought(id: String, level: int)
signal drone_added(drone: Drone)
signal drone_removed(id: int)
signal drone_changed(drone: Drone)
signal drone_failed(reason: String)
signal drone_upgrade_bought(id: String, level: int)
signal collectible_added(c: Collectible)
signal collectible_found(c: Collectible, def: Dictionary)
signal zone_unlocked(zone_id: String)
signal ship_received(item: String, n: int)
signal ship_delivered(items: Dictionary, bolts: int, by_player: bool)
signal milestone_reached(def: Dictionary, step: int, value: int, bolts: int)
signal event_warning(type: String, seconds: float, center_px: Vector2)
signal event_started(type: String, targets_px: Array, delays_s: Array)
signal event_landed(type: String, node: ResourceNode)
signal ship_upgraded(ship: Ship)
signal ship_upgrade_bought(id: String, level: int)
signal ship_failed(reason: String)
signal quest_completed(id: String, def: Dictionary)

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
var unlocked_tech: Dictionary = {}  # tech_id → true (Spiegel von tech.unlocked)
var tech := TechState.new()
var skills := SkillState.new()
var flags: Dictionary = {}  # launched, mvp_done …
var zones := ZoneTracker.new()
var helpers: Dictionary = {}          # id → Helper (Sammel-Bots)
var helper_cfg: Dictionary = {}       # data/helpers.json
var helper_upgrades: Dictionary = {}  # upgrade id → Stufe
var mods: Dictionary = Modifiers.DEFAULTS.duplicate()
var unlocked_buildings: Dictionary = {}  # def_id → true
var unlocked_features: Dictionary = {}   # helpers, collection, drones, courier, helper_tools, launch
var rare_items: Dictionary = {}          # item_id → true (von außen gesetzt)
var gate_buildings := false              # true sobald Fortschrittsdaten geladen sind
var bolts: int = 0
var progression := Progression.new()
var respawns: Array[Dictionary] = []  # [{kind, tile, ticks_left}]

var _commands: Array[Dictionary] = []
var _next_id: int = 1
var _full_notified := false
var _node_tiles: Dictionary = {}  # Vector2i → node id (für Bauprüfung)
var _too_hard_cooldown := 0
const TOO_HARD_INTERVAL := 20
var blocked_tiles: Dictionary = {}  # Zaun-Kacheln (nicht bebaubar, Bots fahren drumherum)
var blocked_version := 0            # +1 bei jeder Änderung an blocked_tiles (NavGrid baut neu)
var nav := NavGrid.new()
var nav_changes: Array[Vector2i] = []
var _node_block: Dictionary = {}           # Kachel → Anzahl Objekte, deren Grundfläche sie belegt
var _zone_nodes_cache: Dictionary = {}    # Zonen-ID → Array[ResourceNode] (Leistung, MS64)
var _zone_nodes_dirty := true   # Kacheln mit neuen/entfernten Objekten (Wegfindung, MS61)
var drones: Dictionary = {}          # id → Drone
var drone_cfg: Dictionary = {}
var drone_upgrades: Dictionary = {}  # id → level
var collectible_cfg: Dictionary = {}       # data/collectibles.json
var collectibles: Dictionary = {}          # id → Collectible (noch nicht gefunden, in der Welt)
var collectibles_found: Dictionary = {}    # def_id → true
var ship_cfg: Dictionary = {}              # data/ship.json
var ship_upgrades: Dictionary = {}         # upgrade id → Stufe (Laderaum, Ertrag, Tempo, Saugen, Werkzeug)
var quests := QuestState.new()             # geführte Aufgabenkette
var milestones := MilestoneState.new()     # Meilensteine (MS23)
var events_cfg: Dictionary = {}            # data/events.json (MS30)
var events_state: Dictionary = {}          # nächste Termine, Vorwarnungen, Abwürfe
var couriers: Dictionary = {}              # id → Courier (MS34)
var courier_cooldown := 0                  # Ticks bis zum nächsten Kurier
var dirt := DirtMap.new()                  # Schmutz je Kachel (MS21)
var dirt_cfg: Dictionary = {}              # data/dirt.json
var _dirt_reward := 0                      # geputzte Kacheln seit dem letzten Kleinschrott


func _init() -> void:
	# Methoden-Callable statt Lambda: ein Lambda hielte self fest und erzeugte einen Zyklus.
	player.inventory.changed.connect(_on_inventory_changed)
	zones.zone_unlocked.connect(_on_zone_unlocked)
	zones.dirt = dirt
	item_collected.connect(_quest_collected)
	item_sold.connect(_quest_sold)
	wreck_destroyed.connect(_quest_wreck)
	ship_received.connect(_quest_ship_received)
	quests.completed.connect(_on_quest_completed)
	milestones.reached.connect(_on_milestone_reached)
	zones.stage_changed.connect(_on_zone_stage_changed)


func _quest_collected(item: String, _pos: Vector2i) -> void:
	quests.on_collected(item)


func _quest_sold(_item: String, value: int, _pos: Vector2i) -> void:
	quests.on_sold(value)


func _quest_wreck(_id: int) -> void:
	quests.on_wreck()


func _quest_ship_received(_item: String, n: int) -> void:
	quests.on_ship_received(n)


func _on_quest_completed(id: String, def: Dictionary) -> void:
	quest_completed.emit(id, def)


## Saubere Zone (Stufe 3): der ganze saubere Boden wird Wiese.
func _on_zone_stage_changed(zone_id: String, stage: int) -> void:
	if stage >= 3 and dirt.is_active():
		var z := zones.zone_by_id(zone_id)
		if z.has("rect"):
			dirt.heal_rect(z["rect"])


func _on_milestone_reached(def: Dictionary, step: int, value: int, bolts: int) -> void:
	milestone_reached.emit(def, step, value, bolts)


func _on_zone_unlocked(id: String) -> void:
	zone_unlocked.emit(id)


## Fortschrittsdaten setzen; danach sind nur freigeschaltete Gebäude baubar.
func setup_progression_data(tech_defs: Array, skill_data: Dictionary) -> void:
	tech.setup(tech_defs)
	skills.setup(skill_data)
	gate_buildings = true
	for id in tech.unlocked.keys():
		_apply_tech_effects(str(id))
	recompute_modifiers()


func _on_inventory_changed() -> void:
	_full_notified = false


func set_size(w: int, h: int) -> void:
	width_tiles = w
	height_tiles = h
	grid = Grid.new(w, h)


func next_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func size_px() -> Vector2i:
	return Vector2i(width_tiles, height_tiles) * TILE


func queue_command(cmd: Dictionary) -> void:
	_commands.append(cmd)


func pending_commands() -> int:
	return _commands.size()


func tick() -> void:
	for cmd in _commands:
		_apply(cmd)
	_commands.clear()
	SecretSystem.tick(self)

	for n: ResourceNode in nodes.values():
		if n.tick():
			node_changed.emit(n)

	for b: Building in buildings.values():
		if b.tick():
			if b is Ship:
				ShipSystem.credit(self, b as Ship)
			building_changed.emit(b)

	if player.suck_cooldown > 0:
		player.suck_cooldown -= 1
	if player.hammer_cooldown > 0:
		player.hammer_cooldown -= 1
	if _too_hard_cooldown > 0:
		_too_hard_cooldown -= 1

	HelperSystem._tick_helpers(self)
	DroneSystem._tick_drones(self)
	CollectibleSystem._tick_collectibles(self)
	quests.tick_move(player.pos)
	if tick_count % 10 == 0:
		quests.check(self)
	if tick_count % 20 == 5:
		milestones.check(self)
	ToolSystem._tick_suction(self)
	ToolSystem._tick_clean(self)
	ShipSystem._tick_clean_wave(self)
	ToolSystem._tick_magnet(self)
	_tick_hammer()
	NodeSystem._tick_respawns(self)
	EventSystem._tick(self)
	NetworkSystem._tick_auto(self)
	NetworkSystem._tick_couriers(self)
	if tick_count % 20 == 0:
		zones.check_unlocks(nodes)
		if dirt.is_active():
			zones.refresh(nodes)
	var done := tech.tick()
	if done != "":
		_apply_tech_effects(done)
		recompute_modifiers()
		tech_unlocked.emit(done)
	player.hammer_pressed = false
	tick_count += 1


func _apply(cmd: Dictionary) -> void:
	match str(cmd.get("type", "")):
		"place":
			BuildingSystem._cmd_place(self, cmd)
		"remove":
			BuildingSystem._cmd_remove(self, cmd)
		"deposit":
			BuildingSystem._cmd_deposit(self, cmd)
		"deliver_all":
			ShipSystem._cmd_deliver_all(self, cmd)
		"buy_upgrade":
			ShipSystem._cmd_buy_upgrade(self, cmd)
		"upgrade_ship":
			ShipSystem._cmd_upgrade_ship(self, cmd)
		"buy_skill":
			ResearchSystem._cmd_buy_skill(self, cmd)
		"buy_helper":
			HelperSystem._cmd_buy_helper(self, cmd)
		"buy_helper_upgrade":
			HelperSystem._cmd_buy_helper_upgrade(self, cmd)
		"secret":
			if str(cmd.get("id", "")) in ["disco", "fireflies"]:
				SecretSystem.progress(self, str(cmd["id"]))
		"fuse_helpers":
			HelperSystem._cmd_fuse(self, cmd)
		"remove_helper":
			HelperSystem._cmd_remove_helper(self, cmd)
		"build_point":
			NetworkSystem._cmd_build_point(self, cmd)
		"call_courier":
			NetworkSystem._cmd_call_courier(self, cmd)
		"buy_drone":
			DroneSystem._cmd_buy_drone(self, cmd)
		"remove_drone":
			DroneSystem._cmd_remove_drone(self, cmd)
		"buy_drone_upgrade":
			DroneSystem._cmd_buy_drone_upgrade(self, cmd)


# --- Weiterleitungen an die Teilsysteme (öffentliche API bleibt stabil) ------

# ShipSystem

func ship() -> Ship:
	return ShipSystem.ship(self)


func count_available(item: String) -> int:
	return ShipSystem.count_available(self, item)


func can_afford(cost: Dictionary) -> bool:
	return ShipSystem.can_afford(self, cost)


func missing_for(cost: Dictionary) -> Dictionary:
	return ShipSystem.missing(self, cost)


func ship_upgrade_level(id: String) -> int:
	return ShipSystem.upgrade_level(self, id)


# ResearchSystem

func is_building_unlocked(def_id: String) -> bool:
	return ResearchSystem.is_building_unlocked(self, def_id)


func recompute_modifiers() -> void:
	ResearchSystem.recompute_modifiers(self)


func _apply_tech_effects(id: String) -> void:
	ResearchSystem._apply_tech_effects(self, id)


# NodeSystem

## Objekte einer Zone (gecacht, wird bei jeder Objekt-Änderung neu aufgebaut).
func zone_nodes(zid: String) -> Array:
	if _zone_nodes_dirty:
		_zone_nodes_dirty = false
		_zone_nodes_cache.clear()
		for n: ResourceNode in nodes.values():
			var z := zones.zone_id_at(n.tile)
			if not _zone_nodes_cache.has(z):
				_zone_nodes_cache[z] = []
			_zone_nodes_cache[z].append(n)
	return _zone_nodes_cache.get(zid, [])


func add_object(kind: String, tile: Vector2i, amount_override: int = -1) -> ResourceNode:
	return NodeSystem.add_object(self, kind, tile, amount_override)


func add_pile(kind: String, tile: Vector2i, amount: int) -> ResourceNode:
	return NodeSystem.add_pile(self, kind, tile, amount)


func add_wreck(tile: Vector2i, loot: Dictionary, kind: String = ResourceNode.KIND_WRECK) -> ResourceNode:
	return NodeSystem.add_wreck(self, tile, loot, kind)


func add_loose(item_id: String, pos: Vector2i, tier: int = 1, count: int = 1) -> LooseItem:
	return NodeSystem.add_loose(self, item_id, pos, tier, count)


func _remove_node(n: ResourceNode) -> void:
	NodeSystem._remove_node(self, n)


func _scatter() -> Vector2i:
	return NodeSystem._scatter(self)


func _emit_too_hard(n: ResourceNode, tool: String) -> void:
	NodeSystem._emit_too_hard(self, n, tool)


# BuildingSystem

func player_tile() -> Vector2i:
	return BuildingSystem.player_tile(self)


func building_count(def_id: String) -> int:
	return BuildingSystem.building_count(self, def_id)


func next_cost(def: BuildingDef) -> Dictionary:
	return BuildingSystem.next_cost(self, def)


func in_build_range(tile: Vector2i, size: Vector2i) -> bool:
	return BuildingSystem.in_build_range(self, tile, size)


func _tile_blocked(tile: Vector2i) -> bool:
	return BuildingSystem._tile_blocked(self, tile)


func can_place_def(def: BuildingDef, tile: Vector2i, rot: int) -> bool:
	return BuildingSystem.can_place_def(self, def, tile, rot)


func place_free(def_id: String, tile: Vector2i, rot: int = 0) -> Building:
	return BuildingSystem.place_free(self, def_id, tile, rot)


func building_near(pos: Vector2i, max_dist_px: int) -> Building:
	return BuildingSystem.building_near(self, pos, max_dist_px)


# ToolSystem

func _tick_hammer() -> void:
	ToolSystem._tick_hammer(self)


func helper_work(h: Helper) -> void:
	ToolSystem.helper_work(self, h)


# HelperSystem

func next_helper_cost() -> Dictionary:
	return HelperSystem.next_helper_cost(self)


func can_buy_helper() -> String:
	return HelperSystem.can_buy_helper(self)


func _apply_helper_mods(h: Helper) -> void:
	HelperSystem._apply_helper_mods(self, h)


func add_helper(zone_tile: Vector2i, depot_tile: Vector2i, name_index: int = -1, color_index: int = -1) -> Helper:
	return HelperSystem.add_helper(self, zone_tile, depot_tile, name_index, color_index)


func can_buy_helper_upgrade(id: String) -> String:
	return HelperSystem.can_buy_helper_upgrade(self, id)


# DroneSystem

func next_drone_cost() -> Dictionary:
	return DroneSystem.next_drone_cost(self)


func can_buy_drone() -> String:
	return DroneSystem.can_buy_drone(self)


func _apply_drone_mods(d: Drone) -> void:
	DroneSystem._apply_drone_mods(self, d)


func add_drone() -> Drone:
	return DroneSystem.add_drone(self)


func can_buy_drone_upgrade(id: String) -> String:
	return DroneSystem.can_buy_drone_upgrade(self, id)


# CollectibleSystem

func spawn_collectibles() -> void:
	CollectibleSystem.spawn_collectibles(self)


func collectible_def(def_id: String) -> Dictionary:
	return CollectibleSystem.collectible_def(self, def_id)


func collectible_total() -> int:
	return CollectibleSystem.collectible_total(self)
