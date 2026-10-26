extends TestCase
## Meilensteine und neue kurze Aufgaben (MS23).


func _ms(w: SimWorld, id: String) -> Dictionary:
	for d: Dictionary in w.milestones.defs:
		if d["id"] == id:
			return d
	return {}


func test_defs_load_with_rising_steps() -> void:
	var w := TestWorlds.make()
	assert_true(w.milestones.defs.size() >= 6)
	for d: Dictionary in w.milestones.defs:
		var steps: Array = d["steps"]
		for i in range(1, steps.size()):
			assert_true(int(steps[i]) > int(steps[i - 1]), "Stufen steigen: " + str(d["id"]))


func test_reaching_a_step_pays_once() -> void:
	var w := TestWorlds.make()
	var got := []
	w.milestone_reached.connect(func(d: Dictionary, step: int, value: int, bolts: int) -> void: got.append([d["id"], step, value, bolts]))
	w.quests.counters["collect:scrap"] = 99
	w.milestones.check(w)
	assert_eq(got.size(), 0)
	w.quests.counters["collect:scrap"] = 60
	w.quests.counters["collect:copper"] = 40
	w.milestones.check(w)
	assert_eq(got, [["ms_collected", 0, 100, 20]], "Summe aller gesammelten Teile")
	assert_eq(w.bolts, 20)
	w.milestones.check(w)
	assert_eq(got.size(), 1, "nur einmal")
	assert_eq(w.milestones.next_step(_ms(w, "ms_collected")), 1000)


func test_several_steps_at_once_and_last_step() -> void:
	var w := TestWorlds.make()
	w.quests.counters["wrecks"] = 1000
	assert_eq(w.milestones.check(w), 3)
	assert_eq(w.milestones.steps_done("ms_wrecks"), 3)
	assert_eq(w.milestones.next_step(_ms(w, "ms_wrecks")), -1)


func test_silent_check_gives_no_reward() -> void:
	var w := TestWorlds.make()
	w.quests.counters["sold_value"] = 6000
	var got := []
	w.milestone_reached.connect(func(_d: Dictionary, _s: int, _v: int, _b: int) -> void: got.append(1))
	w.milestones.check(w, true)
	assert_eq(w.milestones.steps_done("ms_bolts"), 2)
	assert_eq(got.size(), 0)
	assert_eq(w.bolts, 0)


func test_milestones_run_in_tick_and_are_saved() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	w.quests.counters["deliveries"] = 10
	TestWorlds.run(w, 21)
	assert_eq(w.milestones.steps_done("ms_deliveries"), 1)
	var data := SaveCodec.encode(w, "test", Vector2(32, 32), 0)
	var w2 := TestWorlds.make()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.milestones.steps_done("ms_deliveries"), 1)


func test_delivery_counts_only_when_something_moved() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	var by := []
	w.ship_delivered.connect(func(_i: Dictionary, _b: int, p: bool) -> void: by.append(p))
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_eq(int(w.quests.counters.get("deliveries", 0)), 0, "leere Taschen zählen nicht")
	w.player.inventory.add("scrap", 5)
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_eq(int(w.quests.counters.get("deliveries", 0)), 1)
	assert_eq(by, [true], "Abgabe von Rusty ist markiert")


func test_quest_position_survives_inserted_quests() -> void:
	var w := TestWorlds.make()
	var idx := -1
	for i in w.quests.defs.size():
		if w.quests.defs[i]["id"] == "q_tool":
			idx = i
	w.quests.from_dict({"index": 3, "current": "q_tool", "counters": {}})
	assert_eq(w.quests.index, idx, "über die ID gefunden, nicht über die alte Nummer")
	w.quests.from_dict({"index": 2, "counters": {}})
	assert_eq(w.quests.index, 2, "ohne ID: alte Nummer")


func test_clean_quest_reads_dirt() -> void:
	var w := TestWorlds.make()
	w.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w, {"width": 40, "height": 30, "seed": 3, "dirt": true, "zone_order": ["a"], "unlock_cleanliness": 0.5,
		"player_start": {"x": 5, "y": 15}, "ship": {"x": 2, "y": 2},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}], "nodes": []})
	for i in w.quests.defs.size():
		if w.quests.defs[i]["id"] == "q_clean":
			w.quests.index = i
	assert_eq(w.quests.progress(w)[1], 30)
	var n := 0
	for y in 30:
		for x in 40:
			if n < 30 and w.dirt.clean(Vector2i(x, y), 255):
				n += 1
	assert_true(w.quests.check(w), "30 geputzte Kacheln erfüllen die Aufgabe")
