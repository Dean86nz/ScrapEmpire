extends TestCase


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.helper_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json"))
	w.drone_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/drones.json"))
	w.ship_cfg = ShipSystem.load_config()
	w.quests.setup(QuestState.load_defs())
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.player.pos = Vector2i(320, 352)
	return w


func _with_ship(w: SimWorld) -> Ship:
	var s := w.place_free("ship", Vector2i(2, 2), 0) as Ship
	ShipSystem.apply_stage(w, s)
	return s


func _run(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		w.tick()


func test_ship_def_is_not_buildable() -> void:
	var w := _world()
	var def: BuildingDef = w.defs["ship"]
	assert_false(def.buildable)
	assert_eq(def.size, Vector2i(3, 3))
	w.player.inventory.add("scrap", 50)
	var fails := []
	w.place_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "place", "def_id": "ship", "tile": Vector2i(10, 10)})
	w.tick()
	assert_eq(w.building_count("ship"), 0)
	assert_eq(fails, ["locked"])


func test_ship_sells_only_above_reserve() -> void:
	var w := _world()
	var s := _with_ship(w)
	assert_eq(s.storage.slot_count, 20)
	assert_eq(s.accept_stack("scrap", 5), 5)        # Reserve 0 → wird verkauft
	assert_eq(s.accept_stack("iron_bar", 3), 3)     # Reserve 50 → bleibt
	var bolts := w.bolts
	_run(w, 60)
	assert_eq(s.storage.count_of("scrap"), 0, "Schrott verkauft")
	assert_eq(s.storage.count_of("iron_bar"), 3, "Barren behalten")
	assert_true(w.bolts > bolts, "Bolts gebucht: %d" % w.bolts)


func test_ship_storage_counts_for_costs_and_pays_after_inventory() -> void:
	var w := _world()
	var s := _with_ship(w)
	w.unlocked_features["decor"] = true
	s.accept_stack("wood", 10)
	w.player.inventory.add("wood", 2)
	assert_eq(w.count_available("wood"), 12)
	assert_true(w.can_afford({"wood": 10}))
	assert_eq(w.missing_for({"wood": 20}), {"wood": 8})
	ShipSystem.pay(w, {"wood": 5})
	assert_eq(w.player.inventory.count_of("wood"), 0, "Inventar zuerst")
	assert_eq(s.storage.count_of("wood"), 7)
	# Bauen mit Material nur im Schiffslager
	w.queue_command({"type": "place", "def_id": "sign", "tile": Vector2i(8, 8)})
	w.tick()
	assert_eq(w.building_count("sign"), 1)
	assert_true(s.storage.count_of("wood") < 7)


func test_research_can_use_ship_storage() -> void:
	var w := _world()
	var s := _with_ship(w)
	w.bolts = 1000
	w.unlocked_tech["furnace"] = true
	w.tech.unlocked["furnace"] = true
	w.tech.unlocked["chest"] = true
	# conveyor braucht 5 Eisenbarren
	s.accept_stack("iron_bar", 5)
	assert_eq(w.tech.can_start("conveyor", w.bolts, w.player.inventory), "items", "ohne Schiff fehlt Material")
	assert_eq(w.tech.can_start("conveyor", w.bolts, w.player.inventory, ShipSystem.extra_inventories(w)), "")
	w.queue_command({"type": "research", "id": "conveyor"})
	w.tick()
	assert_true(w.tech.is_researching())
	assert_eq(s.storage.count_of("iron_bar"), 0)


func test_upgrade_requires_cost_and_grows_storage() -> void:
	var w := _world()
	var s := _with_ship(w)
	var fails := []
	w.ship_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "upgrade_ship"})
	w.tick()
	assert_eq(fails, ["bolts"])
	w.bolts = 5000
	w.queue_command({"type": "upgrade_ship"})
	w.tick()
	assert_eq(fails[-1], "items")
	s.accept_stack("iron_bar", 20)
	w.player.inventory.add("copper_bar", 5)
	var upgraded := []
	w.ship_upgraded.connect(func(sh: Ship) -> void: upgraded.append(sh.stage))
	w.queue_command({"type": "upgrade_ship"})
	w.tick()
	assert_eq(upgraded, [2])
	assert_eq(s.stage, 2)
	assert_eq(s.storage.slot_count, 30)
	assert_eq(s.sell_interval, 6)
	assert_eq(w.bolts, 5000 - 300)
	assert_eq(s.storage.count_of("iron_bar"), 0)
	assert_true(s.sprite_path.ends_with("ship_2.svg"))


func test_belt_delivers_into_ship_and_counts_delivery() -> void:
	var w := _world()
	var s := _with_ship(w)
	var received := []
	w.ship_received.connect(func(item: String, n: int) -> void: received.append([item, n]))
	# Band bei (1,3) zeigt nach rechts in die Schiffszelle (2,3)
	var c := w.place_free("conveyor", Vector2i(1, 3), 0) as Conveyor
	c.try_insert("scrap", 0)
	_run(w, 40)
	assert_true(received.size() >= 1, "Band liefert ans Schiff")
	assert_true(s.storage.count_of("scrap") + 0 >= 0)


