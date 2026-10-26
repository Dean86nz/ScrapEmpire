extends TestCase
## Aufgabenkette für den neuen Ablauf: sammeln, abliefern, aufrüsten, Schiff reparieren, Bots, Drohnen.


func _world() -> SimWorld:
	var w := TestWorlds.make()
	MapLoader.apply(w, {"width": 40, "height": 30, "player_start": {"x": 20, "y": 15}, "ship": {"x": 16, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}], "zone_order": ["a"], "unlock_cleanliness": 0.5,
		"nodes": [{"kind": "scrap_pile", "x": 20, "y": 10, "amount": 10}, {"kind": "toaster", "x": 24, "y": 12}]})
	w.player.pos = Vector2i(20 * 64 + 32, 15 * 64 + 32)
	return w


func _ids(w: SimWorld) -> Array:
	var out := []
	for q in w.quests.defs:
		out.append(str(q["id"]))
	return out


func _goto(w: SimWorld, id: String) -> void:
	w.quests.index = _ids(w).find(id)


func test_chain_starts_simple_and_ends_with_launch() -> void:
	var w := _world()
	var ids := _ids(w)
	assert_eq(ids[0], "q_move")
	assert_eq(ids[1], "q_collect")
	assert_eq(ids[2], "q_deliver")
	assert_eq(ids[3], "q_upgrade")
	assert_eq(ids[-1], "q_launch")
	for q in w.quests.defs:
		assert_true(["moved", "collect", "ship_delivered", "upgrades_bought", "wrecks", "upgrade_level", "bolts_earned",
			"zone_gate", "ship_stage", "helpers", "drones", "collectibles", "planet", "cleaned", "deliveries"].has(str(q["type"])), "bekannter Typ: " + str(q["type"]))


func test_first_minutes_move_collect_deliver_upgrade() -> void:
	var w := _world()
	var done := []
	w.quest_completed.connect(func(id: String, _d: Dictionary) -> void: done.append(id))
	for i in 30:
		w.player.pos += Vector2i(8, 0)
		w.tick()
	TestWorlds.run(w, 10)
	assert_eq(done, ["q_move"])
	for i in 20:
		w.item_collected.emit("scrap", w.player.pos)
	TestWorlds.run(w, 10)
	assert_eq(done.back(), "q_collect")
	w.player.inventory.add("scrap", 20)
	w.queue_command({"type": "deliver_all"})
	TestWorlds.run(w, 10)
	assert_eq(done.back(), "q_deliver")
	assert_eq(w.bolts, 30, "20 Schrott + 10 Bonus")
	w.queue_command({"type": "buy_upgrade", "id": "cargo"})
	TestWorlds.run(w, 10)
	assert_eq(done.back(), "q_upgrade")


func test_upgrade_level_and_bolts_earned() -> void:
	var w := _world()
	_goto(w, "q_cargo")
	assert_eq(w.quests.progress(w), [0, 2])
	w.ship_upgrades["cargo"] = 2
	assert_true(w.quests.is_satisfied(w))
	_goto(w, "q_earn")
	w.player.inventory.add("chrome", 10)
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_eq(w.quests.progress(w), [80, 300])


func test_zone_gate_ship_stage_bots_and_planet() -> void:
	var w := _world()
	_goto(w, "q_zone1")
	assert_eq(w.quests.progress(w)[1], 50)
	for n in w.nodes.values():
		if n.kind == "toaster":
			w._remove_node(n)
	assert_true(w.quests.is_satisfied(w))
	_goto(w, "q_ship2")
	assert_eq(w.quests.progress(w), [1, 2])
	_goto(w, "q_bot")
	w.unlocked_features["helpers"] = true
	w.add_helper(Vector2i(20, 10), w.ship().tile)
	assert_true(w.quests.is_satisfied(w))
	_goto(w, "q_planet")
	assert_eq(w.quests.progress(w), [80, 80])


func test_save_roundtrip() -> void:
	var w := _world()
	w.quests.index = 3
	w.quests.counters["sold_value"] = 12
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.quests.index, 3)
	assert_eq(int(w2.quests.counters["sold_value"]), 12)
