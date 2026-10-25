extends TestCase


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.helper_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json"))
	w.drone_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/drones.json"))
	w.ship_cfg = ShipSystem.load_config()
	w.quests.setup(QuestState.load_defs())
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	MapLoader.apply(w, {"width": 40, "height": 30, "player_start": {"x": 20, "y": 15}, "ship": {"x": 16, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}], "zone_order": ["a"], "unlock_cleanliness": 0.5,
		"nodes": [{"kind": "scrap_pile", "x": 20, "y": 10, "amount": 10}, {"kind": "toaster", "x": 24, "y": 12}]})
	w.player.pos = Vector2i(20 * 64 + 32, 15 * 64 + 32)
	return w


func _run(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		w.tick()


func _ids(w: SimWorld) -> Array:
	var out := []
	for q in w.quests.defs:
		out.append(str(q["id"]))
	return out


func test_quest_defs_load_in_order() -> void:
	var w := _world()
	assert_eq(w.quests.total(), 24)
	assert_eq(str(w.quests.current()["id"]), "q_move")
	assert_eq(_ids(w)[-1], "q_planet")


func test_move_collect_deliver_bolts_chain() -> void:
	var w := _world()
	var done := []
	w.quest_completed.connect(func(id: String, _d: Dictionary) -> void: done.append(id))
	# Bewegen: 200 px in kleinen Schritten
	for i in 30:
		w.player.pos += Vector2i(8, 0)
		w.tick()
	_run(w, 10)
	assert_eq(done, ["q_move"])
	assert_eq(w.quests.progress(w), [0, 30])
	# Sammeln: 30 Schrott über das Signal
	for i in 30:
		w.item_collected.emit("scrap", w.player.pos)
	_run(w, 10)
	assert_eq(done.back(), "q_collect")
	# Abliefern: 20 Schrott ins Schiff einlegen
	var s := ShipSystem.ship(w)
	w.player.inventory.add("scrap", 20)
	w.player.pos = s.center_px() + Vector2i(0, 120)
	w.queue_command({"type": "deposit", "tile": s.tile, "slot": 0})
	_run(w, 10)
	assert_eq(done.back(), "q_deliver", "Abliefern gezählt: %s" % str(w.quests.counters))
	assert_eq(w.bolts >= 20, true, "Bonus-Bolts")
	# Verkauf: Schiff verkauft Schrott von allein (40 Schrott → 40 Bolts)
	w.player.inventory.add("scrap", 20)
	w.queue_command({"type": "deposit", "tile": s.tile, "slot": 0})
	_run(w, 600)
	assert_true(done.has("q_bolts"), "Verkaufserlös erreicht: %s" % str(w.quests.counters))


func test_research_build_and_belt_conditions() -> void:
	var w := _world()
	w.quests.index = _ids(w).find("q_research_furnace")
	assert_false(w.quests.is_satisfied(w))
	w.unlocked_tech["furnace"] = true
	w.tech.unlocked["furnace"] = true
	w.refresh_recipes()
	_run(w, 10)
	assert_eq(str(w.quests.current()["id"]), "q_build_furnace")
	var f := w.place_free("furnace", Vector2i(10, 20), 0)
	_run(w, 10)
	assert_eq(str(w.quests.current()["id"]), "q_bars")
	ShipSystem.ship(w).accept_stack("iron_bar", 10)
	_run(w, 10)
	assert_eq(str(w.quests.current()["id"]), "q_research_conveyor")
	w.quests.index = _ids(w).find("q_belt")
	assert_false(w.quests.is_satisfied(w))
	# Bänder vom Ofen-Ausgang (12,20) zum Schiff (16..18, 13..15): nach rechts bis x=16, dann hoch
	for x in range(12, 16):
		w.place_free("conveyor", Vector2i(x, 20), 0)
	for y in range(20, 15, -1):
		w.place_free("conveyor", Vector2i(16, y), 3)  # nach oben bis in die Schiffszelle (16,15)
	assert_true(w.quests.is_satisfied(w), "Band erreicht das Schiff")
	_run(w, 10)
	assert_eq(str(w.quests.current()["id"]), "q_research_extractor", "Aufgabe abgehakt")
	assert_true(f != null)


func test_zone_gate_ship_stage_and_planet() -> void:
	var w := _world()
	w.quests.index = _ids(w).find("q_zone1")
	var p := w.quests.progress(w)
	assert_eq(p[1], 50)
	for n in w.nodes.values():
		if n.kind == "toaster":
			w._remove_node(n)
	assert_true(w.quests.is_satisfied(w), "Tor-Ziel: %s" % str(w.quests.progress(w)))
	_run(w, 10)
	assert_eq(str(w.quests.current()["id"]), "q_research_press", "Zonen-Aufgabe abgehakt")
	w.quests.index = _ids(w).find("q_ship2")
	assert_eq(w.quests.progress(w), [1, 2])
	w.quests.index = _ids(w).find("q_planet")
	assert_eq(w.quests.progress(w), [100, 100])


func test_fast_forward_old_save() -> void:
	var w := _world()
	w.flags["tutorial_done"] = true
	w.unlocked_tech["furnace"] = true
	w.tech.unlocked["furnace"] = true
	w.refresh_recipes()
	w.place_free("furnace", Vector2i(10, 20), 0)
	var skipped := w.quests.fast_forward(w, true)
	assert_eq(skipped, 7, "Tutorial-Aufgaben und gebauter Ofen übersprungen")
	assert_eq(str(w.quests.current()["id"]), "q_bars")


func test_save_roundtrip_and_migration() -> void:
	var w := _world()
	w.quests.index = 3
	w.quests.counters["sold_value"] = 12
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_eq(int(data["version"]), 7)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.quests.index, 3)
	assert_eq(int(w2.quests.counters["sold_value"]), 12)
	var m := SaveMigrations.v6_to_v7({"version": 6})
	assert_eq(int(m["version"]), 7)
	assert_eq(int(m["quests"]["index"]), 0)
