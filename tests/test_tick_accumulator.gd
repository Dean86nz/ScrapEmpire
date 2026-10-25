extends TestCase


func test_one_tick_per_50ms() -> void:
	var acc := TickAccumulator.new()
	assert_eq(acc.advance(0.05), 1)


func test_accumulates_partial_frames() -> void:
	var acc := TickAccumulator.new()
	assert_eq(acc.advance(0.03), 0)
	assert_eq(acc.advance(0.03), 1)
	assert_true(absf(acc.alpha - 0.2) < 0.001, "alpha nach 0.06 s sollte 0.2 sein, ist %f" % acc.alpha)


func test_clamps_large_delta() -> void:
	var acc := TickAccumulator.new()
	assert_eq(acc.advance(10.0), 5, "max 0.25 s pro Frame = 5 Ticks")


func test_zero_delta_no_tick() -> void:
	var acc := TickAccumulator.new()
	assert_eq(acc.advance(0.0), 0)
	assert_eq(acc.alpha, 0.0)
