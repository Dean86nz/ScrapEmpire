extends TestCase

const P := Vector2i(320, 320)


func _world() -> SimWorld:
	var w := SimWorld.new()
	w.player.pos = P
	w.player.aim = Vector2.RIGHT
	return w


func _hold_suck(w: SimWorld, ticks: int) -> void:
	w.player.suck_held = true
	for i in ticks:
		w.tick()
	w.player.suck_held = false


func test_pile_in_cone_is_sucked() -> void:
	var w := _world()
	var pile := w.add_pile("scrap_pile", Vector2i(6, 5), 5)  # Mitte (416, 352): rechts vorne
	_hold_suck(w, 1)
	assert_eq(pile.amount, 4)
	assert_eq(w.player.inventory.count_of("scrap"), 1)


func test_pile_behind_player_is_not_sucked() -> void:
	var w := _world()
	var pile := w.add_pile("scrap_pile", Vector2i(3, 5), 5)  # Mitte (224, 352): links hinten
	_hold_suck(w, 10)
	assert_eq(pile.amount, 5)


func test_pile_out_of_range_is_not_sucked() -> void:
	var w := _world()
	var pile := w.add_pile("scrap_pile", Vector2i(9, 5), 5)  # Mitte (608, 352): 290 px weit
	_hold_suck(w, 10)
	assert_eq(pile.amount, 5)


func test_suction_rate_one_item_per_5_ticks() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(6, 5), 10)
	_hold_suck(w, 5)
	assert_eq(w.player.inventory.count_of("scrap"), 1)
	_hold_suck(w, 5)
	assert_eq(w.player.inventory.count_of("scrap"), 2)


func test_full_inventory_notifies_once_and_leaves_pile() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 120)
	var pile := w.add_pile("copper_tangle", Vector2i(6, 5), 5)
	var calls := [0]
	w.inventory_full.connect(func() -> void: calls[0] += 1)
	_hold_suck(w, 30)
	assert_eq(calls[0], 1)
	assert_eq(pile.amount, 5)


func test_full_notification_resets_after_inventory_changes() -> void:
	var w := _world()
	w.player.inventory.add("scrap", 120)
	w.add_pile("copper_tangle", Vector2i(6, 5), 5)
	var calls := [0]
	w.inventory_full.connect(func() -> void: calls[0] += 1)
	_hold_suck(w, 5)
	w.player.inventory.remove("scrap", 20)
	w.player.inventory.add("plastic", 20)  # wieder voll, aber Inventar hat sich geändert
	_hold_suck(w, 5)
	assert_eq(calls[0], 2)


func test_loose_item_preferred_over_pile() -> void:
	var w := _world()
	var pile := w.add_pile("scrap_pile", Vector2i(6, 5), 5)
	w.add_loose("copper", Vector2i(400, 330))
	_hold_suck(w, 1)
	assert_eq(w.loose.size(), 0)
	assert_eq(pile.amount, 5)
	assert_eq(w.player.inventory.count_of("copper"), 1)


func test_item_collected_signal_carries_origin() -> void:
	var w := _world()
	var pile := w.add_pile("plastic_crumbs", Vector2i(6, 5), 5)
	var got := []
	w.item_collected.connect(func(id: String, from: Vector2i) -> void: got.append([id, from]))
	_hold_suck(w, 1)
	assert_eq(got.size(), 1)
	assert_eq(got[0][0], "plastic")
	assert_eq(got[0][1], pile.center_px())


func test_hammer_hits_wreck_and_spawns_loose_item() -> void:
	var w := _world()
	w.player.pos = Vector2i(300, 352)
	var wreck := w.add_wreck(Vector2i(5, 5), {"scrap": 3, "copper": 1})  # Mitte (352, 352)
	var hits := [0]
	w.wreck_hit.connect(func(_n: ResourceNode) -> void: hits[0] += 1)
	w.player.hammer_pressed = true
	w.tick()
	assert_eq(hits[0], 1)
	assert_eq(wreck.amount, 3)
	assert_eq(w.loose.size(), 1)
	var item: LooseItem = w.loose.values()[0]
	assert_eq(item.item_id, "scrap")
	var off: Vector2i = item.pos - wreck.center_px()
	assert_true(absi(off.x) <= SimWorld.LOOT_SCATTER_PX and absi(off.y) <= SimWorld.LOOT_SCATTER_PX, "Streuung zu groß")
	assert_false(w.player.hammer_pressed, "hammer_pressed wird pro Tick verbraucht")


func test_hammer_cooldown_blocks_second_hit() -> void:
	var w := _world()
	w.player.pos = Vector2i(300, 352)
	var wreck := w.add_wreck(Vector2i(5, 5), {"scrap": 5})
	var per := ResourceNode.items_per_hit(wreck, w.player.hammer_tier)
	for i in 10:
		w.player.hammer_pressed = true
		w.tick()
	assert_eq(wreck.amount, 5 - per, "innerhalb von 10 Ticks nur ein Schlag")
	w.player.hammer_pressed = true
	w.tick()
	assert_eq(wreck.amount, maxi(0, 5 - 2 * per))


func test_hammer_out_of_range_does_nothing() -> void:
	var w := _world()
	w.player.pos = Vector2i(100, 352)
	var wreck := w.add_wreck(Vector2i(5, 5), {"scrap": 5})
	w.player.hammer_pressed = true
	w.tick()
	assert_eq(wreck.amount, 5)
	assert_eq(w.loose.size(), 0)


func test_hammer_ignores_piles() -> void:
	var w := _world()
	w.player.pos = Vector2i(300, 352)
	var pile := w.add_pile("scrap_pile", Vector2i(5, 5), 5)
	w.player.hammer_pressed = true
	w.tick()
	assert_eq(pile.amount, 5)


func test_wreck_destroyed_when_empty() -> void:
	var w := _world()
	w.player.pos = Vector2i(300, 352)
	var wreck := w.add_wreck(Vector2i(5, 5), {"copper": 1})
	var destroyed := []
	w.wreck_destroyed.connect(func(id: int) -> void: destroyed.append(id))
	var removed := []
	w.node_removed.connect(func(id: int) -> void: removed.append(id))
	w.player.hammer_pressed = true
	w.tick()
	assert_eq(destroyed, [wreck.id])
	assert_eq(removed, [wreck.id])
	assert_false(w.nodes.has(wreck.id))
	assert_eq(w.loose.size(), 1)


func test_empty_pile_vanishes_without_counting_as_wreck() -> void:
	var w := _world()
	var pile := w.add_pile("scrap_pile", Vector2i(6, 5), 2)
	var removed := []
	var wrecks := []
	w.node_removed.connect(func(id: int) -> void: removed.append(id))
	w.wreck_destroyed.connect(func(id: int) -> void: wrecks.append(id))
	w.player.suck_held = true
	for i in 40:
		w.tick()
	assert_eq(removed, [pile.id], "leerer Haufen verschwindet")
	assert_eq(wrecks, [], "zählt nicht als zerlegtes Müllteil")
	assert_false(w.nodes.has(pile.id))
