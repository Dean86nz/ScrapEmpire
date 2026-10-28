extends TestCase
## Sammel-Bots: Bau am Schiff, sammeln im Umkreis, liefern ans Schiff (Bolts), Upgrades, Spielstand.


func _world() -> SimWorld:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w, Vector2i(9, 9))   # Schiff bei (9..11, 9..11)
	return w


func _unlock(w: SimWorld) -> void:
	w.unlocked_features["helpers"] = true


func test_cost_curve() -> void:
	var w := _world()
	var base := int(w.helper_cfg["cost_base_bolts"])
	var g := float(w.helper_cfg["cost_growth"])
	assert_eq(w.next_helper_cost(), {"bolts": base})
	_unlock(w)
	w.add_helper(Vector2i(10, 6), w.ship().tile)
	var c1 := int(w.next_helper_cost()["bolts"])
	assert_true(absi(c1 - int(base * g)) <= 10, "zweiter Bot ≈ Basis × Wachstum (%d)" % c1)
	w.add_helper(Vector2i(10, 6), w.ship().tile)
	assert_true(int(w.next_helper_cost()["bolts"]) > c1, "jeder weitere teurer")


func test_buy_requirements() -> void:
	var w := _world()
	var fails := []
	w.helper_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "buy_helper"})
	w.tick()
	assert_eq(fails, ["locked"])
	_unlock(w)
	w.queue_command({"type": "buy_helper"})
	w.tick()
	assert_eq(fails, ["locked", "bolts"])
	w.bolts = 200
	w.queue_command({"type": "buy_helper", "zone": Vector2i(14, 6)})
	w.tick()
	assert_eq(w.helpers.size(), 1)
	assert_eq(w.bolts, 50)
	var h: Helper = w.helpers.values()[0]
	assert_eq(h.zone_tile, Vector2i(14, 6))
	assert_eq(h.depot_tile, w.ship().tile, "Bots liefern immer ans Schiff")
	assert_eq(h.display_name(w.helper_cfg["names"]), "Bolte")


func test_bot_works_where_rusty_is_by_default() -> void:
	var w := _world()
	_unlock(w)
	w.bolts = 200
	w.player.pos = Vector2i(20 * 64, 5 * 64)
	w.queue_command({"type": "buy_helper"})
	w.tick()
	var h: Helper = w.helpers.values()[0]
	assert_eq(h.zone_tile, Vector2i(20, 5))


func test_max_helpers() -> void:
	var w := _world()
	_unlock(w)
	for i in int(w.helper_cfg["max_helpers"]):
		w.add_helper(Vector2i(10, 6), w.ship().tile)
	w.bolts = 100000000
	assert_eq(w.can_buy_helper(), "max")


func test_bot_collects_pile_and_earns_bolts_at_ship() -> void:
	var w := _world()
	_unlock(w)
	w.add_pile("scrap_pile", Vector2i(14, 6), 10)
	w.add_pile("copper_tangle", Vector2i(6, 14), 10)
	var h := w.add_helper(Vector2i(10, 8), w.ship().tile)
	TestWorlds.run(w, 20 * 60)
	assert_true(w.bolts >= 20, "Bot hat abgeliefert, Bolts: %d" % w.bolts)
	assert_true(h.inventory.total() < 30, "lädt regelmäßig ab")


func test_bot_hammers_toaster() -> void:
	var w := _world()
	_unlock(w)
	w.add_object("toaster", Vector2i(14, 8))
	w.add_helper(Vector2i(10, 8), w.ship().tile)
	TestWorlds.run(w, 20 * 60)
	assert_eq(w.nodes.size(), 0, "Toaster zerlegt")
	assert_true(w.bolts >= 6, "Beute abgeliefert: %d Bolts" % w.bolts)


func test_bot_ignores_objects_above_tier_and_outside_radius() -> void:
	var w := _world()
	ResourceNode.load_defs("res://tests/data/scrap_objects_test.json")  # feste Test-Objekte
	_unlock(w)
	var fridge := w.add_object("fridge", Vector2i(14, 8))      # T2
	var far := w.add_pile("scrap_pile", Vector2i(35, 8), 10)    # 25 Kacheln entfernt
	w.add_helper(Vector2i(10, 8), w.ship().tile)
	TestWorlds.run(w, 20 * 20)
	assert_eq(fridge.amount, 27)
	assert_eq(far.amount, 10)


