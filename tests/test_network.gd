extends TestCase
## Bot-Stationen (MS78), Drohnen-Transport, Umbau alter Sammelstellen und Kurier (MS34).


func _world() -> SimWorld:
	var w := TestWorlds.make(60, 30)
	w.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w, {"width": 60, "height": 30, "seed": 2, "zone_order": ["a", "b"], "unlock_cleanliness": 0.5,
		"player_start": {"x": 5, "y": 15}, "ship": {"x": 2, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 30, "h": 30}, {"id": "b", "name": "B", "x": 30, "y": 0, "w": 30, "h": 30}],
		"nodes": []})
	w.zones.unlocked["b"] = true
	return w


func _station(w: SimWorld, tile: Vector2i) -> Station:
	var st := w.place_free(StationSystem.DEF, tile) as Station
	StationSystem.apply(w, st)
	return st


func test_station_costs_bolts_and_brings_a_drone() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	w.bolts = 2000
	w.player.pos = Vector2i(40, 10) * 64
	w.queue_command({"type": "build_station"})
	w.tick()
	assert_eq(StationSystem.stations(w).size(), 1, "Station neben Rusty gebaut")
	assert_eq(w.bolts, 2000 - 300)
	assert_eq(w.drones.size(), 1, "bringt eine Drohne mit")


func test_far_station_is_emptied_by_drone() -> void:
	var w := _world()
	var st := _station(w, Vector2i(40, 10))
	w.player.pos = st.center_px()
	w.player.inventory.add("copper", 20)
	w.queue_command({"type": "deliver_all", "to": st.id})
	w.tick()
	assert_eq(st.total(), 20, "Rusty lädt an der Station ab")
	assert_false(StationSystem.linked_to_ship(w, st))
	w.add_drone()
	TestWorlds.run(w, 20 * 20)
	assert_eq(st.total(), 0, "Drohne hat abgeholt")
	assert_eq(w.bolts, 60, "20 Kupfer à 3 am Schiff")


func test_near_station_shoots_cube_to_ship() -> void:
	var w := _world()
	var st := _station(w, Vector2i(7, 13))
	assert_true(StationSystem.linked_to_ship(w, st))
	st.accept_stack("scrap", 10)
	TestWorlds.run(w, 20 * 4)
	assert_eq(st.total(), 0, "Station gibt selbst ans Schiff weiter")
	assert_eq(w.bolts, 10)


func test_station_bot_stays_in_radius() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	w.bolts = 5000
	var st := _station(w, Vector2i(40, 10))
	w.add_pile("scrap_pile", Vector2i(44, 12), 6)
	var far := w.add_pile("scrap_pile", Vector2i(55, 25), 6)
	w.player.pos = st.center_px()
	w.queue_command({"type": "buy_helper"})
	w.tick()
	var h: Helper = w.helpers.values()[0]
	assert_eq(h.station_id, st.id)
	var limit := float((st.radius_tiles + 2) * 64)
	var max_d := 0.0
	for i in 20 * 40:
		w.tick()
		max_d = maxf(max_d, Vector2(h.pos).distance_to(Vector2(st.center_px())))
	assert_true(max_d <= limit, "bleibt im Umkreis: %d > %d" % [max_d, limit])
	assert_eq(far.amount, 6, "Müll außerhalb bleibt liegen")
	assert_true(st.total() > 0 or h.inventory.total() > 0, "arbeitet und liefert an die Station")


func test_buy_needs_free_station() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	w.bolts = 100000
	var fails := []
	w.helper_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "buy_helper"})
	w.tick()
	assert_eq(fails, ["no_station"])
	var st := _station(w, Vector2i(10, 20))
	for i in st.slots + 1:
		w.queue_command({"type": "buy_helper"})
		w.tick()
	assert_eq(StationSystem.bots_of(w, st), st.slots, "Station voll")
	assert_eq(fails.back(), "no_station")


