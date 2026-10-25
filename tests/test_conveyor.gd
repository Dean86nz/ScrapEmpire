extends TestCase

const R := 0  # rechts
const D := 1  # unten
const L := 2  # links
const U := 3  # oben


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.player.pos = Vector2i(32, 32)  # Kachel (0,0), weit weg vom Geschehen
	return w


func _belt(w: SimWorld, x: int, y: int, rot: int) -> Conveyor:
	return w.place_free("conveyor", Vector2i(x, y), rot) as Conveyor


func test_item_moves_26_per_tick_and_stops_at_end() -> void:
	var w := _world()
	var c := _belt(w, 5, 5, R)
	assert_true(c.try_insert("scrap", 0))
	w.tick()
	assert_eq(c.items[0]["offset"], 26)
	for i in 20:
		w.tick()
	assert_eq(c.items[0]["offset"], 255, "ohne Ziel bleibt das Item am Ende stehen")
	assert_eq(c.items.size(), 1)


func test_spacing_is_enforced() -> void:
	var w := _world()
	var c := _belt(w, 5, 5, R)
	assert_true(c.try_insert("scrap", 0))
	assert_false(c.try_insert("scrap", 30), "zu nah am ersten Item")
	assert_true(c.try_insert("scrap", 64))
	assert_eq(c.items[0]["offset"], 64, "vorderstes zuerst")
	for i in 30:
		w.tick()
	assert_eq(c.items[0]["offset"], 255)
	assert_eq(c.items[1]["offset"], 191, "Nachfolger hält 64 Abstand")


func test_capacity_four_per_tile() -> void:
	var w := _world()
	var c := _belt(w, 5, 5, R)
	var n := 0
	for off in [0, 64, 128, 192, 255]:
		if c.try_insert("scrap", off):
			n += 1
	assert_eq(n, 4)


func test_transfer_belt_to_belt() -> void:
	var w := _world()
	var a := _belt(w, 5, 5, R)
	var b := _belt(w, 6, 5, R)
	a.try_insert("scrap", 200)
	for i in 3:
		w.tick()
	assert_eq(a.items.size(), 0)
	assert_eq(b.items.size(), 1)
	assert_true(int(b.items[0]["offset"]) < 64)


func test_blocked_when_next_belt_full() -> void:
	var w := _world()
	var a := _belt(w, 5, 5, R)
	var b := _belt(w, 6, 5, R)
	var c := _belt(w, 7, 5, D)  # endet im Nichts: (7,6) leer → staut
	for off in [0, 64, 128, 192]:
		c.try_insert("scrap", off)
	for off in [0, 64, 128, 192]:
		b.try_insert("scrap", off)
	a.try_insert("scrap", 100)
	for i in 40:
		w.tick()
	assert_eq(a.items.size(), 1, "kann nicht übergeben")
	assert_eq(a.items[0]["offset"], 255)
	assert_eq(b.items.size(), 4)
	assert_eq(c.items.size(), 4)


func test_chain_of_three_keeps_gap() -> void:
	var w := _world()
	var a := _belt(w, 5, 5, R)
	_belt(w, 6, 5, R)
	var c := _belt(w, 7, 5, R)
	a.try_insert("scrap", 64)
	a.try_insert("copper", 0)
	for i in 30:
		w.tick()
	var middle: Conveyor = w.grid.at(Vector2i(6, 5))
	var total: int = a.items.size() + middle.items.size() + c.items.size()
	assert_eq(total, 2)
	# beide liegen jetzt auf c: Abstand bleibt 64
	assert_eq(c.items.size(), 2)
	assert_eq(c.items[0]["item"], "scrap")
	assert_eq(int(c.items[0]["offset"]) - int(c.items[1]["offset"]), 64)


func test_curve_detection() -> void:
	var w := _world()
	var a := _belt(w, 5, 5, R)   # zeigt auf (6,5)
	var b := _belt(w, 6, 5, D)   # läuft nach unten; a kommt von links = von b aus gesehen „links der Laufrichtung“? Laufrichtung unten: left_dir = (1,0)*? prüfen
	w.tick()
	assert_true(b.shape != Conveyor.Shape.STRAIGHT, "einziger seitlicher Zulauf → Kurve")
	# a liegt bei b.tile + (-1,0); b.left_dir() bei rot D=(0,1) ist (1,0)... also rechts → TURN_FROM_RIGHT
	assert_eq(b.shape, Conveyor.Shape.TURN_FROM_RIGHT)
	a.try_insert("scrap", 240)
	w.tick()
	assert_eq(b.items.size(), 1)
	assert_true(int(b.items[0]["offset"]) < 64, "Kurve: Einspeisung am Anfang")


