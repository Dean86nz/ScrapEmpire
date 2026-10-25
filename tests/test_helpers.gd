extends TestCase


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	var text := FileAccess.get_file_as_string("res://data/helpers.json")
	w.helper_cfg = JSON.parse_string(text)
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.player.pos = Vector2i(32, 32)
	return w


func _unlock(w: SimWorld) -> void:
	w.unlocked_features["helpers"] = true


func test_cost_curve() -> void:
	var w := _world()
	assert_eq(w.next_helper_cost(), {"bolts": 400, "chrome": 5})
	_unlock(w)
	w.place_free("chest", Vector2i(10, 10), 0)
	w.add_helper(Vector2i(10, 8), Vector2i(10, 10))
	assert_eq(w.next_helper_cost()["bolts"], 600)
	w.add_helper(Vector2i(10, 8), Vector2i(10, 10))
	assert_eq(w.next_helper_cost()["bolts"], 900)


func test_buy_requirements() -> void:
	var w := _world()
	var fails := []
	w.helper_failed.connect(func(r: String) -> void: fails.append(r))
	w.place_free("chest", Vector2i(10, 10), 0)
	w.queue_command({"type": "buy_helper", "zone": Vector2i(10, 8), "depot": Vector2i(10, 10)})
	w.tick()
	assert_eq(fails, ["locked"])
	_unlock(w)
	w.queue_command({"type": "buy_helper", "zone": Vector2i(10, 8), "depot": Vector2i(10, 10)})
	w.tick()
	assert_eq(fails, ["locked", "bolts"])
	w.bolts = 1000
	w.queue_command({"type": "buy_helper", "zone": Vector2i(10, 8), "depot": Vector2i(10, 10)})
	w.tick()
	assert_eq(fails, ["locked", "bolts", "chrome"])
	w.player.inventory.add("chrome", 5)
	w.queue_command({"type": "buy_helper", "zone": Vector2i(10, 8), "depot": Vector2i(5, 5)})
	w.tick()
	assert_eq(fails.back(), "no_depot")
	w.queue_command({"type": "buy_helper", "zone": Vector2i(10, 8), "depot": Vector2i(10, 10)})
	w.tick()
	assert_eq(w.helpers.size(), 1)
	assert_eq(w.bolts, 600)
	assert_eq(w.player.inventory.count_of("chrome"), 0)
	var h: Helper = w.helpers.values()[0]
	assert_eq(h.display_name(w.helper_cfg["names"]), "Bolte")


func test_max_helpers() -> void:
	var w := _world()
	_unlock(w)
	w.place_free("chest", Vector2i(10, 10), 0)
	for i in 6:
		w.add_helper(Vector2i(10, 8), Vector2i(10, 10))
	assert_eq(w.can_buy_helper(Vector2i(10, 10)), "max")


func test_helper_collects_pile_and_deposits_loop() -> void:
	var w := _world()
	_unlock(w)
	var chest: Chest = w.place_free("chest", Vector2i(10, 10), 0)
	w.add_pile("scrap_pile", Vector2i(13, 8), 10)
	w.add_pile("copper_tangle", Vector2i(8, 12), 10)
	var h := w.add_helper(Vector2i(10, 9), Vector2i(10, 10))
	for i in 20 * 60:
		w.tick()
	var total: int = chest.contents().get("scrap", 0) + chest.contents().get("copper", 0)
	assert_true(total >= 20, "Helfer hat %s in die Kiste gebracht" % str(chest.contents()))
	assert_true(h.inventory.total() < 30, "lädt regelmäßig ab")


func test_helper_hammers_toaster() -> void:
	var w := _world()
	_unlock(w)
	var chest: Chest = w.place_free("chest", Vector2i(10, 10), 0)
	w.add_object("toaster", Vector2i(13, 9))
	w.add_helper(Vector2i(10, 9), Vector2i(10, 10))
	for i in 20 * 60:
		w.tick()
	assert_eq(w.nodes.size(), 0, "Toaster zerlegt")
	assert_true(chest.contents().get("scrap", 0) >= 6, "Beute abgeliefert: %s" % str(chest.contents()))


