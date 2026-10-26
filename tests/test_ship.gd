extends TestCase
## Kern-Ablauf am Schiff: abliefern → Bolts, Upgrades für Rusty, Reparaturstufen mit Blaupausen.


func test_ship_def_is_not_buildable_and_not_removable() -> void:
	var w := TestWorlds.make()
	var def: BuildingDef = w.defs["ship"]
	assert_false(def.buildable)
	assert_eq(def.size, Vector2i(3, 3))
	var fails := []
	w.place_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "place", "def_id": "ship", "tile": Vector2i(10, 10)})
	w.tick()
	assert_eq(w.building_count("ship"), 0)
	var s := TestWorlds.with_ship(w)
	w.queue_command({"type": "remove", "tile": s.tile})
	w.tick()
	assert_eq(w.building_count("ship"), 1)
	assert_eq(fails, ["locked", "ship"])


func test_deliver_all_turns_inventory_into_bolts_immediately() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	w.player.inventory.add("scrap", 10)
	w.player.inventory.add("copper", 10)
	w.player.inventory.add("chrome", 2)
	var delivered := []
	w.ship_delivered.connect(func(items: Dictionary, bolts: int) -> void: delivered.append([items, bolts]))
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_eq(w.player.inventory.total(), 0, "alles abgeliefert")
	assert_eq(w.bolts, 10 * 1 + 10 * 3 + 2 * 8, "Werte laut Tabelle: Schrott 1, Kupfer 3, Chrom 8")
	assert_eq(delivered.size(), 1)
	assert_eq(int(delivered[0][1]), 56)


func test_deliver_empty_gives_feedback() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	var fails := []
	w.ship_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_eq(fails, ["empty"])


func test_start_inventory_is_small() -> void:
	var w := TestWorlds.make()
	assert_eq(w.player.inventory.slot_count, 4)
	assert_eq(w.player.inventory.stack_size, 10)


func test_upgrade_costs_follow_table() -> void:
	var w := TestWorlds.make()
	assert_eq(ShipSystem.upgrade_cost(w, "cargo"), 25)
	assert_eq(ShipSystem.upgrade_cost(w, "yield"), 60)
	assert_eq(ShipSystem.upgrade_cost(w, "speed"), 40)
	assert_eq(ShipSystem.upgrade_cost(w, "suction"), 50)
	assert_eq(ShipSystem.upgrade_cost(w, "tool"), 300)
	w.ship_upgrades["cargo"] = 1
	assert_eq(ShipSystem.upgrade_cost(w, "cargo"), 40, "25 × 1,6 auf 5 gerundet")
	w.ship_upgrades["cargo"] = 8
	assert_eq(ShipSystem.upgrade_cost(w, "cargo"), -1)
	assert_eq(ShipSystem.can_buy_upgrade(w, "cargo"), "max")


func test_buy_upgrades_change_rusty() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	w.bolts = 100000
	var bought := []
	w.ship_upgrade_bought.connect(func(id: String, lvl: int) -> void: bought.append([id, lvl]))
	for id in ["cargo", "cargo", "yield", "speed", "suction", "tool"]:
		w.queue_command({"type": "buy_upgrade", "id": id})
	w.tick()
	assert_eq(bought.size(), 6)
	assert_eq(w.player.inventory.slot_count, 6, "4 + 2 Laderaum")
	assert_true(absf(float(w.mods["sell_mult"]) - 1.1) < 0.001)
	assert_true(absf(float(w.mods["speed_mult"]) - 1.08) < 0.001)
	assert_eq(w.player.suck_interval, 4, "5 / 1,12 = 4,5 → 4")
	assert_eq(w.player.hammer_tier, 2)
	assert_eq(w.player.suction_tier, 2)
	assert_eq(w.bolts, 100000 - 25 - 40 - 60 - 40 - 50 - 300)
	assert_eq(ShipSystem.upgrades_total(w), 6)


