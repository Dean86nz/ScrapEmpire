extends TestCase

const SPEED_PX := 13  # 256 px/s bei 20 Ticks


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.player.pos = Vector2i(320, 320)
	return w


## Simuliert den Player-Node: bewegt den Körper pro Tick auf das Ziel zu.
func _run(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		if w.player.has_move_target():
			var d := Vector2(w.player.move_target - w.player.pos)
			if d.length() <= SPEED_PX:
				w.player.pos = w.player.move_target
			else:
				w.player.pos += Vector2i((d.normalized() * SPEED_PX).round())
		w.tick()


func test_add_remove_move_limits() -> void:
	var t := TaskList.new()
	for i in 12:
		assert_true(t.add_step(TaskList.Type.GOTO, Vector2i(i, 0)))
	assert_false(t.add_step(TaskList.Type.GOTO, Vector2i(99, 0)), "max 12")
	t.move_step(0, 1)
	assert_eq(t.steps[1]["tile"], Vector2i(0, 0))
	t.remove_step(0)
	assert_eq(t.steps.size(), 11)
	assert_eq(t.steps[0]["tile"], Vector2i(0, 0))


func test_goto_reaches_and_loops() -> void:
	var w := _world()
	w.tasks.add_step(TaskList.Type.GOTO, Vector2i(10, 5))   # (672, 352)
	w.tasks.add_step(TaskList.Type.GOTO, Vector2i(5, 5))    # zurück
	var starts := []
	w.tasks.step_started.connect(func(i: int) -> void: starts.append(i))
	assert_true(w.tasks.start(w.player))
	_run(w, 40)
	assert_true(Vector2(w.player.pos - Vector2i(672, 352)).length() < 30 or starts.size() >= 2)
	_run(w, 80)
	assert_true(starts.size() >= 3, "Schleife: 0, 1, 0 … hat %d" % starts.size())


func test_collect_fills_inventory_from_pile() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(10, 5), 10)
	w.tasks.add_step(TaskList.Type.COLLECT, Vector2i(10, 5))
	w.tasks.add_step(TaskList.Type.GOTO, Vector2i(5, 5))
	w.tasks.start(w.player)
	_run(w, 200)
	assert_true(w.player.inventory.count_of("scrap") >= 8, "hat %d Schrott" % w.player.inventory.count_of("scrap"))


func test_collect_then_deposit_into_chest() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(10, 5), 10)
	var chest: Chest = w.place_free("chest", Vector2i(5, 8), 0)
	w.tasks.add_step(TaskList.Type.COLLECT, Vector2i(10, 5))
	w.tasks.add_step(TaskList.Type.DEPOSIT, Vector2i(5, 8))
	w.tasks.start(w.player)
	_run(w, 600)
	assert_true(chest.contents().get("scrap", 0) >= 10, "Kiste hat %s" % str(chest.contents()))
	assert_true(w.tasks.active, "läuft weiter in der Schleife")


func test_hammer_toaster_and_pick_up_loot() -> void:
	var w := _world()
	w.add_object("toaster", Vector2i(10, 5))
	w.tasks.add_step(TaskList.Type.HAMMER, Vector2i(10, 5))
	w.tasks.add_step(TaskList.Type.GOTO, Vector2i(5, 5))
	w.tasks.start(w.player)
	_run(w, 700)
	assert_eq(w.nodes.size(), 0, "Toaster zerlegt")
	assert_true(w.player.inventory.total() >= 8, "lose Items eingesammelt: %d" % w.player.inventory.total())


func test_too_hard_waits_and_reports() -> void:
	var w := _world()
	w.add_object("fridge", Vector2i(10, 5))
	w.tasks.add_step(TaskList.Type.HAMMER, Vector2i(10, 5))
	var reasons := []
	w.tasks.waiting.connect(func(r: String) -> void: reasons.append(r))
	w.tasks.start(w.player)
	_run(w, 60)
	assert_eq(reasons, ["too_hard"])
	assert_true(w.tasks.wait_ticks > 0)


func test_interrupt_stops_and_releases() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(10, 5), 10)
	w.tasks.add_step(TaskList.Type.COLLECT, Vector2i(10, 5))
	w.tasks.start(w.player)
	_run(w, 30)
	assert_true(w.player.has_move_target() or w.player.suck_held)
	w.tasks.interrupt(w.player)
	assert_false(w.tasks.active)
	assert_false(w.player.has_move_target())
	assert_false(w.player.suck_held)


func test_withdraw_from_chest() -> void:
	var w := _world()
	var chest: Chest = w.place_free("chest", Vector2i(6, 5), 0)
	chest.accept_stack("copper", 15)
	w.tasks.add_step(TaskList.Type.WITHDRAW, Vector2i(6, 5))
	w.tasks.add_step(TaskList.Type.GOTO, Vector2i(5, 5))
	w.tasks.start(w.player)
	_run(w, 60)
	assert_eq(w.player.inventory.count_of("copper"), 15)
	assert_eq(chest.contents(), {})


func test_save_roundtrip_keeps_tasks() -> void:
	var w := _world()
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.tasks.add_step(TaskList.Type.COLLECT, Vector2i(3, 4), "scrap")
	w.tasks.add_step(TaskList.Type.DEPOSIT, Vector2i(7, 8))
	w.tasks.active = true
	w.tasks.index = 1
	w.flags["tutorial_done"] = true
	w.flags["gate_open"] = true
	var data := SaveCodec.encode(w, "main", Vector2(320, 320), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	var w2 := _world()
	w2.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.tasks.steps.size(), 2)
	assert_eq(w2.tasks.steps[0]["item"], "scrap")
	assert_eq(w2.tasks.steps[1]["tile"], Vector2i(7, 8))
	assert_eq(w2.tasks.index, 1)
	assert_true(w2.tasks.active)
	assert_true(bool(w2.flags["gate_open"]))
	assert_true(bool(w2.flags["tutorial_done"]))


func test_migration_v1_to_v2_shifts_tutorial_map() -> void:
	var old := {
		"version": 1, "map": "tutorial",
		"player": {"pos": [1312.0, 992.0]},
		"nodes": [{"kind": "toaster", "tile": [17, 17], "amount": 5}],
		"loose": [{"item": "scrap", "pos": [100, 100], "tier": 1}],
		"buildings": [{"def": "chest", "tile": [12, 8], "rot": 0}],
		"respawns": [{"kind": "fridge", "tile": [7, 15], "ticks_left": 10}],
	}
	var m := SaveMigrations.v1_to_v2(old)
	assert_eq(int(m["version"]), 2)
	assert_eq(str(m["map"]), "main")
	assert_eq(m["nodes"][0]["tile"], [17, 47])
	assert_eq(m["buildings"][0]["tile"], [12, 38])
	assert_eq(m["respawns"][0]["tile"], [7, 45])
	assert_eq(m["loose"][0]["pos"], [100, 2020])
	assert_eq(m["player"]["pos"], [1312.0, 2912.0])
	assert_true(bool(m["tutorial"]["done"]))
	assert_true(bool(m["flags"]["gate_open"]))
