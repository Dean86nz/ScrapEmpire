extends TestCase


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.player.pos = Vector2i(320, 320)
	w.player.aim = Vector2.RIGHT
	return w


## Startet eine Forschung; give=true legt die benötigten Produkte (nicht Chrom) vorher ins Inventar.
func _research(w: SimWorld, id: String, give: bool = true) -> void:
	if give and w.tech.by_id.has(id):
		for item in w.tech.by_id[id].get("cost_items", {}):
			if str(item) != "chrome":
				w.player.inventory.add(str(item), int(w.tech.by_id[id]["cost_items"][item]))
	w.queue_command({"type": "research", "id": id})
	w.tick()


func test_defs_and_initial_state() -> void:
	var w := _world()
	assert_eq(w.tech.defs.size(), 17)
	assert_true(w.tech.is_unlocked("terminal"), "Gratis-Knoten ist frei")
	assert_true(w.is_building_unlocked("sell_terminal"))
	assert_false(w.is_building_unlocked("furnace"), "Ofen braucht Forschung")
	assert_eq(w.tech.available(), ["furnace", "suction_plus", "hammer_plus"] as Array[String])


func test_locked_building_cannot_be_placed() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 100)
	w.player.inventory.add("copper", 20)
	var reasons := []
	w.place_failed.connect(func(r: String) -> void: reasons.append(r))
	w.queue_command({"type": "place", "def_id": "furnace", "tile": Vector2i(7, 5)})
	w.tick()
	assert_eq(reasons, ["locked"])


func test_research_needs_bolts_and_requirements() -> void:
	var w := _world()
	var fails := []
	w.research_failed.connect(func(r: String) -> void: fails.append(r))
	_research(w, "furnace")
	assert_eq(fails, ["bolts"])
	w.bolts = 1000
	_research(w, "press")
	assert_eq(fails, ["bolts", "requires"])


func test_research_pays_and_completes_after_time() -> void:
	var w := _world()
	w.bolts = 100
	var unlocked := []
	w.tech_unlocked.connect(func(id: String) -> void: unlocked.append(id))
	_research(w, "furnace")
	assert_eq(w.bolts, 50)
	assert_true(w.tech.is_researching())
	assert_eq(w.progression.total_xp, 5, "Tech-XP = Kosten / 10")
	for i in 198:
		w.tick()
	assert_eq(unlocked, [])
	w.tick()
	assert_eq(unlocked, ["furnace"], "10 s = 200 Ticks")
	assert_true(w.is_building_unlocked("furnace"))
	assert_false(w.tech.is_researching())


func test_only_one_research_at_a_time() -> void:
	var w := _world()
	w.bolts = 1000
	var fails := []
	w.research_failed.connect(func(r: String) -> void: fails.append(r))
	_research(w, "furnace")
	_research(w, "suction_plus")
	assert_eq(fails, ["busy"])


func test_recipe_tech_unlocks_recipe_in_existing_press() -> void:
	var w := _world()
	w.bolts = 5000
	for id in ["furnace", "press"]:
		_research(w, id)
		for i in 400:
			w.tick()
	w.player.inventory.add("iron_bar", 5)
	w.player.inventory.add("plastic", 20)
	w.queue_command({"type": "place", "def_id": "press", "tile": Vector2i(7, 5)})
	w.tick()
	var p: Machine = w.buildings.values()[0]
	assert_false(p.accepts_item("iron_bar"))
	_research(w, "gear")
	for i in 1001:
		w.tick()
	assert_true(w.tech.is_unlocked("gear"))
	assert_true(p.accepts_item("iron_bar"), "Rezeptliste der Presse wurde erneuert")


func test_chrome_cost() -> void:
	var w := _world()
	w.bolts = 100000
	for id in ["furnace", "chest", "press", "suction_plus", "gear", "backpack", "circuit"]:
		_research(w, id)
		for i in 3000:
			w.tick()
	var fails := []
	w.research_failed.connect(func(r: String) -> void: fails.append(r))
	w.player.inventory.add("circuit", 5)
	_research(w, "autopilot", false)
	assert_eq(fails, ["items"], "10 Chrom fehlen")
	w.player.inventory.add("chrome", 10)
	_research(w, "autopilot", false)
	assert_eq(w.player.inventory.count_of("chrome"), 0)
	assert_true(w.tech.is_researching())


func test_modifier_tech_applies() -> void:
	var w := _world()
	w.bolts = 1000
	_research(w, "hammer_plus")
	for i in 801:
		w.tick()
	assert_eq(w.player.hammer_items, 2)
	assert_eq(int(w.mods["hammer_items"]), 2)


func test_backpack_adds_slots() -> void:
	var w := _world()
	w.bolts = 5000
	var resized := [0]
	w.inventory_resized.connect(func() -> void: resized[0] += 1)
	for id in ["furnace", "chest", "backpack"]:
		_research(w, id)
		for i in 1601:
			w.tick()
	assert_eq(w.player.inventory.slot_count, 10)
	assert_eq(resized[0], 1)


func test_terminal_plus_speeds_selling() -> void:
	var w := _world()
	w.bolts = 5000
	w.player.inventory.add("scrap", 100)
	w.queue_command({"type": "place", "def_id": "sell_terminal", "tile": Vector2i(7, 5)})
	w.tick()
	for id in ["furnace", "conveyor", "terminal_plus"]:
		_research(w, id)
		for i in 3001:
			w.tick()
	var t: SellTerminal = w.buildings.values()[0]
	assert_eq(t.sell_interval, 4)