func test_yield_upgrade_raises_delivery_value() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w)
	w.ship_upgrades["yield"] = 5
	w.recompute_modifiers()
	w.player.inventory.add("scrap", 10)
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_eq(w.bolts, 15, "10 × 1 × 1,5")


func test_upgrade_without_bolts_fails() -> void:
	var w := TestWorlds.make()
	var fails := []
	w.ship_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "buy_upgrade", "id": "cargo"})
	w.tick()
	assert_eq(fails, ["upgrade_bolts"])
	assert_eq(w.player.inventory.slot_count, 4)


func test_repair_stages_unlock_blueprints() -> void:
	var w := TestWorlds.make()
	var s := TestWorlds.with_ship(w)
	assert_eq(ShipSystem.max_stage(w), 5)
	assert_eq(ShipSystem.next_stage_cost(w, s), 500)
	assert_false(w.unlocked_features.has("helpers"))
	var fails := []
	w.ship_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "upgrade_ship"})
	w.tick()
	assert_eq(fails, ["bolts"])
	w.bolts = 15500
	var ups := []
	w.ship_upgraded.connect(func(sh: Ship) -> void: ups.append(sh.stage))
	for i in 3:
		w.queue_command({"type": "upgrade_ship"})
		w.tick()
	assert_eq(ups, [2, 3, 4])
	assert_eq(w.bolts, 0)
	for f in ["helpers", "drones", "decor", "helper_tools", "museum"]:
		assert_true(w.unlocked_features.has(f), "frei: " + f)
	assert_true(s.sprite_path.ends_with("ship_3.svg"))


func test_final_stage_needs_healed_planet_and_launches() -> void:
	var w := TestWorlds.make()
	MapLoader.apply(w, {"width": 40, "height": 30, "zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}],
		"nodes": [{"kind": "toaster", "x": 20, "y": 20}]})
	var s := TestWorlds.with_ship(w)
	s.stage = 4
	ShipSystem.apply_stage(w, s)
	w.bolts = 40000
	assert_eq(ShipSystem.can_upgrade(w, s), "planet")
	for n in w.nodes.values():
		w._remove_node(n)
	assert_eq(ShipSystem.can_upgrade(w, s), "")
	w.queue_command({"type": "upgrade_ship"})
	w.tick()
	assert_eq(s.stage, 5)
	assert_true(bool(w.flags.get("launched", false)))
	assert_eq(ShipSystem.can_upgrade(w, s), "max")


func test_save_roundtrip_keeps_stage_and_upgrades() -> void:
	var w := TestWorlds.make()
	var s := TestWorlds.with_ship(w)
	s.stage = 3
	ShipSystem.apply_stage(w, s)
	w.ship_upgrades["cargo"] = 2
	w.recompute_modifiers()
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	var w2 := TestWorlds.make()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	var s2 := w2.ship()
	assert_eq(s2.stage, 3)
	assert_true(w2.unlocked_features.has("drones"), "Freischaltungen aus der Stufe")
	assert_eq(w2.player.inventory.slot_count, 6)


func test_ensure_ship_and_planet_health() -> void:
	var w := TestWorlds.make()
	var map := {"width": 40, "height": 30, "player_start": {"x": 20, "y": 15}, "ship": {"x": 16, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}], "nodes": [{"kind": "toaster", "x": 5, "y": 5}]}
	MapLoader.apply(w, map, false)
	assert_true(w.ship() == null)
	var s := MapLoader.ensure_ship(w, map)
	assert_true(s != null and s.tile == Vector2i(16, 13))
	assert_true(MapLoader.ensure_ship(w, map) == s, "kein zweites Schiff")
	var w2 := TestWorlds.make()
	MapLoader.apply(w2, map)
	assert_true(w2.ship() != null)
	assert_true(absf(w2.zones.planet_health(w2.nodes)) < 0.001, "Planet 0 % mit Müll")
	for n in w2.nodes.values():
		w2._remove_node(n)
	assert_true(absf(w2.zones.planet_health(w2.nodes) - 1.0) < 0.001, "Planet 100 % ohne Müll")
