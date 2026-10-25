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
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.player.pos = Vector2i(32, 32)
	return w


func _unlock(w: SimWorld) -> void:
	w.unlocked_features["drones"] = true
	w.unlocked_tech["furnace"] = true
	w.refresh_recipes()


func _run(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		w.tick()


func test_buy_requires_feature_and_buildings() -> void:
	var w := _world()
	var fails := []
	w.drone_failed.connect(func(r: String) -> void: fails.append(r))
	var chest := w.place_free("chest", Vector2i(5, 5), 0)
	var furnace := w.place_free("furnace", Vector2i(15, 5), 0)
	w.queue_command({"type": "buy_drone", "source": chest.tile, "target": furnace.tile})
	w.tick()
	assert_eq(fails, ["locked"])
	_unlock(w)
	w.queue_command({"type": "buy_drone", "source": chest.tile, "target": furnace.tile})
	w.tick()
	assert_eq(fails, ["locked", "bolts"])
	w.bolts = 5000
	w.player.inventory.add("circuit", 3)
	w.queue_command({"type": "buy_drone", "source": Vector2i(20, 20), "target": furnace.tile})
	w.tick()
	assert_eq(fails[-1], "no_source")
	w.queue_command({"type": "buy_drone", "source": chest.tile, "target": chest.tile})
	w.tick()
	assert_eq(fails[-1], "same")
	w.queue_command({"type": "buy_drone", "source": chest.tile, "target": furnace.tile})
	w.tick()
	assert_eq(w.drones.size(), 1)
	assert_eq(w.bolts, 5000 - 600)
	assert_eq(w.player.inventory.count_of("circuit"), 0)


func test_cost_curve() -> void:
	var w := _world()
	assert_eq(w.next_drone_cost(), {"bolts": 600, "circuit": 3})
	_unlock(w)
	var chest := w.place_free("chest", Vector2i(5, 5), 0)
	var furnace := w.place_free("furnace", Vector2i(15, 5), 0)
	w.add_drone(chest.id, furnace.id)
	assert_eq(w.next_drone_cost()["bolts"], 840)


func test_drone_moves_scrap_from_chest_to_furnace() -> void:
	var w := _world()
	_unlock(w)
	var chest := w.place_free("chest", Vector2i(5, 5), 0) as Chest
	var furnace := w.place_free("furnace", Vector2i(15, 5), 0) as Machine
	chest.inventory.add("scrap", 30)
	var d := w.add_drone(chest.id, furnace.id)
	assert_eq(d.capacity, 10)
	_run(w, 400)
	# Ofen hat Schrott bekommen und schmilzt; Kiste wurde geleert
	var total_in_furnace := int(furnace.input.get("scrap", 0)) + int(furnace.output.get("iron_bar", 0)) * 3
	assert_true(chest.inventory.count_of("scrap") < 30, "Kiste geleert: %d" % chest.inventory.count_of("scrap"))
	assert_true(total_in_furnace > 0 or furnace.progress_ticks > 0, "Ofen hat Material")
	assert_true(d.trips >= 1, "mindestens eine Fahrt: %d" % d.trips)


func test_filter_only_moves_matching_item() -> void:
	var w := _world()
	_unlock(w)
	var a := w.place_free("chest", Vector2i(5, 5), 0) as Chest
	var b := w.place_free("chest", Vector2i(12, 5), 0) as Chest
	a.inventory.add("scrap", 20)
	a.inventory.add("copper", 20)
	var d := w.add_drone(a.id, b.id)
	w.queue_command({"type": "set_drone_filter", "id": d.id, "item": "copper"})
	_run(w, 600)
	assert_eq(a.inventory.count_of("scrap"), 20)
	assert_eq(a.inventory.count_of("copper"), 0)
	assert_eq(b.inventory.count_of("copper"), 20)


func test_limit_stops_at_target_amount() -> void:
	var w := _world()
	_unlock(w)
	var a := w.place_free("chest", Vector2i(5, 5), 0) as Chest
	var b := w.place_free("chest", Vector2i(12, 5), 0) as Chest
	a.inventory.add("scrap", 60)
	var d := w.add_drone(a.id, b.id)
	w.queue_command({"type": "set_drone_limit", "id": d.id, "limit": 25})
	_run(w, 900)
	assert_eq(b.inventory.count_of("scrap"), 25)
	assert_true(d.state == Drone.State.WAIT and d.wait_reason == "limit", "wartet wegen Limit: %s" % d.wait_reason)


func test_empty_source_waits_without_crash() -> void:
	var w := _world()
	_unlock(w)
	var a := w.place_free("chest", Vector2i(5, 5), 0) as Chest
	var b := w.place_free("chest", Vector2i(12, 5), 0) as Chest
	var d := w.add_drone(a.id, b.id)
	_run(w, 200)
	assert_eq(d.wait_reason, "source_empty")
	assert_eq(d.trips, 0)
	# Quelle wird gefüllt: Drohne nimmt die Arbeit auf
	a.inventory.add("scrap", 5)
	_run(w, 300)
	assert_eq(b.inventory.count_of("scrap"), 5)


func test_removed_building_puts_drone_on_hold() -> void:
	var w := _world()
	_unlock(w)
	var a := w.place_free("chest", Vector2i(5, 5), 0) as Chest
	var b := w.place_free("chest", Vector2i(12, 5), 0) as Chest
	var d := w.add_drone(a.id, b.id)
	w.queue_command({"type": "remove", "tile": b.tile})
	w.tick()
	_run(w, 20)
	assert_eq(d.wait_reason, "missing")


func test_upgrade_capacity_and_speed() -> void:
	var w := _world()
	_unlock(w)
	var a := w.place_free("chest", Vector2i(5, 5), 0)
	var b := w.place_free("chest", Vector2i(12, 5), 0)
	var d := w.add_drone(a.id, b.id)
	var base_speed := d.speed_px_per_tick
	w.bolts = 10000
	w.player.inventory.add("circuit", 20)
	w.queue_command({"type": "buy_drone_upgrade", "id": "drone_capacity"})
	w.queue_command({"type": "buy_drone_upgrade", "id": "drone_speed"})
	w.tick()
	assert_eq(int(w.drone_upgrades.get("drone_capacity", 0)), 1)
	assert_eq(d.capacity, 20)
	assert_true(d.speed_px_per_tick > base_speed, "schneller: %d > %d" % [d.speed_px_per_tick, base_speed])


func test_save_roundtrip_and_migration() -> void:
	var w := _world()
	_unlock(w)
	var a := w.place_free("chest", Vector2i(5, 5), 0) as Chest
	var b := w.place_free("chest", Vector2i(12, 5), 0)
	a.inventory.add("scrap", 20)
	var d := w.add_drone(a.id, b.id)
	d.item_filter = "scrap"
	d.limit = 50
	_run(w, 50)
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	assert_eq(data["drones"].size(), 1)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.drones.size(), 1)
	var d2: Drone = w2.drones.values()[0]
	assert_eq(d2.item_filter, "scrap")
	assert_eq(d2.limit, 50)
	assert_true(w2.buildings.has(d2.source_id) and w2.buildings.has(d2.target_id), "Gebäude-IDs bleiben gültig")
	var migrated := SaveMigrations.v4_to_v5({"version": 4})
	assert_eq(int(migrated["version"]), 5)
	assert_eq(migrated["drones"], [])
