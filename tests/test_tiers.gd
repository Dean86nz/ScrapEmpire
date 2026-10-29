extends TestCase


func _world() -> SimWorld:
	ResourceNode.load_defs("res://tests/data/scrap_objects_test.json")  # feste Test-Objekte (Mechanik, nicht Balancing)
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.player.pos = Vector2i(320, 352)
	w.player.aim = Vector2.RIGHT
	return w


func test_defs_loaded() -> void:
	ResourceNode.load_defs("res://tests/data/scrap_objects_test.json")  # feste Test-Objekte (Mechanik, nicht Balancing)
	assert_true(ResourceNode.has_kind("toaster"))
	assert_true(ResourceNode.has_kind("monolith"))
	assert_eq(ResourceNode.defs.size(), 19, "16 Objekte + Müllsack + Meteor + eingebautes Wrack")
	var n := ResourceNode.from_kind(1, "fridge", Vector2i.ZERO)
	assert_eq(n.tier, 2)
	assert_true(n.uses_hammer())
	assert_eq(n.amount, 27)
	assert_eq(n.respawn_ticks, 0, "seit MS30 respawnt nichts")


func test_hammer_too_hard_for_tier2() -> void:
	var w := _world()
	var fridge := w.add_object("fridge", Vector2i(5, 5))  # Mitte (352, 352), 32 px vor Rusty
	var hard := []
	w.too_hard.connect(func(n: ResourceNode, tool: String) -> void: hard.append([n.kind, tool]))
	w.player.hammer_pressed = true
	w.tick()
	assert_eq(hard, [["fridge", "hammer"]])
	assert_eq(fridge.amount, 27)
	assert_eq(w.loose.size(), 0)


func test_hammer_works_with_tier2_tool() -> void:
	var w := _world()
	var fridge := w.add_object("fridge", Vector2i(5, 5))
	w.player.hammer_tier = 2
	w.player.hammer_pressed = true
	w.tick()
	var per := ResourceNode.items_per_hit(fridge, 2)
	assert_true(per > 1, "Hammer-Formel: mehrere Teile je Schlag (MS43)")
	assert_eq(fridge.amount, fridge.max_amount - per)
	# MS64: Beute als Bündel – je Item-Sorte ein Haufen, zusammen genau `per` Teile
	var total := 0
	for li: LooseItem in w.loose.values():
		total += li.count
	assert_eq(total, per)
	assert_true(w.loose.size() < per, "weniger Einzelteile als Teile")
	var item: LooseItem = w.loose.values()[0]
	assert_eq(item.tier, 2)


func test_too_hard_feedback_is_throttled() -> void:
	var w := _world()
	w.add_object("fridge", Vector2i(5, 5))
	var hard := [0]
	w.too_hard.connect(func(_n: ResourceNode, _t: String) -> void: hard[0] += 1)
	for i in 30:
		w.player.hammer_pressed = true
		w.tick()
	assert_eq(hard[0], 2, "ein Hinweis pro 20 Ticks (Hammer-Cooldown 10 ignoriert)")


func test_suction_skips_too_hard_and_reports() -> void:
	var w := _world()
	var cart := w.add_object("cart", Vector2i(6, 5))  # Tier 2 Saug-Objekt
	var hard := []
	w.too_hard.connect(func(n: ResourceNode, tool: String) -> void: hard.append([n.kind, tool]))
	w.player.suck_held = true
	for i in 5:
		w.tick()
	assert_eq(cart.amount, 20)
	assert_eq(hard, [["cart", "suction"]])
	w.player.suction_tier = 2
	w.tick()
	assert_eq(cart.amount, 19)
	assert_eq(w.player.inventory.total(), 1)


func test_suction_prefers_collectable_pile_over_hard_object() -> void:
	var w := _world()
	w.add_object("cart", Vector2i(6, 5))
	var pile := w.add_pile("scrap_pile", Vector2i(6, 6), 5)
	w.player.suck_held = true
	w.tick()
	assert_eq(pile.amount, 4)


func test_suction_loot_object_depletes_and_never_respawns() -> void:
	var w := _world()
	w.player.suction_tier = 3
	var sat := w.add_object("satellite", Vector2i(6, 5))  # 15 Items, Respawn 480 s
	var removed := []
	w.node_removed.connect(func(id: int) -> void: removed.append(id))
	w.player.suck_held = true
	for i in 15 * 5:
		w.tick()
	assert_eq(removed, [sat.id])
	assert_eq(w.player.inventory.count_of("chrome"), 3)
	assert_eq(w.respawns.size(), 0, "kein Nachwachsen")
	w.player.suck_held = false
	for i in 480 * 20:
		w.tick()
	assert_eq(w.nodes.size(), 0)


func test_hammer_object_is_gone_for_good() -> void:
	var w := _world()
	var toaster := w.add_object("toaster", Vector2i(5, 5))  # Tier 1, 10 Items
	for i in 10:
		for j in 10:
			w.player.hammer_pressed = true
			w.tick()
	assert_false(w.nodes.has(toaster.id))
	assert_eq(w.respawns.size(), 0, "seit MS30 kommt nichts zurück")
	for i in 3600:
		w.tick()
	assert_eq(w.nodes.size(), 0)


func test_monolith_never_respawns_and_is_too_hard() -> void:
	var w := _world()
	w.player.hammer_tier = 4
	var m := w.add_object("monolith", Vector2i(5, 5))
	w.player.hammer_pressed = true
	w.tick()
	assert_eq(m.amount, 3)
	assert_eq(m.respawn_ticks, 0)


func test_xp_scales_with_tier() -> void:
	var w := _world()
	w.player.suction_tier = 3
	w.add_object("satellite", Vector2i(6, 5))
	w.player.suck_held = true
	w.tick()
	assert_eq(w.progression.total_xp, 3)
