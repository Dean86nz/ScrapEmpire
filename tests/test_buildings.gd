extends TestCase


func _terminal() -> SellTerminal:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	return Building.create(1, defs["sell_terminal"], Vector2i(2, 2), 0) as SellTerminal


func _chest() -> Chest:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	return Building.create(2, defs["chest"], Vector2i(5, 5), 0) as Chest


func test_terminal_accepts_up_to_buffer_max() -> void:
	var t := _terminal()
	assert_eq(t.accept_stack("scrap", 30), 30)
	assert_eq(t.accept_stack("copper", 20), 10)
	assert_eq(t.buffer.size(), 40)


func test_terminal_sells_fifo_every_10_ticks() -> void:
	var t := _terminal()
	t.accept_stack("scrap", 1)
	t.accept_stack("copper", 1)
	assert_true(t.tick(), "erster Tick verkauft sofort")
	assert_eq(t.take_sold(), "scrap")
	assert_eq(t.take_sold(), "", "nur einmal abholbar")
	var sold := 0
	for i in 9:
		if t.tick():
			sold += 1
	assert_eq(sold, 0, "Cooldown 10 Ticks")
	assert_true(t.tick())
	assert_eq(t.take_sold(), "copper")
	assert_false(t.tick(), "Puffer leer")


func test_terminal_contents_and_summary() -> void:
	var t := _terminal()
	t.accept_stack("scrap", 3)
	t.accept_stack("plastic", 2)
	assert_eq(t.contents(), {"scrap": 3, "plastic": 2})
	assert_eq(t.summary()["buffer"], 5)


func test_chest_accept_withdraw() -> void:
	var c := _chest()
	assert_eq(c.accept_stack("scrap", 25), 25)
	assert_eq(c.contents(), {"scrap": 25})
	var stack := c.withdraw_stack()
	assert_eq(stack, {"item": "scrap", "count": 20})
	assert_eq(c.withdraw_stack(), {"item": "scrap", "count": 5})
	assert_eq(c.withdraw_stack(), {})


func test_chest_capacity() -> void:
	var c := _chest()
	assert_eq(c.accept_stack("scrap", 300), 240)
	assert_false(c.tick())
