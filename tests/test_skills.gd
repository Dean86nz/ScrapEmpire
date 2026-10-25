extends TestCase


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.rare_items = {"copper": true, "plastic": true, "chrome": true, "copper_bar": true, "plastic_sheet": true, "circuit": true}
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.player.pos = Vector2i(320, 320)
	w.player.aim = Vector2.RIGHT
	return w


func _buy(w: SimWorld, id: String) -> void:
	w.queue_command({"type": "buy_skill", "id": id})
	w.tick()


func test_defs() -> void:
	var w := _world()
	assert_eq(w.skills.defs.size(), 13)
	assert_eq(w.skills.branches.size(), 4)
	assert_eq(w.skills.total_levels(), 48)


func test_buy_needs_points_and_requirements() -> void:
	var w := _world()
	var fails := []
	w.skill_failed.connect(func(r: String) -> void: fails.append(r))
	_buy(w, "fast_wheels")
	assert_eq(fails, ["points"])
	w.progression.skill_points = 3
	_buy(w, "boost")
	assert_eq(fails, ["points", "requires"], "Boost braucht Flinke Räder 2")
	_buy(w, "fast_wheels")
	_buy(w, "fast_wheels")
	_buy(w, "boost")
	assert_eq(w.progression.skill_points, 0)
	assert_eq(w.skills.level_of("boost"), 1)
	assert_true(absf(float(w.mods["speed_mult"]) - 1.16) < 0.001)
	assert_eq(float(w.mods["boost_cooldown"]), 8.0)


func test_max_level() -> void:
	var w := _world()
	w.progression.skill_points = 10
	var fails := []
	w.skill_failed.connect(func(r: String) -> void: fails.append(r))
	for i in 6:
		_buy(w, "haggle")
	assert_eq(w.skills.level_of("haggle"), 5)
	assert_eq(fails, ["max"])
	assert_true(absf(float(w.mods["sell_mult"]) - 1.25) < 0.001)


func test_no_dead_ends_all_skills_reachable() -> void:
	var w := _world()
	w.progression.skill_points = 100
	# Kaufe stur in Dateireihenfolge, bis nichts mehr geht: am Ende muss alles voll sein.
	var progress := true
	while progress:
		progress = false
		for d: Dictionary in w.skills.defs:
			var id := str(d["id"])
			if w.skills.can_buy(id, w.progression.skill_points) == "":
				_buy(w, id)
				progress = true
	for d: Dictionary in w.skills.defs:
		var id := str(d["id"])
		assert_eq(w.skills.level_of(id), int(d["max_level"]), "Skill nicht voll: " + id)
	assert_eq(w.progression.skill_points, 100 - 48)


func test_tool_tiers_from_skills() -> void:
	var w := _world()
	w.progression.skill_points = 5
	_buy(w, "smash")
	_buy(w, "suction_power")
	_buy(w, "suction_power")
	assert_eq(w.player.hammer_tier, 2)
	assert_eq(w.player.suction_tier, 3)
	var cart := w.add_object("cart", Vector2i(6, 5))
	w.player.suck_held = true
	w.tick()
	assert_eq(cart.amount, 19, "Tier-2-Objekt jetzt saugbar")


func test_pockets_and_stacker_resize_inventory() -> void:
	var w := _world()
	w.progression.skill_points = 10
	w.player.inventory.add("scrap", 20)
	_buy(w, "pockets")
	_buy(w, "pockets")
	assert_eq(w.player.inventory.slot_count, 8)
	_buy(w, "stacker")
	assert_eq(w.player.inventory.stack_size, 25)
	assert_eq(w.player.inventory.count_of("scrap"), 20, "Inhalt bleibt")
	assert_eq(w.player.inventory.add("scrap", 5), 0, "Stack wächst auf 25")
	assert_eq(w.player.inventory.slots[0]["count"], 25)


func test_magnet_collects_loose_items_without_aim() -> void:
	var w := _world()
	w.progression.skill_points = 10
	for id in ["pockets", "pockets", "stacker", "stacker", "magnet"]:
		_buy(w, id)
	assert_eq(w.player.magnet_radius_px, 64)
	w.add_loose("copper", w.player.pos + Vector2i(-40, 0))  # hinter Rusty
	w.add_loose("copper", w.player.pos + Vector2i(-200, 0))  # außerhalb
	w.tick()
	assert_eq(w.player.inventory.count_of("copper"), 1)
	assert_eq(w.loose.size(), 1)


func test_trade_skills_change_sale_value() -> void:
	var w := _world()
	w.progression.skill_points = 10
	for i in 2:
		_buy(w, "haggle")
	assert_eq(w.sale_value("scrap", 1), 1, "1 × 1,10 → 1")
	assert_eq(w.sale_value("copper_bar", 1), 11, "10 × 1,10")
	_buy(w, "connoisseur")
	assert_eq(w.sale_value("copper_bar", 1), 12, "10 × 1,10 × 1,10 = 12,1")
	assert_eq(w.sale_value("iron_bar", 1), 7, "nicht selten: 6 × 1,10 = 6,6 → 7")
	_buy(w, "connoisseur")
	_buy(w, "wholesale")
	assert_eq(w.sale_value("copper_bar", 25), 14, "10 × 1,10 × 1,20 × 1,05 = 13,86")


func test_tempo_and_reach() -> void:
	var w := _world()
	w.progression.skill_points = 10
	_buy(w, "smash")
	_buy(w, "tempo")
	_buy(w, "tempo")
	assert_eq(w.player.suck_interval, 4, "5 / 1,30 = 3,8 → 4")
	assert_eq(w.player.hammer_interval, 8, "10 / 1,30 = 7,7 → 8")
	_buy(w, "suction_power")
	_buy(w, "reach")
	_buy(w, "reach")
	assert_eq(w.player.suck_range_px, 224, "160 + 1 Kachel")
