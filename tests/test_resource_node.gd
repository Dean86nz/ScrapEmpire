extends TestCase


func test_pile_regenerates_after_600_ticks() -> void:
	var n := ResourceNode.make_pile(1, "scrap_pile", Vector2i(3, 4), 5)
	var changed := false
	for i in 599:
		changed = n.tick() or changed
	assert_false(changed, "vor Tick 600 keine Änderung")
	assert_true(n.tick(), "bei Tick 600 +1")
	assert_eq(n.amount, 6)


func test_pile_stops_at_max() -> void:
	var n := ResourceNode.make_pile(1, "copper_tangle", Vector2i.ZERO, 10)
	for i in 2000:
		n.tick()
	assert_eq(n.amount, 10)


func test_pile_take_one() -> void:
	var n := ResourceNode.make_pile(1, "plastic_crumbs", Vector2i.ZERO, 2)
	assert_eq(n.take_one(), "plastic")
	assert_eq(n.take_one(), "plastic")
	assert_eq(n.take_one(), "")
	assert_true(n.is_depleted())


func test_wreck_never_regenerates() -> void:
	var w := ResourceNode.make_wreck(2, Vector2i(1, 1), {"scrap": 1})
	w.take_one()
	for i in 2000:
		w.tick()
	assert_eq(w.amount, 0)


func test_wreck_take_order_largest_first() -> void:
	var w := ResourceNode.make_wreck(2, Vector2i(1, 1), {"scrap": 3, "copper": 1, "plastic": 2})
	assert_eq(w.amount, 6)
	var got: Array[String] = []
	for i in 7:
		got.append(w.take_one())
	# Größte Restmenge zuerst, bei Gleichstand alphabetisch: ergibt gemischte Ausbeute.
	assert_eq(got, ["scrap", "plastic", "scrap", "copper", "plastic", "scrap", ""] as Array[String])
	assert_true(w.is_depleted())


func test_center_px() -> void:
	var n := ResourceNode.make_pile(1, "scrap_pile", Vector2i(2, 3), 1)
	assert_eq(n.center_px(), Vector2i(160, 224))


func test_rng_same_seed_same_sequence() -> void:
	var a := SimRng.new(42)
	var b := SimRng.new(42)
	for i in 10:
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000))


func test_rng_state_roundtrip() -> void:
	var a := SimRng.new(7)
	a.randi_range(0, 100)
	var state := a.get_state()
	var next := a.randi_range(0, 100)
	var b := SimRng.new(0)
	b.set_state(state)
	assert_eq(b.randi_range(0, 100), next)
