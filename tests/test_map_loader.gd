extends TestCase


func test_tutorial_map_loads() -> void:
	var w := SimWorld.new()
	var start := MapLoader.load_into(w, "res://data/maps/tutorial.json")
	assert_eq(w.width_tiles, 40)
	assert_eq(w.height_tiles, 30)
	assert_eq(w.nodes.size(), 13)
	assert_eq(start, Vector2i(20 * 64 + 32, 15 * 64 + 32))
	var wrecks := 0
	for n: ResourceNode in w.nodes.values():
		if n.is_wreck():
			wrecks += 1
	assert_eq(wrecks, 3)


func test_unknown_kind_is_skipped() -> void:
	var w := SimWorld.new()
	MapLoader.apply(w, {
		"width": 10, "height": 10,
		"nodes": [
			{"kind": "scrap_pile", "x": 1, "y": 1, "amount": 3},
			{"kind": "unicorn", "x": 2, "y": 2},
		],
	})
	assert_eq(w.nodes.size(), 1)


func test_default_start_is_center() -> void:
	var w := SimWorld.new()
	var start := MapLoader.apply(w, {"width": 10, "height": 8, "nodes": []})
	assert_eq(start, Vector2i(5 * 64 + 32, 4 * 64 + 32))


func test_wreck_loot_is_int() -> void:
	var w := SimWorld.new()
	MapLoader.apply(w, {"nodes": [{"kind": "wreck", "x": 0, "y": 0, "loot": {"scrap": 2.0}}]})
	var n: ResourceNode = w.nodes.values()[0]
	assert_eq(n.amount, 2)
	assert_eq(n.take_one(), "scrap")
