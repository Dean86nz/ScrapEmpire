extends TestCase

const P := Vector2i(320, 320)  # Kachel (5,5)


func _world() -> SimWorld:
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.player.pos = P
	w.player.aim = Vector2.RIGHT
	return w


func _place(w: SimWorld, def_id: String, tile: Vector2i, rot: int = 0) -> void:
	w.queue_command({"type": "place", "def_id": def_id, "tile": tile, "rot": rot})
	w.tick()


func test_place_pays_and_occupies() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 50)
	_place(w, "sell_terminal", Vector2i(7, 5))
	assert_eq(w.buildings.size(), 1)
	assert_eq(w.player.inventory.count_of("scrap"), 20)
	assert_eq(w.grid.occupied_count(), 4)
	var b: Building = w.buildings.values()[0]
	assert_eq(b.paid_cost, {"scrap": 30})
	assert_true(b is SellTerminal)


func test_place_fails_without_resources() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 10)
	var reasons := []
	w.place_failed.connect(func(r: String) -> void: reasons.append(r))
	_place(w, "sell_terminal", Vector2i(7, 5))
	assert_eq(reasons, ["cost"])
	assert_eq(w.buildings.size(), 0)
	assert_eq(w.player.inventory.count_of("scrap"), 10)


func test_place_fails_on_resource_node_and_player() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 100)
	w.add_pile("scrap_pile", Vector2i(8, 6), 5)
	var reasons := []
	w.place_failed.connect(func(r: String) -> void: reasons.append(r))
	_place(w, "sell_terminal", Vector2i(7, 5))  # deckt (8,6) ab
	_place(w, "chest", Vector2i(5, 5))          # unter Rusty
	assert_eq(reasons, ["blocked", "blocked"])
	assert_eq(w.buildings.size(), 0)


func test_place_fails_out_of_range() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 100)
	var reasons := []
	w.place_failed.connect(func(r: String) -> void: reasons.append(r))
	_place(w, "chest", Vector2i(12, 5))  # 7 Kacheln weit
	assert_eq(reasons, ["range"])
	_place(w, "chest", Vector2i(11, 5))  # 6 Kacheln: ok
	assert_eq(w.buildings.size(), 1)


func test_second_terminal_costs_more() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 100)
	assert_eq(w.next_cost(w.defs["sell_terminal"])["scrap"], 30)
	_place(w, "sell_terminal", Vector2i(7, 5))
	assert_eq(w.next_cost(w.defs["sell_terminal"])["scrap"], 40)
	_place(w, "sell_terminal", Vector2i(7, 8))
	assert_eq(w.player.inventory.count_of("scrap"), 30)


func test_remove_refunds() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 30)
	_place(w, "sell_terminal", Vector2i(7, 5))
	assert_eq(w.player.inventory.count_of("scrap"), 0)
	var removed := []
	w.building_removed.connect(func(id: int) -> void: removed.append(id))
	w.queue_command({"type": "remove", "tile": Vector2i(8, 6)})
	w.tick()
	assert_eq(removed.size(), 1)
	assert_eq(w.buildings.size(), 0)
	assert_eq(w.grid.occupied_count(), 0)
	assert_eq(w.player.inventory.count_of("scrap"), 30)


func test_remove_drops_contents_when_inventory_full() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 10)
	_place(w, "chest", Vector2i(7, 5))
	w.player.inventory.add("copper", 120)  # Inventar voll
	var chest: Chest = w.buildings.values()[0]
	chest.accept_stack("plastic", 5)
	w.queue_command({"type": "remove", "tile": Vector2i(7, 5)})
	w.tick()
	assert_eq(w.loose.size(), 15, "10 Schrott Erstattung + 5 Plastik Inhalt als lose Items")


func test_deposit_and_sell() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 50)
	_place(w, "sell_terminal", Vector2i(7, 5))
	var bolts := []
	w.bolts_changed.connect(func(v: int) -> void: bolts.append(v))
	var sold := []
	w.item_sold.connect(func(id: String, v: int, _pos: Vector2i) -> void: sold.append([id, v]))
	w.queue_command({"type": "deposit", "tile": Vector2i(7, 5), "slot": 0})
	w.tick()
	assert_eq(w.player.inventory.count_of("scrap"), 0, "ganzer Stack (20) eingelegt")
	assert_eq(w.bolts, 1, "erstes Item sofort verkauft")
	for i in 199:
		w.tick()
	assert_eq(w.bolts, 20)
	assert_eq(sold.size(), 20)
	assert_eq(sold[0], ["scrap", 1])
	assert_eq(bolts.back(), 20)


func test_deposit_copper_worth_3() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 30)
	w.player.inventory.add("copper", 2)
	_place(w, "sell_terminal", Vector2i(7, 5))
	# Bezahlen leert Slot 0 und 1 (Schrott); Kupfer liegt in Slot 2.
	w.queue_command({"type": "deposit", "tile": Vector2i(8, 6), "slot": 2})
	w.tick()
	for i in 20:
		w.tick()
	assert_eq(w.bolts, 6)


func test_chest_deposit_withdraw_roundtrip() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 10)
	w.player.inventory.add("plastic", 7)
	_place(w, "chest", Vector2i(7, 5))
	# Bezahlen leert Slot 0 (Schrott); Plastik liegt in Slot 1.
	w.queue_command({"type": "deposit", "tile": Vector2i(7, 5), "slot": 1})
	w.tick()
	assert_eq(w.player.inventory.count_of("plastic"), 0)
	var chest: Chest = w.buildings.values()[0]
	assert_eq(chest.contents(), {"plastic": 7})
	w.queue_command({"type": "withdraw", "tile": Vector2i(7, 5)})
	w.tick()
	assert_eq(w.player.inventory.count_of("plastic"), 7)
	assert_eq(chest.contents(), {})


func test_building_near() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 50)
	_place(w, "sell_terminal", Vector2i(7, 5))  # Rechteck px (448..576, 320..448)
	assert_true(w.building_near(Vector2i(420, 330), 48) != null, "28 px links vom Rand")
	assert_true(w.building_near(Vector2i(380, 330), 48) == null, "68 px entfernt")
	assert_true(w.building_near(Vector2i(500, 400), 48) != null, "innen")
