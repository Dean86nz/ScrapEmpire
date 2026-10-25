extends TestCase


func _world() -> SimWorld:
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.player.pos = Vector2i(320, 320)
	return w


func _machine(w: SimWorld, def_id: String, tile: Vector2i = Vector2i(7, 5)) -> Machine:
	var m: Machine = Building.create(w.next_id(), w.defs[def_id], tile, 0)
	m.recipes = w.available_recipes(def_id)
	return m


func test_recipes_load() -> void:
	var r := RecipeDef.load_all("res://data/recipes.json")
	assert_eq(r.size(), 5)
	assert_eq(r[0].id, "iron_bar")
	assert_eq(r[0].inputs, {"scrap": 3})
	assert_eq(r[0].ticks, 80)
	assert_eq(r[3].tech, "gear")


func test_furnace_accepts_only_inputs_up_to_10() -> void:
	var w := _world()
	var f := _machine(w, "furnace")
	assert_eq(f.accept_stack("scrap", 20), 10)
	assert_eq(f.accept_stack("scrap", 5), 0, "Eingang je Item voll")
	assert_eq(f.accept_stack("plastic", 5), 0, "Ofen kennt kein Plastik")
	assert_eq(f.accept_stack("copper", 4), 4)


func test_furnace_makes_iron_bar_after_80_ticks() -> void:
	var w := _world()
	var f := _machine(w, "furnace")
	f.accept_stack("scrap", 3)
	assert_true(f.tick(), "Start verbraucht Inputs")
	assert_eq(f.input.get("scrap", 0), 0)
	assert_true(f.progress_fraction() < 0.05)
	for i in 79:
		f.tick()
	assert_eq(f.output.get("iron_bar", 0), 0)
	assert_true(f.tick(), "80 Ticks nach dem Start fertig")
	assert_eq(f.output.get("iron_bar", 0), 1)
	assert_true(f.is_idle())


func test_furnace_picks_copper_recipe() -> void:
	var w := _world()
	var f := _machine(w, "furnace")
	f.accept_stack("copper", 2)
	for i in 81:
		f.tick()
	assert_eq(f.output.get("copper_bar", 0), 1)


func test_blocked_when_output_full() -> void:
	var w := _world()
	var f := _machine(w, "furnace")
	f.output["iron_bar"] = 10
	f.accept_stack("scrap", 3)
	assert_true(f.is_blocked())
	assert_false(f.tick())
	assert_eq(f.input.get("scrap", 0), 3, "nichts verbraucht")
	f.withdraw_stack()
	assert_false(f.is_blocked())
	assert_true(f.tick())


func test_gear_requires_tech() -> void:
	var w := _world()
	var p := _machine(w, "press")
	assert_false(p.accepts_item("iron_bar"), "Zahnrad ohne Tech gesperrt")
	w.unlocked_tech["gear"] = true
	p.recipes = w.available_recipes("press")
	assert_true(p.accepts_item("iron_bar"))
	p.accept_stack("iron_bar", 2)
	for i in 101:
		p.tick()
	assert_eq(p.output.get("gear", 0), 1)


func test_circuit_needs_both_inputs() -> void:
	var w := _world()
	w.unlocked_tech["circuit"] = true
	var p := _machine(w, "press")
	p.accept_stack("copper_bar", 1)
	assert_true(p.is_idle())
	assert_false(p.tick())
	p.accept_stack("plastic_sheet", 1)
	assert_true(p.tick())
	for i in 120:
		p.tick()
	assert_eq(p.output.get("circuit", 0), 1)


func test_withdraw_output_first_then_input() -> void:
	var w := _world()
	var f := _machine(w, "furnace")
	f.accept_stack("scrap", 2)
	f.output["iron_bar"] = 3
	assert_eq(f.withdraw_stack(), {"item": "iron_bar", "count": 3})
	assert_eq(f.withdraw_stack(), {"item": "scrap", "count": 2})
	assert_eq(f.withdraw_stack(), {})
	assert_eq(f.contents(), {})


func test_world_deposit_and_sell_bar() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 100)
	w.player.inventory.add("copper", 10)
	w.queue_command({"type": "place", "def_id": "furnace", "tile": Vector2i(7, 5)})
	w.tick()
	assert_eq(w.buildings.size(), 1)
	var f: Machine = w.buildings.values()[0]
	assert_eq(f.recipes.size(), 2)
	# Schrott liegt nach dem Bezahlen (100-40=60) in Slot 0..2; Slot 0 hat 20.
	w.queue_command({"type": "deposit", "tile": Vector2i(7, 5), "slot": 0})
	w.tick()
	assert_eq(f.input.get("scrap", 0), 7, "max 10 angenommen, 3 sofort im selben Tick verbraucht")
	assert_eq(w.player.inventory.count_of("scrap"), 50)
	for i in 82:
		w.tick()
	assert_eq(f.output.get("iron_bar", 0), 1)
	w.player.inventory.add("scrap", 0)
	# Terminal bauen und Barren verkaufen
	w.queue_command({"type": "place", "def_id": "sell_terminal", "tile": Vector2i(7, 8)})
	w.tick()
	w.queue_command({"type": "withdraw", "tile": Vector2i(7, 5)})
	w.tick()
	assert_eq(w.player.inventory.count_of("iron_bar"), 1)
	var slot := -1
	for i in w.player.inventory.slots.size():
		if w.player.inventory.slots[i]["item"] == "iron_bar":
			slot = i
	w.queue_command({"type": "deposit", "tile": Vector2i(7, 8), "slot": slot})
	w.tick()
	assert_eq(w.bolts, 6)


func test_world_rejects_wrong_item() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 60)
	w.player.inventory.add("copper", 10)
	w.player.inventory.add("plastic", 5)
	w.queue_command({"type": "place", "def_id": "furnace", "tile": Vector2i(7, 5)})
	w.tick()
	var rejected := []
	w.deposit_rejected.connect(func(_b: Building, item: String) -> void: rejected.append(item))
	var slot := -1
	for i in w.player.inventory.slots.size():
		if w.player.inventory.slots[i]["item"] == "plastic":
			slot = i
	w.queue_command({"type": "deposit", "tile": Vector2i(7, 5), "slot": slot})
	w.tick()
	assert_eq(rejected, ["plastic"])
	assert_eq(w.player.inventory.count_of("plastic"), 5)
