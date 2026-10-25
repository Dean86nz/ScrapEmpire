extends TestCase


func _def(id: String, size: Vector2i) -> BuildingDef:
	var d := BuildingDef.new()
	d.id = id
	d.size = size
	return d


func test_bounds() -> void:
	var g := Grid.new(10, 8)
	assert_true(g.in_bounds(Vector2i(0, 0)))
	assert_true(g.in_bounds(Vector2i(9, 7)))
	assert_false(g.in_bounds(Vector2i(10, 7)))
	assert_false(g.in_bounds(Vector2i(-1, 0)))
	assert_false(g.can_place(Vector2i(9, 7), Vector2i(2, 2)), "2×2 ragt über den Rand")


func test_footprint_and_overlap() -> void:
	var g := Grid.new(10, 10)
	var b := Building.create(1, _def("x", Vector2i(2, 2)), Vector2i(3, 3), 0)
	assert_eq(b.cells().size(), 4)
	g.place(b)
	assert_eq(g.occupied_count(), 4)
	assert_eq(g.at(Vector2i(4, 4)), b)
	assert_false(g.can_place(Vector2i(4, 4), Vector2i(1, 1)), "überlappt")
	assert_true(g.can_place(Vector2i(5, 3), Vector2i(1, 1)))
	g.remove(b)
	assert_eq(g.occupied_count(), 0)


func test_blocked_callable() -> void:
	var g := Grid.new(10, 10)
	var blocked := func(t: Vector2i) -> bool: return t == Vector2i(2, 2)
	assert_false(g.can_place(Vector2i(1, 1), Vector2i(2, 2), blocked))
	assert_true(g.can_place(Vector2i(3, 3), Vector2i(2, 2), blocked))


func test_rotation_swaps_size() -> void:
	var d := _def("x", Vector2i(3, 1))
	var b := Building.create(1, d, Vector2i.ZERO, 1)
	assert_eq(b.size(), Vector2i(1, 3))
	assert_eq(b.center_px(), Vector2i(32, 96))
