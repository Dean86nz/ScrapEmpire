extends TestCase


func test_tick_increments() -> void:
	var w := SimWorld.new()
	w.tick()
	w.tick()
	assert_eq(w.tick_count, 2)


func test_commands_consumed_on_tick() -> void:
	var w := SimWorld.new()
	w.queue_command({"type": "noop"})
	assert_eq(w.pending_commands(), 1)
	w.tick()
	assert_eq(w.pending_commands(), 0)