func test_old_collection_point_becomes_hopper_and_station() -> void:
	var w := _world()
	var p := w.place_free("collection_point", Vector2i(40, 10)) as CollectionPoint
	p.accept_stack("chrome", 7)
	var h := w.add_helper(Vector2i(42, 12), p.tile)
	h.zone_id = "b"
	var data := SaveCodec.encode(w, "test", Vector2(32, 32), 0)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(NetworkSystem.points(w2).filter(func(b: CollectionPoint) -> bool: return b.def.id == "collection_point").size(), 0, "keine Sammelstelle mehr")
	var hops := RoamerSystem.hoppers(w2)
	assert_eq(hops.size(), 1)
	assert_eq(hops[0].store, {"chrome": 7}, "Inhalt bleibt")
	var sts := StationSystem.stations(w2)
	assert_eq(sts.size(), 1, "dazu eine Station")
	assert_eq((w2.helpers.values()[0] as Helper).station_id, sts[0].id, "Bot gehört zur neuen Station")


func test_store_and_courier_survive_save() -> void:
	var w := _world()
	var st := _station(w, Vector2i(40, 10))
	st.accept_stack("chrome", 7)
	w.unlocked_features["courier"] = true
	w.player.inventory.add("scrap", 4)
	w.queue_command({"type": "call_courier"})
	w.tick()
	var data := SaveCodec.encode(w, "test", Vector2(32, 32), 0)
	var w2 := TestWorlds.make(60, 30)
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	var sts := StationSystem.stations(w2)
	assert_eq(sts.size(), 1)
	assert_eq(sts[0].store, {"chrome": 7})
	assert_eq(w2.couriers.size(), 1)
	assert_true(w2.courier_cooldown > 0)


func test_courier_locked_then_picks_up_and_delivers() -> void:
	var w := _world()
	w.player.pos = Vector2i(20 * 64, 15 * 64)
	w.player.inventory.add("scrap", 10)
	w.queue_command({"type": "call_courier"})
	var fails := []
	w.courier_failed.connect(func(r: String) -> void: fails.append(r))
	w.tick()
	assert_eq(fails, ["locked"], "erst ab Schiffsstufe 3")
	w.unlocked_features["courier"] = true
	w.queue_command({"type": "call_courier"})
	w.tick()
	assert_eq(w.couriers.size(), 1)
	var loaded := []
	w.courier_loaded.connect(func(_c: Courier, items: Dictionary) -> void: loaded.append(items))
	TestWorlds.run(w, 20 * 15)
	assert_eq(loaded, [{"scrap": 10}])
	assert_eq(w.player.inventory.total(), 0, "Rusty ist die Ladung los")
	assert_eq(w.bolts, 10, "am Schiff angekommen")
	assert_eq(w.couriers.size(), 0, "Kurier wieder weg")
	assert_eq(int(w.quests.counters.get("courier_pickups", 0)), 1)
	w.player.inventory.add("scrap", 5)
	w.queue_command({"type": "call_courier"})
	w.tick()
	assert_eq(fails.back(), "cooldown", "Wartezeit")


func test_courier_comes_by_itself_when_bags_are_full() -> void:
	var w := _world()
	w.unlocked_features["courier"] = true
	var inv := w.player.inventory
	for s in inv.slot_count:
		inv.add("scrap", inv.stack_size)
	assert_true(inv.is_full())
	w.tick()
	assert_eq(w.couriers.size(), 1, "kommt automatisch")
	w.flags["courier_auto"] = false
	w.couriers.clear()
	w.courier_cooldown = 0
	w.tick()
	assert_eq(w.couriers.size(), 0, "Automatik aus")


func test_courier_upgrade_raises_load_and_count() -> void:
	var w := _world()
	w.unlocked_features["courier"] = true
	assert_eq(int(NetworkSystem.courier_stats(w)["count"]), 1)
	var first_load := int(NetworkSystem.courier_stats(w)["load"])
	w.ship_upgrades["courier"] = 1
	assert_true(int(NetworkSystem.courier_stats(w)["load"]) > first_load, "Stufe 2 trägt mehr")
	# Höchststufe aus ship.json: letzte Zeile der Kurier-Tabelle
	var levels: Array = w.ship_cfg["courier"]["levels"]
	w.ship_upgrades["courier"] = int(ShipSystem.upgrade_def(w, "courier")["max_level"])
	assert_eq(int(NetworkSystem.courier_stats(w)["count"]), int(levels[-1]["count"]))
	assert_true(int(NetworkSystem.courier_stats(w)["count"]) > 1, "mehrere Kuriere")
	assert_eq(int(NetworkSystem.courier_stats(w)["load"]), 0, "alles")
