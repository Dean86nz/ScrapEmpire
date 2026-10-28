extends TestCase
## Arbeiter-Logik (TaskList) der Helfer, hier mit Rustys Körper als WorkerBody getrieben.

const SPEED_PX := 13  # 256 px/s bei 20 Ticks


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.player.pos = Vector2i(320, 320)
	return w


## Simuliert den Node: Gehirn denkt, Körper bewegt sich pro Tick auf das Ziel zu.
func _run(w: SimWorld, t: TaskList, ticks: int) -> void:
	for i in ticks:
		t.tick(w, w.player)
		if w.player.has_move_target():
			var d := Vector2(w.player.move_target - w.player.pos)
			if d.length() <= SPEED_PX:
				w.player.pos = w.player.move_target
			else:
				w.player.pos += Vector2i((d.normalized() * SPEED_PX).round())
		w.tick()


func test_add_step_limit() -> void:
	var t := TaskList.new()
	for i in 12:
		assert_true(t.add_step(TaskList.Type.GOTO, Vector2i(i, 0)))
	assert_false(t.add_step(TaskList.Type.GOTO, Vector2i(99, 0)), "max 12")
	assert_eq(t.steps.size(), 12)


func test_goto_reaches_and_loops() -> void:
	var w := _world()
	var t := TaskList.new()
	t.add_step(TaskList.Type.GOTO, Vector2i(10, 5))   # (672, 352)
	t.add_step(TaskList.Type.GOTO, Vector2i(5, 5))    # zurück
	assert_true(t.start(w.player))
	_run(w, t, 40)
	assert_true(Vector2(w.player.pos - Vector2i(672, 352)).length() < 30 or t.index >= 1)
	_run(w, t, 80)
	assert_true(t.loops >= 1, "Schleife: hat %d Runden" % t.loops)


func test_collect_fills_inventory_from_pile() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(10, 5), 10)
	var t := TaskList.new()
	t.add_step(TaskList.Type.COLLECT, Vector2i(10, 5))
	t.add_step(TaskList.Type.GOTO, Vector2i(5, 5))
	t.start(w.player)
	_run(w, t, 200)
	assert_true(w.player.inventory.count_of("scrap") >= 8, "hat %d Schrott" % w.player.inventory.count_of("scrap"))


func test_collect_then_deposit_into_ship() -> void:
	var w := _world()
	w.ship_cfg = ShipSystem.load_config()
	w.add_pile("scrap_pile", Vector2i(10, 5), 10)
	TestWorlds.with_ship(w, Vector2i(4, 8))
	var t := TaskList.new()
	t.add_step(TaskList.Type.COLLECT, Vector2i(10, 5))
	t.add_step(TaskList.Type.DEPOSIT, Vector2i(4, 8))
	t.start(w.player)
	_run(w, t, 600)
	assert_true(w.bolts >= 10, "Schiff hat abgekauft: %d Bolts" % w.bolts)
	assert_true(t.active, "läuft weiter in der Schleife")


func test_hammer_toaster_and_pick_up_loot() -> void:
	var w := _world()
	w.add_object("toaster", Vector2i(10, 5))
	var t := TaskList.new()
	t.add_step(TaskList.Type.HAMMER, Vector2i(10, 5))
	t.add_step(TaskList.Type.GOTO, Vector2i(5, 5))
	t.start(w.player)
	_run(w, t, 700)
	assert_eq(w.nodes.size(), 0, "Toaster zerlegt")
	assert_true(w.player.inventory.total() >= 8, "lose Items eingesammelt: %d" % w.player.inventory.total())


func test_too_hard_waits_and_reports() -> void:
	var w := _world()
	w.add_object("fridge", Vector2i(10, 5))
	var t := TaskList.new()
	t.add_step(TaskList.Type.HAMMER, Vector2i(10, 5))
	var reasons := []
	t.waiting.connect(func(r: String) -> void: reasons.append(r))
	t.start(w.player)
	_run(w, t, 60)
	assert_eq(reasons, ["too_hard"])
	assert_true(t.wait_ticks > 0)


func test_old_save_with_rusty_tasks_loads_silently() -> void:
	var w := _world()
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.flags["tutorial_done"] = true
	w.flags["gate_open"] = true
	var data := SaveCodec.encode(w, "main", Vector2(320, 320), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	assert_false(data.has("tasks"), "Rustys Aufgabenliste wird nicht mehr gespeichert")
	# Alter Stand (bis MS37) mit Autopilot-Liste: Schlüssel wird still ignoriert.
	data["tasks"] = {"steps": [{"type": 1, "tile": [3, 4], "item": "scrap"}], "active": true, "index": 0}
	var w2 := _world()
	w2.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
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


func test_stop_with_body_releases_suction() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(10, 5), 10)
	var t := TaskList.new()
	t.add_step(TaskList.Type.COLLECT, Vector2i(10, 5))
	t.start(w.player)
	_run(w, t, 30)
	assert_true(w.player.has_move_target() or w.player.suck_held)
	w.player.suck_held = true  # wie mitten im Saugen
	t.stop(w.player)
	assert_false(t.active)
	assert_false(w.player.has_move_target())
	assert_false(w.player.suck_held, "Stopp gibt den Sauger frei")
