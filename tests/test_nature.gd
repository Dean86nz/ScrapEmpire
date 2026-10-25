extends TestCase


func _cfg() -> Dictionary:
	return {
		"decor": {
			"1": {"grass": 0.02},
			"2": {"grass": 0.05, "flower_yellow": 0.01},
			"3": {"grass": 0.07, "flower_yellow": 0.03, "bush": 0.01, "pond": 0.003},
		},
		"decor_size": {"pond": [2, 2]},
	}


func test_stage_zero_has_no_decor() -> void:
	var r := Rect2i(0, 0, 40, 30)
	assert_eq(NaturePlanner.plan(r, 0, 1, _cfg()).size(), 0)


func test_plan_is_deterministic() -> void:
	var r := Rect2i(40, 30, 40, 30)
	var a := NaturePlanner.plan(r, 3, 123, _cfg())
	var b := NaturePlanner.plan(r, 3, 123, _cfg())
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i]["kind"], b[i]["kind"])
		assert_eq(a[i]["tile"], b[i]["tile"])
	var c := NaturePlanner.plan(r, 3, 124, _cfg())
	var same := c.size() == a.size()
	if same:
		for i in a.size():
			if a[i]["tile"] != c[i]["tile"]:
				same = false
				break
	assert_true(not same, "anderer Seed → anderer Plan")


func test_more_decor_with_higher_stage() -> void:
	var r := Rect2i(0, 0, 40, 30)
	var s1 := NaturePlanner.plan(r, 1, 7, _cfg()).size()
	var s2 := NaturePlanner.plan(r, 2, 7, _cfg()).size()
	var s3 := NaturePlanner.plan(r, 3, 7, _cfg()).size()
	assert_true(s1 > 0 and s1 < s2 and s2 < s3, "Stufen: %d < %d < %d" % [s1, s2, s3])


func test_decor_stays_inside_and_avoids_occupied_and_border() -> void:
	var r := Rect2i(10, 20, 20, 15)
	var occupied := {}
	for x in range(10, 30):
		occupied[Vector2i(x, 27)] = true  # eine belegte Zeile
	var plan := NaturePlanner.plan(r, 3, 5, _cfg(), occupied)
	assert_true(plan.size() > 0)
	var inner := Rect2i(r.position + Vector2i.ONE, r.size - Vector2i(2, 2))
	for d in plan:
		var t: Vector2i = d["tile"]
		assert_true(inner.has_point(t), "innerhalb ohne Rand: %s" % t)
		assert_true(t.y != 27, "belegte Zeile frei")
	# Teiche belegen 2×2, keine Überlappung mit anderen
	var used := {}
	for d in plan:
		var fp := Vector2i(2, 2) if d["kind"] == "pond" else Vector2i.ONE
		for dx in fp.x:
			for dy in fp.y:
				var t2: Vector2i = d["tile"] + Vector2i(dx, dy)
				assert_true(not used.has(t2), "keine Überlappung bei %s" % t2)
				used[t2] = true


func test_sky_never_dark() -> void:
	for i in 48:
		var c := DayLight.color_at(float(i) / 48.0)
		assert_true(c.r >= 0.9 and c.g >= 0.9 and c.b >= 0.9, "hell bei %d: %s" % [i, c])
	assert_true(DayLight.color_at(0.0).is_equal_approx(DayLight.WARM))
	assert_true(DayLight.color_at(0.5).is_equal_approx(DayLight.COOL))


func test_zone_seed_stable() -> void:
	assert_eq(NaturePlanner.zone_seed("z01"), NaturePlanner.zone_seed("z01"))
	assert_true(NaturePlanner.zone_seed("z01") != NaturePlanner.zone_seed("z02"))
	assert_true(NaturePlanner.zone_seed("z11") >= 0)