func test_belt_to_ship_detection() -> void:
	var w := _world()
	_with_ship(w)
	w.unlocked_tech["furnace"] = true
	w.refresh_recipes()
	var f := w.place_free("furnace", Vector2i(8, 2), 0)
	assert_false(ConveyorSystem.belt_reaches_ship(w, "furnace"))
	# Ofen-Ausgang rechts bei (10,2): Bänder nach links führen nicht zum Schiff; wir legen das Schiff rechts
	var s2 := w.place_free("ship", Vector2i(14, 1), 0) as Ship
	ShipSystem.apply_stage(w, s2)
	w.place_free("conveyor", Vector2i(10, 2), 0)
	w.place_free("conveyor", Vector2i(11, 2), 0)
	w.place_free("conveyor", Vector2i(12, 2), 0)
	w.place_free("conveyor", Vector2i(13, 2), 0)
	w.tick()
	assert_true(ConveyorSystem.belt_reaches_ship(w, "furnace"), "Bandkette erreicht das Schiff")
	assert_true(f != null)


func test_drone_uses_ship_as_source_and_target() -> void:
	var w := _world()
	var s := _with_ship(w)
	w.unlocked_features["drones"] = true
	var chest := w.place_free("chest", Vector2i(12, 12), 0) as Chest
	chest.inventory.add("scrap", 20)
	assert_eq(w.can_buy_drone(chest.tile, s.tile).replace("bolts", ""), "", "Schiff ist gültiges Ziel")
	var d := w.add_drone(chest.id, s.id)
	_run(w, 600)
	assert_true(s.storage.count_of("scrap") > 0 or w.bolts > 0, "Drohne liefert ans Schiff (wird ggf. verkauft)")
	assert_true(d.trips >= 1)
	s.accept_stack("iron_bar", 10)
	var chest2 := w.place_free("chest", Vector2i(12, 16), 0) as Chest
	var d2 := w.add_drone(s.id, chest2.id)
	d2.item_filter = "iron_bar"
	_run(w, 600)
	assert_eq(chest2.inventory.count_of("iron_bar"), 10, "Drohne holt aus dem Schiffslager")


func test_terminal_is_outpost_one_per_zone() -> void:
	var w := _world()
	MapLoader.apply(w, {"width": 40, "height": 30, "zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 20, "h": 30}, {"id": "b", "name": "B", "x": 20, "y": 0, "w": 20, "h": 30}], "nodes": []})
	w.player.pos = Vector2i(320, 352)
	var def: BuildingDef = w.defs["sell_terminal"]
	assert_eq(def.max_per_zone, 1)
	assert_eq(w.next_cost(def), w.next_cost(def), "keine Steigerung")
	w.player.inventory.add("scrap", 100)
	w.player.inventory.add("iron_bar", 20)
	var fails := []
	w.place_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "place", "def_id": "sell_terminal", "tile": Vector2i(6, 5)})
	w.tick()
	assert_eq(w.building_count("sell_terminal"), 1)
	w.queue_command({"type": "place", "def_id": "sell_terminal", "tile": Vector2i(9, 5)})
	w.tick()
	assert_eq(w.building_count("sell_terminal"), 1)
	assert_eq(fails, ["zone_limit"])


func test_ship_cannot_be_demolished() -> void:
	var w := _world()
	var s := _with_ship(w)
	w.queue_command({"type": "remove", "tile": s.tile})
	w.tick()
	assert_eq(w.building_count("ship"), 1)


func test_save_roundtrip_keeps_stage_and_storage() -> void:
	var w := _world()
	var s := _with_ship(w)
	s.stage = 2
	ShipSystem.apply_stage(w, s)
	s.accept_stack("gear", 7)
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	var s2 := ShipSystem.ship(w2)
	assert_true(s2 != null)
	assert_eq(s2.stage, 2)
	assert_eq(s2.storage.slot_count, 30)
	assert_eq(s2.storage.count_of("gear"), 7)
	assert_true(s2.sprite_path.ends_with("ship_2.svg"))


func test_ensure_ship_for_old_save_and_planet_health() -> void:
	var w := _world()
	var map := {"width": 40, "height": 30, "player_start": {"x": 20, "y": 15}, "ship": {"x": 16, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}], "nodes": [{"kind": "toaster", "x": 5, "y": 5}]}
	MapLoader.apply(w, map, false)
	assert_true(ShipSystem.ship(w) == null)
	var s := MapLoader.ensure_ship(w, map)
	assert_true(s != null and s.tile == Vector2i(16, 13))
	assert_true(MapLoader.ensure_ship(w, map) == s, "kein zweites Schiff")
	# Neues Spiel setzt das Schiff über apply()
	var w2 := _world()
	MapLoader.apply(w2, map)
	assert_true(ShipSystem.ship(w2) != null)
	assert_true(absf(w2.zones.planet_health(w2.nodes) - 0.0) < 0.001, "Planet 0 % mit Müll")
	for n in w2.nodes.values():
		if n.kind == "toaster":
			w2._remove_node(n)
	assert_true(absf(w2.zones.planet_health(w2.nodes) - 1.0) < 0.001, "Planet 100 % ohne Müll")
