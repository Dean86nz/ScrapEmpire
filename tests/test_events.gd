extends TestCase
## Nachschub-Ereignisse (MS30): Touristen und Meteoriten.


func _world() -> SimWorld:
	var w := TestWorlds.make()
	w.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w, {"width": 40, "height": 30, "seed": 5, "dirt": true, "zone_order": ["a"], "unlock_cleanliness": 0.5,
		"player_start": {"x": 20, "y": 15}, "ship": {"x": 2, "y": 2},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}], "nodes": []})
	w.player.pos = Vector2i(20 * 64 + 32, 15 * 64 + 32)
	w.events_cfg = EventSystem.load_config()
	return w


func _run_until(w: SimWorld, ticks: int) -> void:
	for i in ticks:
		w.tick()


func test_first_tourists_after_four_minutes_with_warning() -> void:
	var w := _world()
	var warn := []
	var started := []
	var landed := []
	w.event_warning.connect(func(t: String, s: float, _c: Vector2) -> void: warn.append([t, s]))
	w.event_started.connect(func(t: String, px: Array, _d: Array) -> void: started.append([t, px.size()]))
	w.event_landed.connect(func(t: String, n: ResourceNode) -> void: landed.append([t, n.kind, n.bonus]))
	_run_until(w, 240 * 20 - 5)
	assert_eq(warn.size(), 0, "vor 4 Minuten nichts")
	_run_until(w, 10)
	assert_eq(warn, [["tourists", 5.0]])
	_run_until(w, 5 * 20 + 2)
	assert_eq(started.size(), 1)
	var n := int(started[0][1])
	assert_true(n >= 4 and n <= 6, "4 bis 6 Säcke: %d" % n)
	_run_until(w, 5 * 20)
	assert_eq(landed.size(), n, "alle Säcke gelandet")
	assert_eq(landed[0][1], "trash_bag")
	assert_true(landed[0][2], "Bonus-Müll")


func test_bonus_trash_does_not_soil_meadow_and_is_richer() -> void:
	var w := _world()
	w.events_state = {"next": {"tourists": 0, "meteors": 999999}, "warn": [], "drops": []}
	var bags: Array = []
	w.event_landed.connect(func(_t: String, n: ResourceNode) -> void: bags.append(n))
	for y in 30:
		for x in 40:
			w.dirt.clean(Vector2i(x, y), 255)
	_run_until(w, 20 * 12)
	assert_true(bags.size() >= 4)
	for b: ResourceNode in bags:
		assert_eq(w.dirt.value(b.tile), 0, "Boden unter dem Sack bleibt sauber")
		assert_true(b.amount >= 15, "mehr drin als ein Toaster (10): %d" % b.amount)
	var bag: ResourceNode = bags[0]
	w._remove_node(bag)
	assert_true(w.dirt.is_green(bag.tile), "Wiese bleibt Wiese")


func test_meteors_only_from_ship_stage_two() -> void:
	var w := _world()
	w.events_state = {"next": {"tourists": 999999, "meteors": 0}, "warn": [], "drops": []}
	var warn := []
	w.event_warning.connect(func(t: String, _s: float, _c: Vector2) -> void: warn.append(t))
	_run_until(w, 5)
	assert_eq(warn, [], "Stufe 1: keine Meteoriten")
	w.ship().stage = 2
	w.events_state["next"]["meteors"] = w.tick_count
	_run_until(w, 3)
	assert_eq(warn, ["meteors"])
	_run_until(w, 20 * 26)
	var meteors := 0
	for n: ResourceNode in w.nodes.values():
		if n.kind == "meteor":
			meteors += 1
	assert_true(meteors >= 5 and meteors <= 8, "5 bis 8 Brocken: %d" % meteors)


func test_cap_on_bonus_objects() -> void:
	var w := _world()
	w.events_cfg["max_bonus_objects"] = 3
	w.events_state = {"next": {"tourists": 0, "meteors": 999999}, "warn": [], "drops": []}
	_run_until(w, 20 * 12)
	assert_true(EventSystem.bonus_count(w) <= 3)
	w.events_state["next"]["tourists"] = w.tick_count
	_run_until(w, 20 * 12)
	assert_true(EventSystem.bonus_count(w) <= 3, "Obergrenze hält")


func test_event_state_survives_save() -> void:
	var w := _world()
	w.events_state = {"next": {"tourists": 0, "meteors": 999999}, "warn": [], "drops": []}
	_run_until(w, 20 * 6 + 10)
	assert_false((w.events_state["drops"] as Array).is_empty(), "Säcke unterwegs")
	var data := SaveCodec.encode(w, "test", Vector2(32, 32), 0)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq((w2.events_state["drops"] as Array).size(), (w.events_state["drops"] as Array).size())
	assert_eq(int(w2.events_state["next"]["tourists"]), int(w.events_state["next"]["tourists"]))
	_run_until(w2, 20 * 4)
	var bonus := 0
	for n: ResourceNode in w2.nodes.values():
		if n.bonus:
			bonus += 1
	assert_true(bonus >= 4, "nach dem Laden landen die Säcke trotzdem")
