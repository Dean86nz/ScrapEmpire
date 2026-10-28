extends TestCase


func test_piles_are_finite_since_ms30() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var n := ResourceNode.make_pile(1, "scrap_pile", Vector2i(3, 4), 5)
	for i in 2000:
		assert_false(n.tick(), "Haufen wachsen nicht mehr nach")
	assert_eq(n.amount, 5)
	assert_false(n.is_resource(), "Haufen sind Müll")
	for i in 5:
		n.take_one()
	assert_true(n.is_used_up(), "leer = verschwindet")


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


func test_hammer_hits_drop_with_tool_tier() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var n := ResourceNode.new()
	n.kind = "toaster"
	n.tier = 2
	n.max_amount = 20
	n.amount = 20
	var base := ResourceNode.hits_needed(n, 2)
	assert_eq(base, 5, "3 + 1 × Stufe 2")
	assert_eq(ResourceNode.hits_needed(n, 3), 2, "eine Stufe drüber: 40 %, aufgerundet")
	assert_eq(ResourceNode.hits_needed(n, 4), 1, "zwei Stufen drüber: ein Schlag")
	assert_eq(ResourceNode.items_per_hit(n, 4), 20)
	assert_eq(ResourceNode.items_per_hit(n, 2), 4)
	n.boss = true
	assert_eq(ResourceNode.hits_needed(n, 5), 30, "Bosse: feste Schlagzahl")