func test_helper_ignores_objects_above_tier_and_outside_zone() -> void:
	var w := _world()
	_unlock(w)
	w.place_free("chest", Vector2i(10, 10), 0)
	var fridge := w.add_object("fridge", Vector2i(13, 9))       # T2, in Zone
	var far := w.add_pile("scrap_pile", Vector2i(30, 9), 10)    # außerhalb (20 Kacheln)
	w.add_helper(Vector2i(10, 9), Vector2i(10, 10))
	for i in 20 * 20:
		w.tick()
	assert_eq(fridge.amount, 27)
	assert_eq(far.amount, 10)


func test_upgrades_change_speed_capacity_tier() -> void:
	var w := _world()
	_unlock(w)
	w.unlocked_features["helper_tools"] = true
	w.place_free("chest", Vector2i(10, 10), 0)
	var h := w.add_helper(Vector2i(10, 9), Vector2i(10, 10))
	assert_eq(h.speed_px_per_tick, 11)
	assert_eq(h.inventory.stack_size, 10)
	assert_eq(h.hammer_tier, 1)
	w.bolts = 10000
	w.player.inventory.add("chrome", 20)
	var fails := []
	w.helper_failed.connect(func(r: String) -> void: fails.append(r))
	for id in ["helper_speed", "helper_capacity", "helper_tool"]:
		w.queue_command({"type": "buy_helper_upgrade", "id": id})
		w.tick()
	assert_eq(fails, [])
	assert_eq(h.speed_px_per_tick, 13, "224 × 1,2 / 20 = 13,4")
	assert_eq(h.inventory.stack_size, 20)
	assert_eq(h.hammer_tier, 2)
	assert_eq(w.bolts, 10000 - 300 - 300 - 1500)
	assert_eq(w.player.inventory.count_of("chrome"), 10)


func test_upgrade_requires_feature_and_max() -> void:
	var w := _world()
	w.bolts = 100000
	w.player.inventory.add("chrome", 100)
	assert_eq(w.can_buy_helper_upgrade("helper_speed"), "locked")
	_unlock(w)
	assert_eq(w.can_buy_helper_upgrade("helper_tool"), "locked", "braucht Helfer-Werkzeug II")
	for i in 3:
		w.queue_command({"type": "buy_helper_upgrade", "id": "helper_speed"})
		w.tick()
	assert_eq(w.can_buy_helper_upgrade("helper_speed"), "max")


func test_stuck_event_pauses_and_quips() -> void:
	var w := _world()
	_unlock(w)
	w.place_free("chest", Vector2i(10, 10), 0)
	w.add_pile("scrap_pile", Vector2i(13, 8), 10)
	var h := w.add_helper(Vector2i(10, 9), Vector2i(10, 10))
	h.stuck_timer = 30
	var quips := []
	w.helper_quip.connect(func(_h: Helper, key: String) -> void: quips.append(key))
	for i in 40:
		w.tick()
	assert_eq(quips.size(), 1)
	assert_true(quips[0].begins_with("HELPER_STUCK"))
	assert_true(h.tasks.wait_ticks > 0 or h.stuck_timer > 100, "Pause gesetzt und neuer Timer")


func test_save_roundtrip_with_helpers() -> void:
	var w := _world()
	_unlock(w)
	w.place_free("chest", Vector2i(10, 10), 0)
	var h := w.add_helper(Vector2i(10, 8), Vector2i(10, 10))
	h.inventory.add("scrap", 7)
	w.helper_upgrades["helper_speed"] = 2
	w.recompute_modifiers()
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_eq(int(data["version"]), 3)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.helpers.size(), 1)
	var h2: Helper = w2.helpers.values()[0]
	assert_eq(h2.zone_tile, Vector2i(10, 8))
	assert_eq(h2.depot_tile, Vector2i(10, 10))
	assert_eq(h2.inventory.count_of("scrap"), 7)
	assert_eq(int(w2.helper_upgrades["helper_speed"]), 2)
	assert_eq(h2.speed_px_per_tick, h.speed_px_per_tick)


func test_migration_v2_to_v3() -> void:
	var m := SaveMigrations.v2_to_v3({"version": 2, "bolts": 3})
	assert_eq(int(m["version"]), 3)
	assert_eq(m["helpers"], [])