func test_upgrades_change_speed_capacity_tier() -> void:
	var w := _world()
	_unlock(w)
	w.unlocked_features["helper_tools"] = true
	var h := w.add_helper(Vector2i(10, 8), w.ship().tile)
	assert_eq(h.speed_px_per_tick, 11)
	assert_eq(h.inventory.stack_size, 10)
	assert_eq(h.hammer_tier, 1)
	w.bolts = 10000
	var fails := []
	w.helper_failed.connect(func(r: String) -> void: fails.append(r))
	for id in ["helper_speed", "helper_capacity", "helper_tool"]:
		w.queue_command({"type": "buy_helper_upgrade", "id": id})
		w.tick()
	assert_eq(fails, [])
	assert_eq(h.speed_px_per_tick, 13, "224 × 1,2 / 20 = 13,4")
	assert_eq(h.inventory.stack_size, 20)
	assert_eq(h.hammer_tier, 2)
	assert_eq(w.bolts, 10000 - 300 - 300 - 400)
	w.bolts = 100000
	for i in 3:
		w.queue_command({"type": "buy_helper_upgrade", "id": "helper_tool"})
		w.tick()
	assert_eq(h.hammer_tier, 5, "Bot-Werkzeug bis T5: jeder normale Müll (MS42)")


func test_upgrade_requires_feature_and_max() -> void:
	var w := _world()
	w.bolts = 100000
	assert_eq(w.can_buy_helper_upgrade("helper_speed"), "locked")
	_unlock(w)
	assert_eq(w.can_buy_helper_upgrade("helper_tool"), "locked", "braucht das Feature helper_tools")
	for i in 3:
		w.queue_command({"type": "buy_helper_upgrade", "id": "helper_speed"})
		w.tick()
	assert_eq(w.can_buy_helper_upgrade("helper_speed"), "max")


func test_stuck_event_pauses_and_quips() -> void:
	var w := _world()
	_unlock(w)
	w.add_pile("scrap_pile", Vector2i(14, 6), 10)
	var h := w.add_helper(Vector2i(10, 8), w.ship().tile)
	h.stuck_timer = 30
	var quips := []
	w.helper_quip.connect(func(_h: Helper, key: String) -> void: quips.append(key))
	TestWorlds.run(w, 40)
	assert_eq(quips.size(), 1)
	assert_true(quips[0].begins_with("HELPER_STUCK"))


func test_save_roundtrip_with_helpers() -> void:
	var w := _world()
	_unlock(w)
	var h := w.add_helper(Vector2i(10, 6), w.ship().tile)
	h.inventory.add("scrap", 7)
	w.helper_upgrades["helper_speed"] = 2
	w.recompute_modifiers()
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	var w2 := TestWorlds.make()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.helpers.size(), 1)
	var h2: Helper = w2.helpers.values()[0]
	assert_eq(h2.zone_tile, Vector2i(10, 6))
	assert_eq(h2.depot_tile, Vector2i(9, 9))
	assert_eq(h2.inventory.count_of("scrap"), 7)
	assert_eq(int(w2.helper_upgrades["helper_speed"]), 2)
	assert_eq(h2.speed_px_per_tick, h.speed_px_per_tick)


func test_bored_bot_says_why() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	w.bolts = 1000
	w.queue_command({"type": "buy_helper", "zone": Vector2i(20, 20)})
	w.tick()
	var h: Helper = w.helpers.values()[0]
	var bored := []
	w.helper_bored.connect(func(b: Helper) -> void: bored.append(b.bored))
	h.idle_quip_timer = 1
	TestWorlds.run(w, 120)
	assert_eq(h.bored, "empty", "nichts in der Nähe")
	assert_true(bored.has("empty"), "meldet Langeweile")
	w.add_object("monolith", Vector2i(21, 21))
	h.idle_quip_timer = 1
	TestWorlds.run(w, 120)
	assert_eq(h.bored, "too_hard", "nur zu harter Müll")


func test_bots_pick_up_loose_items_first() -> void:
	# MS49: Bots sammeln alles, was herumliegt, nicht nur selbst Abgebautes.
	var w := _world()
	var h := w.add_helper(Vector2i(10, 6), w.ship().tile)
	var item := w.add_loose("scrap", Vector2i(12, 6) * 64, 1)
	var id := item.id
	TestWorlds.run(w, 20 * 15)
	assert_false(w.loose.has(id), "loses Teil wurde eingesammelt")
