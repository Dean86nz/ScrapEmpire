extends TestCase


func test_add_fills_existing_stack_first() -> void:
	var inv := Inventory.new(6, 20)
	inv.add("scrap", 5)
	inv.add("scrap", 5)
	assert_eq(inv.slots[0]["count"], 10)
	assert_eq(inv.slots[1]["item"], "")


func test_add_overflows_into_next_slot() -> void:
	var inv := Inventory.new(6, 20)
	var rest := inv.add("scrap", 25)
	assert_eq(rest, 0)
	assert_eq(inv.slots[0]["count"], 20)
	assert_eq(inv.slots[1]["count"], 5)


func test_add_returns_remainder_when_full() -> void:
	var inv := Inventory.new(2, 20)
	var rest := inv.add("scrap", 45)
	assert_eq(rest, 5)
	assert_eq(inv.total(), 40)


func test_remove_across_slots_and_frees_empty_slot() -> void:
	var inv := Inventory.new(6, 20)
	inv.add("scrap", 25)
	var removed := inv.remove("scrap", 10)
	assert_eq(removed, 10)
	assert_eq(inv.count_of("scrap"), 15)
	assert_eq(inv.slots[1]["item"], "", "zweiter Slot sollte frei sein")


func test_remove_more_than_available() -> void:
	var inv := Inventory.new(6, 20)
	inv.add("copper", 3)
	assert_eq(inv.remove("copper", 10), 3)
	assert_eq(inv.count_of("copper"), 0)


func test_is_full_and_can_add() -> void:
	var inv := Inventory.new(2, 20)
	inv.add("scrap", 20)
	inv.add("copper", 19)
	assert_false(inv.is_full())
	assert_true(inv.can_add("copper"))
	assert_false(inv.can_add("plastic"), "kein freier Slot für neues Item")
	inv.add("copper", 1)
	assert_true(inv.is_full())
	assert_false(inv.can_add("copper"))


func test_changed_signal_only_when_something_happens() -> void:
	var inv := Inventory.new(1, 20)
	var calls := [0]
	inv.changed.connect(func() -> void: calls[0] += 1)
	inv.add("scrap", 20)
	inv.add("scrap", 5)  # passt nicht, kein Signal
	inv.remove("copper", 1)  # nichts da, kein Signal
	assert_eq(calls[0], 1)
