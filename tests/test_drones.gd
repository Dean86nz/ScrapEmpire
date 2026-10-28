extends TestCase
## Sammel-Drohnen: Bau am Schiff, fliegen zu losen Teilen und Haufen, liefern ans Schiff ab.


func _world() -> SimWorld:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w, Vector2i(2, 2))
	return w


func _unlock(w: SimWorld) -> void:
	w.unlocked_features["drones"] = true


func test_buy_requires_blueprint_and_bolts() -> void:
	var w := _world()
	var fails := []
	w.drone_failed.connect(func(r: String) -> void: fails.append(r))
	w.queue_command({"type": "buy_drone"})
	w.tick()
	assert_eq(fails, ["locked"])
	_unlock(w)
	w.queue_command({"type": "buy_drone"})
	w.tick()
	assert_eq(fails, ["locked", "bolts"])
	w.bolts = 400
	w.queue_command({"type": "buy_drone"})
	w.tick()
	assert_eq(w.drones.size(), 1)
	assert_eq(w.bolts, 0)
	var d: Drone = w.drones.values()[0]
	assert_eq(d.pos, w.ship().center_px(), "startet am Schiff")


func test_cost_curve_and_max() -> void:
	var w := _world()
	_unlock(w)
	assert_eq(w.next_drone_cost(), {"bolts": 400})
	w.add_drone()
	assert_eq(w.next_drone_cost()["bolts"], 600)
	for i in int(w.drone_cfg["max_drones"]) - 1:
		w.add_drone()
	w.bolts = 1000000
	assert_eq(w.can_buy_drone(), "max")


func test_drone_collects_loose_items_and_delivers() -> void:
	var w := _world()
	_unlock(w)
	var d := w.add_drone()
	var n := d.capacity + 2
	for i in n:
		w.add_loose("copper", Vector2i(12 * 64 + (i % 10) * 10, 10 * 64 + (i / 10) * 10))
	assert_eq(d.capacity, int(w.drone_cfg["base_capacity"]))
	TestWorlds.run(w, 20 * 40)
	assert_eq(w.loose.size(), 0, "alle losen Teile eingesammelt")
	assert_eq(w.bolts, n * 3, "Kupfer à 3 Bolts am Schiff")
	assert_true(d.trips >= 2, "mehr als eine Ladung: mindestens zwei Flüge (%d)" % d.trips)


func test_drone_takes_from_piles_when_no_loose_items() -> void:
	var w := _world()
	_unlock(w)
	var pile := w.add_pile("scrap_pile", Vector2i(12, 12), 10)
	w.add_drone()
	TestWorlds.run(w, 20 * 20)
	assert_true(pile.amount < 10, "vom Haufen gesaugt")
	assert_true(w.bolts > 0)


func test_drone_ignores_hard_objects_and_locked_zones() -> void:
	var w := TestWorlds.make()
	MapLoader.apply(w, {"width": 40, "height": 30, "zone_order": ["a", "b"],
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 20, "h": 30}, {"id": "b", "name": "B", "x": 20, "y": 0, "w": 20, "h": 30}],
		"nodes": [{"kind": "cart", "x": 8, "y": 8}, {"kind": "scrap_pile", "x": 25, "y": 5, "amount": 10}]})
	TestWorlds.with_ship(w, Vector2i(2, 2))
	_unlock(w)
	w.add_loose("scrap", Vector2i(26 * 64, 6 * 64))
	var d := w.add_drone()
	TestWorlds.run(w, 20 * 20)
	assert_eq(w.loose.size(), 1, "loses Teil in gesperrter Zone bleibt liegen")
	assert_eq(d.state, Drone.State.IDLE, "nichts zu tun")
	for n: ResourceNode in w.nodes.values():
		if n.kind == "cart":
			assert_eq(n.amount, 20, "Einkaufswagen (Stufe 2) bleibt")


func test_two_drones_do_not_chase_the_same_item() -> void:
	var w := _world()
	_unlock(w)
	w.add_loose("scrap", Vector2i(12 * 64, 10 * 64))
	w.add_loose("scrap", Vector2i(12 * 64, 14 * 64))
	var a := w.add_drone()
	var b := w.add_drone()
	w.tick()
	assert_true(a.target_loose != b.target_loose, "unterschiedliche Ziele")


func test_upgrades_change_speed_and_capacity() -> void:
	var w := _world()
	_unlock(w)
	var d := w.add_drone()
	var base_speed := d.speed_px_per_tick
	w.bolts = 10000
	w.queue_command({"type": "buy_drone_upgrade", "id": "drone_capacity"})
	w.queue_command({"type": "buy_drone_upgrade", "id": "drone_speed"})
	w.tick()
	assert_eq(int(w.drone_upgrades.get("drone_capacity", 0)), 1)
	assert_eq(d.capacity, int(w.drone_cfg["base_capacity"]) + 4)
	assert_true(d.speed_px_per_tick > base_speed)
	assert_eq(w.bolts, 10000 - 600 - 400)


func test_remove_drops_cargo() -> void:
	var w := _world()
	_unlock(w)
	var d := w.add_drone()
	d.carry = {"scrap": 3}
	w.queue_command({"type": "remove_drone", "id": d.id})
	w.tick()
	assert_eq(w.drones.size(), 0)
	assert_eq(w.loose.size(), 3)


func test_save_roundtrip() -> void:
	var w := _world()
	_unlock(w)
	var d := w.add_drone()
	d.carry = {"copper": 2}
	d.trips = 5
	w.drone_upgrades["drone_speed"] = 1
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	var w2 := TestWorlds.make()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.drones.size(), 1)
	var d2: Drone = w2.drones.values()[0]
	assert_eq(d2.carry, {"copper": 2})
	assert_eq(d2.trips, 5)
	assert_eq(d2.state, Drone.State.RETURN, "mit Ladung zurück zum Schiff")