func test_side_load_at_middle_when_straight_feeder_exists() -> void:
	var w := _world()
	_belt(w, 5, 5, R)            # gerader Zulauf für b
	var b := _belt(w, 6, 5, R)
	var s := _belt(w, 6, 4, D)   # von oben seitlich
	w.tick()
	assert_eq(b.shape, Conveyor.Shape.STRAIGHT)
	s.try_insert("copper", 240)
	w.tick()
	assert_eq(b.items.size(), 1)
	assert_eq(b.items[0]["offset"], Conveyor.SIDE_OFFSET)


func test_belt_feeds_furnace_up_to_10() -> void:
	var w := _world()
	var f: Machine = w.place_free("furnace", Vector2i(8, 5), 0)  # Eingang links an (8,5): Band auf (7,5)
	var a := _belt(w, 7, 5, R)
	for i in 14:
		a.try_insert("scrap", 0)
		for j in 3:
			w.tick()
	for i in 60:
		w.tick()
	var in_input: int = f.input.get("scrap", 0)
	assert_true(in_input <= 10, "Eingang nie über 10, ist %d" % in_input)
	var batches: int = f.output.get("iron_bar", 0) + (1 if f.progress_ticks > 0 else 0)
	assert_eq(a.items.size() + in_input + 3 * batches, 14, "alle 14 Schrott sind auf Band, im Eingang oder verarbeitet")


func test_furnace_outputs_onto_belt() -> void:
	var w := _world()
	var f: Machine = w.place_free("furnace", Vector2i(8, 5), 0)  # Ausgang rechts an (9,5): Band auf (10,5)
	var out := _belt(w, 10, 5, R)
	f.accept_stack("scrap", 3)
	for i in 85:
		w.tick()
	assert_eq(out.items.size(), 1)
	assert_eq(out.items[0]["item"], "iron_bar")
	assert_eq(f.output.get("iron_bar", 0), 0)


func test_terminal_accepts_max_10_from_belt() -> void:
	var w := _world()
	var t: SellTerminal = w.place_free("sell_terminal", Vector2i(8, 5), 0)  # Eingang links (8,5)
	var a := _belt(w, 7, 5, R)
	var inserted := 0
	for i in 40:
		if a.try_insert("scrap", 0):
			inserted += 1
		w.tick()
		w.tick()
		w.tick()
	assert_true(w.bolts > 0)
	assert_true(t.buffer.size() <= 10)


func test_extractor_pulls_from_adjacent_pile() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(5, 5), 10)
	var e: Extractor = w.place_free("extractor", Vector2i(6, 5), R)
	for i in 60:
		w.tick()
	assert_eq(e.buffer.size(), 1)
	assert_eq(e.buffer[0], "scrap")
	assert_eq(w.nodes.values()[0].amount, 10, "Haufen bleibt voll (gräbt tiefer)")
	for i in 600:
		w.tick()
	assert_eq(e.buffer.size(), 5, "Puffer max 5 ohne Band")


func test_extractor_ignores_tier2_object() -> void:
	var w := _world()
	w.add_object("cart", Vector2i(5, 5))
	var e: Extractor = w.place_free("extractor", Vector2i(6, 5), R)
	for i in 200:
		w.tick()
	assert_eq(e.buffer.size(), 0)


func test_full_chain_makes_bolts() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(4, 5), 10)
	w.place_free("extractor", Vector2i(5, 5), R)      # Ausgang (6,5)
	_belt(w, 6, 5, R)
	_belt(w, 7, 5, R)
	w.place_free("furnace", Vector2i(8, 5), 0)        # Eingang (7,5)→(8,5), Ausgang (9,5)→(10,5)
	_belt(w, 10, 5, R)
	_belt(w, 11, 5, R)
	w.place_free("sell_terminal", Vector2i(12, 5), 0) # Eingang (11,5)→(12,5)
	for i in 20 * 60:
		w.tick()
	assert_true(w.bolts >= 12, "nach 60 s mindestens 2 Barren verkauft, hat %d" % w.bolts)


func test_rotate_command_and_player_deposit_on_belt() -> void:
	var w := _world()
	var c := _belt(w, 5, 5, R)
	w.queue_command({"type": "rotate", "tile": Vector2i(5, 5), "rot": D})
	w.tick()
	assert_eq(c.rot, D)
	assert_eq(c.accept_stack("scrap", 20), 1, "Spieler legt genau ein Item auf")
	assert_eq(c.withdraw_stack(), {"item": "scrap", "count": 1})


func test_ports_rotate_with_building() -> void:
	var w := _world()
	var f: Building = w.place_free("furnace", Vector2i(8, 5), 1)  # 90° im Uhrzeigersinn
	var ports := f.ports_world()
	var in_port: Dictionary = ports[0]
	var out_port: Dictionary = ports[1]
	assert_eq(in_port["side"], Vector2i(0, -1), "Eingang links → oben")
	assert_eq(out_port["side"], Vector2i(0, 1), "Ausgang rechts → unten")
	assert_eq(in_port["outside"], Vector2i(9, 4))
	assert_eq(out_port["outside"], Vector2i(9, 7))
