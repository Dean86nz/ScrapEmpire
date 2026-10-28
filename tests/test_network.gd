extends TestCase
## Sammelstellen, Drohnen-Transport, Bot-Zuweisung und Kurier (MS34).


func _world() -> SimWorld:
	var w := TestWorlds.make(60, 30)
	w.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w, {"width": 60, "height": 30, "seed": 2, "zone_order": ["a", "b"], "unlock_cleanliness": 0.5,
		"player_start": {"x": 5, "y": 15}, "ship": {"x": 2, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 30, "h": 30}, {"id": "b", "name": "B", "x": 30, "y": 0, "w": 30, "h": 30}],
		"nodes": []})
	w.zones.unlocked["b"] = true
	return w


func _place_point(w: SimWorld, tile: Vector2i) -> CollectionPoint:
	w.unlocked_features["collection"] = true
	w.player.pos = tile * 64 + Vector2i(-100, 32)
	w.queue_command({"type": "place", "def_id": "collection_point", "tile": tile, "rot": 0})
	w.tick()
	for b: Building in w.buildings.values():
		if b is CollectionPoint and b.tile == tile:
			return b
	return null


func test_point_costs_bolts_one_per_zone_and_brings_a_drone() -> void:
	var w := _world()
	w.bolts = 2000
	var p := _place_point(w, Vector2i(40, 10))
	assert_true(p != null, "Sammelstelle gebaut")
	assert_eq(w.bolts, 2000 - 300)
	assert_eq(w.drones.size(), 1, "bringt eine Drohne mit")
	var fails := []
	w.place_failed.connect(func(r: String) -> void: fails.append(r))
	_place_point(w, Vector2i(45, 20))
	assert_eq(fails, ["zone_full"], "nur eine je Zone")


func test_bolts_only_when_material_reaches_the_ship() -> void:
	var w := _world()
	w.bolts = 300
	var p := _place_point(w, Vector2i(40, 10))
	assert_eq(w.bolts, 0)
	w.player.inventory.add("copper", 20)
	w.queue_command({"type": "deliver_all", "to": p.id})
	w.tick()
	assert_eq(p.total(), 20, "eingelagert")
	assert_eq(w.player.inventory.total(), 0)
	assert_eq(w.bolts, 0, "noch keine Bolts")
	TestWorlds.run(w, 20 * 20)
	assert_eq(p.total(), 0, "Drohne hat abgeholt")
	assert_eq(w.bolts, 60, "20 Kupfer à 3 am Schiff")


func test_bot_delivers_to_point_of_its_zone() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	w.bolts = 1300
	var p := _place_point(w, Vector2i(40, 10))
	w.drones.clear()
	w.add_pile("scrap_pile", Vector2i(44, 12), 6)
	w.queue_command({"type": "buy_helper", "zone": Vector2i(42, 12)})
	TestWorlds.run(w, 20 * 40)
	assert_true(p.total() > 0, "Bot lädt an der Sammelstelle ab: %d" % p.total())


func test_bots_always_find_work_themselves() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	w.bolts = 1000
	w.add_pile("scrap_pile", Vector2i(45, 20), 5)
	w.queue_command({"type": "buy_helper", "zone": Vector2i(5, 5)})
	w.tick()
	var h: Helper = w.helpers.values()[0]
	assert_true(h.auto, "Bots arbeiten immer automatisch")
	TestWorlds.run(w, 20 * 10)
	assert_eq(h.zone_id, "b", "leere Zone A: Bot zieht selbst in Zone B mit Müll")


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
	w.ship_upgrades["courier"] = 4
	assert_eq(int(NetworkSystem.courier_stats(w)["count"]), 3)
	assert_eq(int(NetworkSystem.courier_stats(w)["load"]), 0, "alles")


func test_store_and_courier_survive_save() -> void:
	var w := _world()
	w.bolts = 300
	var p := _place_point(w, Vector2i(40, 10))
	w.drones.clear()
	p.accept_stack("chrome", 7)
	w.unlocked_features["courier"] = true
	w.player.inventory.add("scrap", 4)
	w.queue_command({"type": "call_courier"})
	w.tick()
	var data := SaveCodec.encode(w, "test", Vector2(32, 32), 0)
	var w2 := TestWorlds.make(60, 30)
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	var p2: CollectionPoint = null
	for b: Building in w2.buildings.values():
		if b is CollectionPoint:
			p2 = b
	assert_true(p2 != null)
	assert_eq(p2.store, {"chrome": 7})
	assert_eq(w2.couriers.size(), 1)
	assert_true(w2.courier_cooldown > 0)


func _site_world() -> SimWorld:
	var w := TestWorlds.make(60, 30)
	MapLoader.apply(w, {"width": 60, "height": 30, "seed": 2, "zone_order": ["a", "b"], "unlock_cleanliness": 0.5,
		"player_start": {"x": 5, "y": 15}, "ship": {"x": 2, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 30, "h": 30, "site": {"x": 12, "y": 20}},
			{"id": "b", "name": "B", "x": 30, "y": 0, "w": 30, "h": 30, "site": {"x": 40, "y": 20}}],
		"nodes": []})
	w.unlocked_features["collection"] = true
	w.bolts = 2000
	return w


func test_point_only_on_fixed_site() -> void:
	var w := _site_world()
	var failed := []
	w.place_failed.connect(func(r: String) -> void: failed.append(r))
	w.player.pos = Vector2i(8, 24) * 64
	w.queue_command({"type": "place", "def_id": "collection_point", "tile": Vector2i(8, 20), "rot": 0})
	w.tick()
	assert_eq(failed, ["site"], "frei platzieren geht nicht mehr")


func test_a_at_site_builds_point() -> void:
	var w := _site_world()
	assert_eq(NetworkSystem.site_near_player(w), "", "weit weg: kein Bauplatz")
	w.player.pos = Vector2i(12, 20) * 64 + Vector2i(64, 64 + 90)
	assert_eq(NetworkSystem.site_near_player(w), "a")
	w.queue_command({"type": "build_point", "zone": "a"})
	w.tick()
	assert_eq(NetworkSystem.points(w).size(), 1)
	assert_eq(NetworkSystem.points(w)[0].tile, Vector2i(12, 20))
	assert_eq(NetworkSystem.site_near_player(w), "", "Bauplatz belegt")
	assert_true(w.bolts < 2000, "kostet Bolts")
